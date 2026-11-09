import Testing
import Foundation
@testable import HeyBudsBluetooth
import HeyBudsProtocol

@MainActor private final class BaseusRadio: EarbudTransport {
    var onEvent: ((TransportEvent) -> Void)?
    let label = "Mock Baseus SPP"
    var active = false
    var packets: [Data] = []
    var mode: UInt8 = 0
    var level: UInt8 = 0xFF
    var gestures: [UInt8: [UInt8: UInt8]] = [0: [3:1, 0:1, 1:2, 2:6], 1: [3:1, 0:1, 1:3, 2:6]]
    var gestureChildren: [String: [UInt8]] = ["0:2": [1, 2, 0], "1:2": [1, 2, 0]]
    func open() async throws { active = true }
    func close() { active = false }
    func send(_ data: Data) async throws {
        guard active else { throw ProtocolError.disconnected }
        packets.append(data)
        let bytes = [UInt8](data)
        guard bytes.count >= 2, bytes[0] == 0xBA else { throw ProtocolError.invalidPayload }
        let reply: [UInt8]
        switch bytes[1] {
        case 0x02: reply = [0xAA, 0x02, 90, 0, 80, 1]
        case 0x33: reply = [0xAA, 0x33, mode, level, 0, 0]
        case 0x34:
            mode = bytes[2]
            level = bytes[3]
            reply = [0xAA, 0x34, 1]
        case 0x8C:
            let button = bytes[2]
            reply = [0xAA, 0x8C, button, 3, gestures[button]?[3] ?? 0, 0, gestures[button]?[0] ?? 0,
                     1, gestures[button]?[1] ?? 0, 2, gestures[button]?[2] ?? 0]
        case 0x8D:
            gestures[bytes[2], default: [:]][bytes[3]] = bytes[4]
            reply = [0xAA, 0x8D, 1]
        case 0x8E:
            let key = "\(bytes[2]):\(bytes[3])"
            let children = gestureChildren[key] ?? [1, 2, 0]
            reply = [0xAA, 0x8E, bytes[2], bytes[3], bytes[4], UInt8(children.count)] + children
        case 0x8F:
            let key = "\(bytes[2]):\(bytes[3])"
            let count = Int(bytes[5])
            gestureChildren[key] = Array(bytes[6..<(6 + count)])
            reply = [0xAA, 0x8F, 1]
        default: throw ProtocolError.unsupported
        }
        onEvent?(.data(Data(reply)))
    }
}

@MainActor private final class BaseusPowerRadio: EarbudTransport {
    var onEvent:((TransportEvent)->Void)?
    let label="Mock Baseus BLE"
    var active=false
    var packets:[Data]=[]
    var values:[UInt16:UInt16]=[0x20:1,0x22:0,0x1E:0,0x1F:0,0x23:4]
    func open() async throws { active=true }
    func close() { active=false }
    func send(_ data:Data) async throws {
        guard active else { throw ProtocolError.disconnected }
        packets.append(data)
        let bytes=[UInt8](data)
        guard bytes.count >= 7,bytes[0] == 0x9A,bytes[1] == 0xAA else { throw ProtocolError.invalidPayload }
        let code=UInt16(bytes[3]) << 8 | UInt16(bytes[4])
        if bytes[2] == 0x10 {
            values[code]=UInt16(bytes[9]) << 8 | UInt16(bytes[10])
            return
        }
        guard bytes[2] == 0x03 else { throw ProtocolError.unsupported }
        let value=values[code] ?? 0
        let body:[UInt8]=[0x9A,0xAA,0x03,bytes[3],bytes[4],0,1,UInt8(value >> 8),UInt8(value & 0xFF)]
        let crc=BaseusPowerCodec.crc16(body)
        onEvent?(.data(Data(body+[UInt8(crc >> 8),UInt8(crc & 0xFF)])))
    }
}

@Test @MainActor func blade2UsesSharedBaseusBLEProfileAndConfirmsSettings() async throws {
    let radio=BaseusPowerRadio()
    let session=DeviceSession(transport:radio,name:"Baseus Blade 2",catalog:try ModelCatalog())
    defer { session.close() }
    try await session.open()
    #expect(session.model?.id == "baseus:blade-2")
    #expect(session.ready)
    #expect(session.state.powerAccessory[0x23]?.value == 4)
    #expect(try await session.setBaseusPowerTheme(2) == .confirmed)
    #expect(session.state.powerAccessory[0x20]?.value == 2)
    #expect(try await session.setBaseusPowerSaver(true) == .confirmed)
    #expect(try await session.setBaseusPowerTimer(0x1E,value:45) == .confirmed)
    #expect(try await session.setBaseusPowerText("DeviceDeck") == .sent)
    #expect(radio.packets.contains(BaseusPowerCodec.read(0x20)))
    #expect(radio.packets.contains(BaseusPowerCodec.write(0x20,value:2)))
    #expect(String(decoding:radio.packets.last!,as:UTF8.self).contains("DeviceDeck"))
}

