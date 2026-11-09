import Foundation
import HeyBudsProtocol

struct BaseusPowerFrame: Equatable, Sendable {
    let status: DevicePowerReading
    let code: UInt16
}

struct BaseusPowerCodec {
    private(set) var buffer:[UInt8]=[]
    static func read(_ code:UInt16) -> Data {
        appendCRC([0x9A,0xAA,0x03,UInt8(code >> 8),UInt8(code & 0xFF),0,1])
    }
    static func write(_ code:UInt16,value:UInt16) -> Data {
        appendCRC([0x9A,0xAA,0x10,UInt8(code >> 8),UInt8(code & 0xFF),0,1,2,1,UInt8(value >> 8),UInt8(value & 0xFF)])
    }
    static func writeText(_ text:String) throws -> Data {
        let bytes=Array(text.utf8)
        guard !text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { throw ProtocolError.invalidPayload }
        guard bytes.count <= 255 else { throw TransportFailure.unavailable("Display text exceeds the one-byte protocol length") }
        return appendCRC([0x9A,0xAA,0x10,0,0x30,0,1,UInt8(bytes.count),1]+bytes)
    }
    static func crc16(_ bytes:[UInt8]) -> UInt16 {
        var crc:UInt16=0xFFFF
        for byte in bytes {
            crc ^= UInt16(byte)
            for _ in 0..<8 { crc = crc & 1 == 1 ? (crc >> 1) ^ 0xA001 : crc >> 1 }
        }
        return crc
    }
    private static func appendCRC(_ bytes:[UInt8]) -> Data {
        let crc=crc16(bytes)
        return Data(bytes+[UInt8(crc >> 8),UInt8(crc & 0xFF)])
    }
    mutating func reset() { buffer.removeAll(keepingCapacity:true) }
    mutating func feed(_ data:Data) -> [BaseusPowerFrame] {
        guard !data.isEmpty,data.count <= 4096 else { return [] }
        if buffer.count+data.count > 4096 { buffer.removeAll(keepingCapacity:true) }
        buffer += data
        var result:[BaseusPowerFrame]=[]
        while buffer.count >= 2 {
            guard let start=(0..<(buffer.count-1)).first(where:{buffer[$0] == 0x9A && buffer[$0+1] == 0xAA}) else {
                let keep=buffer.last == 0x9A
                buffer=keep ? [0x9A] : []
                break
            }
            if start > 0 { buffer.removeFirst(start) }
            guard buffer.count >= 11 else { break }
            let frame=Array(buffer.prefix(11))
            let carried=UInt16(frame[9]) << 8 | UInt16(frame[10])
            if frame[2] == 0x03, Self.crc16(Array(frame[..<9])) == carried, frame[5] == 0 {
                let code=UInt16(frame[3]) << 8 | UInt16(frame[4])
                let multiplier=Int(frame[6]),value=Int(frame[7]) << 8 | Int(frame[8])
                result.append(BaseusPowerFrame(status:DevicePowerReading(multiplier:multiplier,value:value),code:code))
                buffer.removeFirst(11)
            } else { buffer.removeFirst() }
        }
        return result
    }
}

/// Baseus Blade 2 telemetry and display controls inside DeviceDeck's shared device session.
@MainActor final class BaseusBlade2Session:AdditionalSession {
    private(set) var state=DeviceState()
    private(set) var model:DeviceModel?
    private(set) var ready=false
    var interactive=false
    var onChange:(() -> Void)?
    var onClose:((String?) -> Void)?
    private let channel:ControlChannel<BaseusPowerFrame>
    private let operations=RequestGate()
    private var generation=UUID()
    private var poll:Task<Void,Never>?
    private let extended:Bool

