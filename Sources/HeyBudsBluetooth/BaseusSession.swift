import Foundation
import HeyBudsProtocol

/// Baseus Bass EP10 Pro. The official app routes this exact model through SPP
/// (RFCOMM), sends bare BA commands, and reads bare AA notifications.
@MainActor final class BaseusSession: AdditionalSession {
    private(set) var state = DeviceState()
    private(set) var model: DeviceModel?
    private(set) var ready = false
    var interactive = false
    var onChange: (() -> Void)?
    var onClose: ((String?) -> Void)?

    private let channel: ControlChannel<BaseusFrame>
    private let operations = RequestGate()
    private var generation = UUID()
    private var poll: Task<Void, Never>?
    private var noiseType: UInt8?

    private var isBowie30: Bool { model?.id == "baseus:bowie-30" }

    init(transport: EarbudTransport, name: String, catalog: ModelCatalog) {
        let normalized = EarbudFamily.normalize(name)
        let modelID: String? = normalized.contains("bowie30") ? "baseus:bowie-30"
            : ["baseusbassep10pro", "bassep10pro"].contains(normalized) ? "baseus:bass-ep10-pro" : nil
        model = modelID.flatMap { id in catalog.models.first { $0.id == id } }
        var codec = BaseusFrameCodec()
        channel = ControlChannel(transport: transport, timeout: 2.5,
                                 decode: { codec.feed($0) }, reset: { codec.reset() })
        channel.onClose = { [weak self] reason in self?.close(); self?.onClose?(reason) }
    }

    private func request(_ command: UInt8, payload: [UInt8] = [], response: UInt8? = nil) async throws -> BaseusFrame {
        let token = generation
        let expected = response ?? command
        let frame = try await channel.request(BaseusFrameCodec.encode(command, payload: payload), matching: {
            $0.command == expected
        })
        try Task.checkCancellation()
        guard generation == token else { throw ProtocolError.disconnected }
        return frame
    }

    func open() async throws {
        guard model != nil else { throw ProtocolError.unsupported }
        let token = generation
        do {
            try await channel.open()
            try await readBattery()
            _ = try await readNoise()
            guard generation == token else { throw ProtocolError.disconnected }
            ready = true
            onChange?()
        } catch {
            if generation == token { close() }
            throw error
        }
    }

