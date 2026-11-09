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
    private var supportsGestures: Bool { model?.id == "baseus:bass-ep10-pro" || isBowieMF1 || isBowie30 }
    private let gestureLayouts: [(UInt8, UInt8)] = [(3, 1), (0, 2), (1, 3), (2, 4)]

    private var isBowie30: Bool { model?.id == "baseus:bowie-30" }
    private var isBowieMF1: Bool { model?.id == "baseus:bowie-mf1" }
    private var supportsNoise: Bool { !isBowieMF1 }

    init(transport: EarbudTransport, name: String, catalog: ModelCatalog) {
        let normalized = EarbudFamily.normalize(name)
        let modelID: String? = normalized.contains("bowie30") ? "baseus:bowie-30"
            : normalized.contains("bowiemf1") ? "baseus:bowie-mf1"
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
            if supportsNoise { _ = try await readNoise() }
            if supportsGestures { try? await readGestures() }
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
            if supportsNoise { _ = try await readNoise() }
            if supportsGestures { try? await readGestures() }
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
        command == Command.battery || (supportsNoise && command == Command.noise) || (supportsGestures && command == Command.gestures)
    }

    func canWrite(_ command: UInt16, reading: UInt16?) -> Bool {
        if command == Command.setGestures {
            return ready && supportsGestures && (reading == nil || reading == Command.gestures) && state.observedQueries.contains(Command.gestures)
        }
        return ready && supportsNoise && command == Command.setNoise &&
            (reading == nil || reading == Command.noise) && state.observedQueries.contains(Command.noise)
    }

    private func readGestures() async throws {
        if isBowieMF1 || isBowie30 {
            for layout: UInt8 in [0, 2, 1] { try await readLegacyGestureLayout(layout) }
            return
        }
        var entries: [GestureEntry] = []
        for button: UInt8 in 0...1 {
            let frame = try await request(0x8C, payload: [button, 0xFF])
            guard frame.payload.count == 9, frame.payload[0] == button else { throw ProtocolError.invalidPayload }
            for index in 0..<4 {
                let layout = frame.payload[1 + index * 2]
                guard let gesture = gestureLayouts.first(where: { $0.0 == layout })?.1 else { throw ProtocolError.invalidPayload }
                let entry = GestureEntry(side: button + 1, mode: 1, gesture: gesture, action: frame.payload[2 + index * 2])
                entries.append(entry)
                if entry.action == 6 { _ = try? await readGestureChildren(entry, button: button, layout: layout) }
            }
        }
        state.gestures = entries
        state.observedQueries.insert(Command.gestures)
        onChange?()
    }

    func gestureActions(_ entry: GestureEntry) -> [UInt8] {
        if isBowieMF1 {
            guard entry.mode == 1, (1...2).contains(entry.side), (2...4).contains(entry.gesture) else { return [] }
            return entry.gesture == 3 ? [4, 5] : [11, 12, 1, 2, 3, 4, 0]
        }
        if isBowie30 {
            guard entry.mode == 1, (1...2).contains(entry.side), (2...4).contains(entry.gesture) else { return [] }
            return [0, 1, 2, 3, 4, 6]
        }
        guard supportsGestures, entry.mode == 1, (1...2).contains(entry.side),
              gestureLayouts.contains(where: { $0.1 == entry.gesture }) else { return [] }
        return entry.gesture == 1 ? [0, 1] : [0, 1, 2, 3, 4, 6, 11, 12]
    }

    func setGesture(_ entry: GestureEntry, action: UInt8) async throws -> WriteOutcome {
        guard canWrite(Command.setGestures, reading: Command.gestures), gestureActions(entry).contains(action),
              state.gestures.contains(where: { $0.id == entry.id }) else { throw ProtocolError.unsupported }
        if isBowieMF1 {
            guard let layout: UInt8 = [2:0, 3:1, 4:2][entry.gesture] else { throw ProtocolError.unsupported }
            try await operations.acquire()
            defer { operations.release() }
            let existing = state.gestures.filter { $0.gesture == entry.gesture }
            guard let left = existing.first(where: { $0.side == 1 })?.action,
                  let right = existing.first(where: { $0.side == 2 })?.action else { throw ProtocolError.invalidPayload }
            let nextLeft = entry.side == 1 ? action : left
            let nextRight = entry.side == 2 ? action : right
            let ack = try await request(0x22, payload: [layout, nextLeft, nextRight])
            guard ack.payload.first == 1 else { throw ProtocolError.rejected(ack.payload.first ?? 0) }
            try await readLegacyGestureLayout(layout)
            guard state.gestures.first(where: { $0.id == entry.id })?.action == action else { throw ProtocolError.readbackMismatch }
            return .confirmed
        }
        if isBowie30 {
            guard let layout: UInt8 = [2:0, 3:1, 4:2][entry.gesture] else { throw ProtocolError.unsupported }
            try await operations.acquire()
            defer { operations.release() }
            let existing = state.gestures.filter { $0.gesture == entry.gesture }
            guard let left = existing.first(where: { $0.side == 1 })?.action,
                  let right = existing.first(where: { $0.side == 2 })?.action else { throw ProtocolError.invalidPayload }
            let ack = try await request(0x22, payload: [layout, entry.side == 1 ? action : left, entry.side == 2 ? action : right])
            guard ack.payload.first == 1 else { throw ProtocolError.rejected(ack.payload.first ?? 0) }
            try await readLegacyGestureLayout(layout)
            guard state.gestures.first(where: { $0.id == entry.id })?.action == action else { throw ProtocolError.readbackMismatch }
            return .confirmed
        }
        guard let layout = gestureLayouts.first(where: { $0.1 == entry.gesture })?.0 else { throw ProtocolError.unsupported }
        try await operations.acquire()
        defer { operations.release() }
        let ack = try await request(0x8D, payload: [entry.side - 1, layout, action])
        guard ack.payload.first == 1 else { throw ProtocolError.rejected(ack.payload.first ?? 0) }
        try await readGestures()
        guard state.gestures.first(where: { $0.id == entry.id })?.action == action else { throw ProtocolError.readbackMismatch }
        return .confirmed
    }

    private func readLegacyGestureLayout(_ layout: UInt8) async throws {
        guard (isBowieMF1 || isBowie30), [0, 1, 2].contains(layout) else { throw ProtocolError.unsupported }
        let frame = try await request(0x21, payload: [layout])
        guard frame.payload.count == 3, frame.payload[0] == layout else { throw ProtocolError.invalidPayload }
        let gesture: UInt8 = [0:2, 1:3, 2:4][Int(layout)]!
        let retained = state.gestures.filter { $0.gesture != gesture }
        state.gestures = retained + [
            GestureEntry(side: 1, mode: 1, gesture: gesture, action: frame.payload[1]),
            GestureEntry(side: 2, mode: 1, gesture: gesture, action: frame.payload[2]),
        ]
        state.observedQueries.insert(Command.gestures)
        onChange?()
    }

    func setGestureChildren(_ entry: GestureEntry, selected: [UInt8]) async throws -> WriteOutcome {
        guard canWrite(Command.setGestures, reading: Command.gestures), entry.action == 6,
              selected.count >= 2, selected.count <= 3, Set(selected).count == selected.count,
              selected.allSatisfy({ [UInt8(0),1,2].contains($0) }),
              let layout = gestureLayouts.first(where: { $0.1 == entry.gesture })?.0,
              state.gestures.contains(where: { $0.id == entry.id && $0.action == 6 }) else { throw ProtocolError.unsupported }
        try await operations.acquire()
        defer { operations.release() }
        let button = entry.side - 1
        let ack = try await request(0x8F, payload: [button, layout, 6, UInt8(selected.count)] + selected)
        guard ack.payload.first == 1 else { throw ProtocolError.rejected(ack.payload.first ?? 0) }
        let confirmed = try await readGestureChildren(entry, button: button, layout: layout)
        guard confirmed == selected else { throw ProtocolError.readbackMismatch }
        return .confirmed
    }

    @discardableResult private func readGestureChildren(_ entry: GestureEntry, button: UInt8, layout: UInt8) async throws -> [UInt8] {
        let frame = try await request(0x8E, payload: [button, layout, 6])
        guard frame.payload.count >= 4, frame.payload[0] == button, frame.payload[1] == layout,
              frame.payload[2] == 6, frame.payload[3] >= 2, frame.payload.count == 4 + Int(frame.payload[3]) else { throw ProtocolError.invalidPayload }
        let selected = Array(frame.payload.dropFirst(4))
        guard Set(selected).count == selected.count, selected.allSatisfy({ [UInt8(0),1,2].contains($0) }) else { throw ProtocolError.invalidPayload }
        state.gestureChildren[entry.id] = selected
        onChange?()
        return selected
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
/// handlers: AA02/AA33 six bytes, AA21 five, AA22/AA34/AA35 three.
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
            case 0x21: length = 5
            case 0x22: length = 3
            case 0x02, 0x33: length = 6
            case 0x34, 0x35, 0x8B, 0x8D, 0x8F: length = 3
            case 0x8C: length = 11
            case 0x8E:
                if buffer.count < 6 { return frames }
                length = 6 + Int(buffer[5])
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