    init(transport:EarbudTransport,name:String,catalog:ModelCatalog) {
        model=catalog.models.first{$0.id == "baseus:blade-2"}
        extended=name.localizedCaseInsensitiveContains("140")
        var codec=BaseusPowerCodec()
        channel=ControlChannel(transport:transport,timeout:3,
                              decode:{codec.feed($0)},reset:{codec.reset()})
        channel.onClose={ [weak self] reason in self?.close();self?.onClose?(reason) }
    }
    func open() async throws {
        guard model != nil else { throw ProtocolError.unsupported }
        let token=generation
        do {
            try await channel.open()
            _ = try await read(0x0023)
            guard generation == token else { throw ProtocolError.disconnected }
            ready=true;onChange?()
        } catch { if generation == token { close() };throw error }
    }
    func initialize() async {
        await refresh()
        guard ready,!Task.isCancelled else { return }
        let token=generation
        poll?.cancel()
        poll=Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for:.seconds(self?.interactive == true ? 15 : 45)) } catch { return }
                guard let self,self.ready,self.generation == token else { return }
                await self.refresh()
            }
        }
    }
    func refresh() async {
        guard ready,!Task.isCancelled else { return }
        do {
            try await operations.acquire();defer { operations.release() }
            var codes=Array(UInt16(1)...UInt16(13))+[0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x1E,0x1F,0x20,0x22,0x23]
            if extended { codes += [0x24,0x25,0x26]+Array(UInt16(0x28)...UInt16(0x2D))+Array(UInt16(0x31)...UInt16(0x36)) }
            for code in codes { try Task.checkCancellation(); _ = try await read(code) }
        } catch { if ready { close();onClose?(error.localizedDescription) } }
    }
    private func read(_ code:UInt16) async throws -> DevicePowerReading {
        let token=generation
        let frame=try await channel.request(BaseusPowerCodec.read(code),matching:{$0.code == code})
        try Task.checkCancellation()
        guard ready || !state.powerAccessory.isEmpty || code == 0x23 else { throw ProtocolError.disconnected }
        guard generation == token else { throw ProtocolError.disconnected }
        state.powerAccessory[code]=frame.status;onChange?()
        return frame.status
    }
    private func writeAndRead(_ code:UInt16,value:UInt16) async throws -> WriteOutcome {
        guard ready else { throw ProtocolError.disconnected }
        let allowed:Bool = code == 0x20 ? value <= 2 : code == 0x22 ? value <= 1 : ([0x1E,0x1F].contains(code) && value <= 1440)
        guard allowed else { throw ProtocolError.invalidPayload }
        try await operations.acquire();defer { operations.release() }
        try await channel.send(BaseusPowerCodec.write(code,value:value))
        try await Task.sleep(for:.milliseconds(200))
        let actual=try await read(code)
        guard actual.value == Int(value) else { throw ProtocolError.readbackMismatch }
        return .confirmed
    }
    func setTheme(_ value:UInt16) async throws -> WriteOutcome { try await writeAndRead(0x20,value:value) }
    func setScreenSaver(_ enabled:Bool) async throws -> WriteOutcome { try await writeAndRead(0x22,value:enabled ? 1:0) }
    func setTimer(_ code:UInt16,value:UInt16) async throws -> WriteOutcome { try await writeAndRead(code,value:value) }
    func setPortMode(port:UInt8,mode:UInt8) async throws -> WriteOutcome {
        guard ready,(1...2).contains(port),mode <= 2 else { throw ProtocolError.invalidPayload }
        try await operations.acquire();defer { operations.release() }
        let status=try await read(0x0010).value
        let shift=Int(port-1)*2
        let current=UInt8((status >> shift) & 0x03)
        guard current < 3 else { throw ProtocolError.invalidPayload }
        func command(_ selected:UInt8) -> UInt16? {
            switch (port,selected) {
            case (1,1): return 0x0018 // C1 output / discharge
            case (1,2): return 0x0019 // C1 input / charge
            case (2,1): return 0x001A // C2 output / discharge
            case (2,2): return 0x001B // C2 input / charge
            default: return nil
            }
        }
        if current != mode {
            if current != 0,let code=command(current) { try await channel.send(BaseusPowerCodec.write(code,value:0)) }
            if mode != 0,let code=command(mode) { try await channel.send(BaseusPowerCodec.write(code,value:1)) }
        }
        try await Task.sleep(for:.milliseconds(200))
        let actual=try await read(0x0010).value
        guard UInt8((actual >> shift) & 0x03) == mode else { throw ProtocolError.readbackMismatch }
        return .confirmed
    }
    func setText(_ value:String) async throws -> WriteOutcome {
        guard ready else { throw ProtocolError.disconnected }
        try await operations.acquire();defer { operations.release() }
        try await channel.send(BaseusPowerCodec.writeText(value))
        return .sent
    }
    func canQuery(_ command:UInt16) -> Bool { false }
    func canWrite(_ command:UInt16,reading:UInt16?) -> Bool { false }
    func setNoise(_ mode:NoiseMode) async throws -> WriteOutcome { throw ProtocolError.unsupported }
    func setEQ(_ id:UInt8) async throws -> WriteOutcome { throw ProtocolError.unsupported }
    func close() {
        ready=false;generation=UUID();poll?.cancel();poll=nil;channel.close();state=DeviceState();onChange?()
    }
}