@Test @MainActor func bowie30RoutesThroughBaseusBLEProfileAndUsesVendorModeLevel() async throws {
    #expect(BLEControlProfile.baseus.service == "53527AA4-29F7-AE11-4E74-997334782568")
    #expect(BLEControlProfile.baseus.write == "EE684B1A-1E9B-ED3E-EE55-F894667E92AC")
    #expect(BLEControlProfile.baseus.notify == "654B749C-E37F-AE1F-EBAB-40CA133E3690")
    let radio = BaseusRadio()
    let session = DeviceSession(transport: radio, name: "Baseus Bowie 30", catalog: try ModelCatalog())
    defer { session.close() }
    try await session.open()
    #expect(session.model?.id == "baseus:bowie-30")
    #expect(session.ready && session.state.noise == .off)
    #expect(try await session.setNoise(.smart) == .confirmed)
    #expect(radio.packets.suffix(2) == [Data([0xBA, 0x34, 1, 8]), Data([0xBA, 0x33])])
    #expect(session.state.noise == .smart)
    #expect(try await session.setNoise(.medium) == .confirmed)
    #expect(radio.packets.suffix(2) == [Data([0xBA, 0x34, 1, 10]), Data([0xBA, 0x33])])
    #expect(session.state.noise == .medium)
    #expect(try await session.setNoise(.light) == .confirmed)
    #expect(radio.packets.suffix(2) == [Data([0xBA, 0x34, 1, 9]), Data([0xBA, 0x33])])
    #expect(session.state.noise == .light)
}

@Test @MainActor func bowieMF1UsesOnlyTheBaseusBatteryQueryUntilItsControlsAreMapped() async throws {
    let radio = BaseusRadio()
    let session = DeviceSession(transport: radio, name: "Baseus Bowie MF1", catalog: try ModelCatalog())
    defer { session.close() }
    try await session.open()
    #expect(session.model?.id == "baseus:bowie-mf1")
    #expect(session.ready)
    #expect(session.state.batteries[.left]?.percent == 90)
    #expect(session.state.batteries[.right]?.percent == 80)
    #expect(radio.packets == [Data([0xBA, 0x02])])
    #expect(session.canQuery(Command.battery))
    #expect(!session.canQuery(Command.noise))
    #expect(!session.canWrite(Command.setNoise))
}

@Suite("Baseus EP10 Pro SPP packets") struct BaseusSessionTests {
    @Test func officialAppCommandsAreBareBaFrames() {
        #expect(BaseusFrameCodec.encode(0x02) == Data([0xBA, 0x02]))
        #expect(BaseusFrameCodec.encode(0x33) == Data([0xBA, 0x33]))
        #expect(BaseusFrameCodec.encode(0x34, payload: [0x01, 0x65]) == Data([0xBA, 0x34, 0x01, 0x65]))
    }

    @Test func splitsPartialAndCoalescedNotifications() {
        var codec = BaseusFrameCodec()
        #expect(codec.feed(Data([0xAA, 0x02, 90, 0])) == [])
        let frames = codec.feed(Data([80, 1, 0xAA, 0x34, 1, 0xAA, 0x33, 1, 0x65, 0, 0]))
        #expect(frames == [
            BaseusFrame(command: 0x02, payload: [90, 0, 80, 1]),
            BaseusFrame(command: 0x34, payload: [1]),
            BaseusFrame(command: 0x33, payload: [1, 0x65, 0, 0]),
        ])
    }

    @Test func discardsUnknownNotificationsWithoutLosingFollowingFrame() {
        var codec = BaseusFrameCodec()
        #expect(codec.feed(Data([0xAA, 0x7F, 0xAA, 0x34, 1])) == [BaseusFrame(command: 0x34, payload: [1])])
    }

    @Test @MainActor func sessionReadsBatteryAndConfirmsNoiseAfterAck() async throws {
        let radio = BaseusRadio()
        let session = DeviceSession(transport: radio, name: "Baseus Bass EP10 Pro", catalog: try ModelCatalog())
        defer { session.close() }
        try await session.open()
        #expect(session.ready)
        #expect(session.state.batteries[.left]?.percent == 90)
        #expect(session.state.batteries[.right]?.percent == 80)
        #expect(session.state.noise == .off)
        #expect(session.canWrite(Command.setGestures, reading: Command.gestures))
        let leftDouble = try #require(session.state.gestures.first { $0.side == 1 && $0.gesture == 2 })
        #expect(try await session.setGesture(leftDouble, action: 2) == .confirmed)
        #expect(session.state.gestures.first { $0.id == leftDouble.id }?.action == 2)
        #expect(session.canWrite(Command.setNoise))
        #expect(try await session.setNoise(.anc) == .confirmed)
        #expect(session.state.noise == .anc)
        #expect(Array(radio.packets.suffix(2)) == [Data([0xBA, 0x34, 1, 101]), Data([0xBA, 0x33])])
    }
}

@Suite("Baseus Blade 2 power accessory packets") struct BaseusPowerCodecTests {
    @Test func readWriteTextAndStreamDecoderUseTheAppCRC() throws {
        #expect(BaseusPowerCodec.crc16(Array("123456789".utf8)) == 0x4B37)
        #expect(BaseusPowerCodec.read(0x20) == Data([0x9A,0xAA,0x03,0,0x20,0,1,0x09,0xBD]))
        let write=BaseusPowerCodec.write(0x20,value:2)
        #expect(write.count == 13)
        #expect(try BaseusPowerCodec.writeText("DeviceDeck").count == 21)
        var codec=BaseusPowerCodec()
        let reply=[UInt8]([0x9A,0xAA,0x03,0,0x20,0,1,0,2])
        let crc=BaseusPowerCodec.crc16(reply)
        let frame=Data(reply+[UInt8(crc >> 8),UInt8(crc & 0xFF)])
        #expect(codec.feed(frame.prefix(4)).isEmpty)
        #expect(codec.feed(frame.suffix(from:4)) == [BaseusPowerFrame(status:DevicePowerReading(multiplier:1,value:2),code:0x20)])
    }
}
