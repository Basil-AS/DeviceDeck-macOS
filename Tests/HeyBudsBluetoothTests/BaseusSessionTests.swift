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
        default: throw ProtocolError.unsupported
        }
        onEvent?(.data(Data(reply)))
    }
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
        #expect(session.canWrite(Command.setNoise))
        #expect(try await session.setNoise(.anc) == .confirmed)
        #expect(session.state.noise == .anc)
        #expect(Array(radio.packets.suffix(2)) == [Data([0xBA, 0x34, 1, 101]), Data([0xBA, 0x33])])
    }
}