    func initialize() async {
        await refresh()
        guard ready, !Task.isCancelled else { return }
        let token = generation
        poll?.cancel()
        poll = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(self?.interactive == true ? 15 : 45)) }
                catch { return }
                guard let self, self.ready, self.generation == token else { return }
                await self.refresh()
            }
        }
    }

    func refresh() async {
        guard ready, !Task.isCancelled else { return }
        do {
            try await operations.acquire()
            defer { operations.release() }
            guard ready else { return }
            try await readBattery()
            _ = try await readNoise()
        } catch {
            if ready { close(); onClose?(error.localizedDescription) }
        }
    }

    private func readBattery() async throws {
        let frame = try await request(0x02)
        guard frame.payload.count == 4, frame.payload[0] <= 100,
              frame.payload[1] == 0, frame.payload[2] <= 100, frame.payload[3] == 1 else {
            state.batteries[.left] = nil
            state.batteries[.right] = nil
            state.observedQueries.remove(Command.battery)
            onChange?()
            throw ProtocolError.invalidPayload
        }
        state.batteries[.left] = BatteryReading(percent: Int(frame.payload[0]))
        state.batteries[.right] = BatteryReading(percent: Int(frame.payload[2]))
        state.observedQueries.insert(Command.battery)
        onChange?()
    }

    private func readNoise() async throws -> NoiseMode {
        let frame = try await request(0x33)
        guard frame.payload.count == 4 else {
            state.noise = nil
            state.observedQueries.remove(Command.noise)
            onChange?()
            throw ProtocolError.invalidPayload
        }
        let mode: NoiseMode
        switch frame.payload[0] {
        case 0: mode = .off
        case 1:
            mode = isBowie30
                ? ([UInt8(8):NoiseMode.smart,10:.medium,9:.light][frame.payload[1]] ?? .anc)
                : .anc
        case 2: mode = .transparency
        default:
            state.noise = nil
            state.observedQueries.remove(Command.noise)
            onChange?()
            throw ProtocolError.invalidPayload
        }
        state.noise = mode
        noiseType = frame.payload[1]
        state.observedQueries.insert(Command.noise)
        onChange?()
        return mode
    }

    func canQuery(_ command: UInt16) -> Bool {
        command == Command.battery || command == Command.noise
    }

    func canWrite(_ command: UInt16, reading: UInt16?) -> Bool {
        ready && command == Command.setNoise &&
            (reading == nil || reading == Command.noise) && state.observedQueries.contains(Command.noise)
    }

    func setNoise(_ mode: NoiseMode) async throws -> WriteOutcome {
        guard canWrite(Command.setNoise, reading: Command.noise) else { throw ProtocolError.unsupported }
        let value: UInt8
        let level: UInt8
        switch mode {
        case .off: value = 0; level = 0xFF
        case .anc:
            value = 1
            // Keep the official app's selected environment when possible. The
            // vendor picker lists Bowie 30 commute mode as 8; EP10 Pro uses 101.
            let defaultLevel: UInt8 = isBowie30 ? 8 : 101
            level = state.noise == .anc ? (noiseType ?? defaultLevel) : defaultLevel
        case .smart where isBowie30: value = 1; level = 8
        case .medium where isBowie30: value = 1; level = 10
        case .light where isBowie30: value = 1; level = 9
        case .transparency: value = 2; level = 0xFF
        default: throw ProtocolError.unsupported
        }

        let token = generation
        try await operations.acquire()
        defer { operations.release() }
        guard canWrite(Command.setNoise, reading: Command.noise), generation == token else { throw ProtocolError.disconnected }
        let acknowledgement = try await request(0x34, payload: [value, level])
        guard acknowledgement.payload.first == 1 else {
            throw ProtocolError.rejected(acknowledgement.payload.first ?? 0)
        }
        let current = try await readNoise()
        guard ready, generation == token, current == mode else { throw ProtocolError.readbackMismatch }
        return .confirmed
    }

    func setEQ(_ id: UInt8) async throws -> WriteOutcome { throw ProtocolError.unsupported }
    func close() {
        ready = false
        generation = UUID()
        poll?.cancel(); poll = nil
        channel.close()
        state = DeviceState()
        noiseType = nil
        onChange?()
    }
}

struct BaseusFrame: Equatable, Sendable {
    let command: UInt8
    let payload: [UInt8]
}

/// SPP is a byte stream: retain partial reads and split coalesced Baseus replies.
/// Lengths here are the shapes consumed by Baseus Intelligent 2.18.0's headphone
/// handlers: AA02/AA33 six bytes, AA34/AA35 three bytes.
struct BaseusFrameCodec {
    private var buffer: [UInt8] = []
    static func encode(_ command: UInt8, payload: [UInt8] = []) -> Data {
        Data([0xBA, command] + payload)
    }
    mutating func reset() { buffer.removeAll(keepingCapacity: true) }
    mutating func feed(_ data: Data) -> [BaseusFrame] {
        buffer.append(contentsOf: data)
        var frames: [BaseusFrame] = []
        while let start = buffer.firstIndex(of: 0xAA) {
            if start > 0 { buffer.removeFirst(start) }
            guard buffer.count >= 2 else { break }
            let length: Int
            switch buffer[1] {
            case 0x02, 0x33: length = 6
            case 0x34, 0x35: length = 3
            default: buffer.removeFirst(); continue
            }
            guard buffer.count >= length else { break }
            frames.append(BaseusFrame(command: buffer[1], payload: Array(buffer[2..<length])))
            buffer.removeFirst(length)
        }
        if buffer.count > 128 { buffer.removeAll(keepingCapacity: true) }
        return frames
    }
}
