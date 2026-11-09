// Edifier D8 capability fields decoded from the vendor Connect 8.4.28 parser.
// Unknown bytes are retained by DeviceState and are deliberately not guessed here.
import Foundation

public struct EdifierCapabilityReport: Equatable, Sendable {
    public let payload: [UInt8]

    public init?(payload: [UInt8]) {
        // Byte 13 is the earliest feature-count field used by the app. Short
        // responses remain available as raw diagnostics, but are not presented
        // as a complete capability report.
        guard payload.count >= 14 else { return nil }
        self.payload = payload
    }

    private func value(_ index: Int) -> UInt8? {
        payload.indices.contains(index) ? payload[index] : nil
    }

    private func bit(_ index: Int, _ offset: UInt8) -> Bool? {
        value(index).map { $0 & (1 << offset) != 0 }
    }

    /// Edifier's own app treats D8 byte 13 as an EQ profile selector, not a
    /// Boolean. These preset IDs/names follow its `getEQBean` profile table.
    /// Profiles 5 (per-side tuning) and 11 (scene EQ) have different UI and
    /// payload semantics, so they are deliberately not exposed as simple presets.
    public var equalizerPresets: [EQPreset] {
        let names:[(english:String,chinese:String)]?
        switch value(13) {
        case 1:names=[("Classic","经典"),("Popular","流行"),("Classical","古典"),("Rock","摇滚")]
        case 2:names=[("Classic","经典"),("Popular","流行"),("Classical","古典"),("Rock","摇滚"),("Dance","舞曲"),("Blues","蓝调")]
        case 3:names=[("Classic","经典"),("Popular","流行"),("Rock","摇滚")]
        case 4:names=[("Classic","经典"),("Popular","流行"),("Classical","古典"),("Rock","摇滚"),("Custom","自定义")]
        case 6:names=[("Standard","标准"),("Surround","环绕"),("Game","游戏")]
        case 7:names=[("Classic","经典"),("Dynamic","动感"),("Custom","自定义")]
        case 8:names=[("Classic","经典"),("Dynamic","动感"),("Spatial","空间"),("Custom","自定义")]
        case 9:names=[("Classic","经典"),("HiFi Camel","HiFi 骆驼"),("STAX","STAX")]
        case 10:names=[("Classic","经典"),("Monitor","监听"),("Variable","可变"),("Vocal","人声"),("Custom","自定义")]
        default:names=nil
        }
        return (names ?? []).enumerated().map { index,name in
            EQPreset(id:UInt8(index),chinese:name.chinese,english:name.english)
        }
    }

    /// Minute choices exposed by Connect's timer screen for each D8 timer profile.
    public var sleepTimerOptions: [UInt16] {
        guard let value=value(9),value > 0 else { return [] }
        return value == 1 ? [0,10,20,30,60] : [0,5,15,30,60,180]
    }

    /// Only capabilities explicitly represented by D8 are returned. This is
    /// a device report, not proof that DeviceDeck implements the operation.
    public var reportedControls: [String] {
        var result: [String] = []
        if value(1).map({ $0 > 0 }) == true { result.append("battery") }
        if value(2) == 1 { result.append("readName") }
        if let nameMode=value(3),(1...6).contains(nameMode) { result.append("setName") }
        if value(4) == 1 { result.append("readAddress") }
        if value(5) == 1 { result.append("firmware") }
        if value(6) == 1 { result.append("disconnectAudio") }
        if value(7) == 1 { result.append("repairBluetooth") }
        if value(8) == 1 { result.append("autoPowerOff") }
        if value(9).map({ $0 > 0 }) == true { result.append("sleepTimer") }
        if value(10) == 1 { result.append("powerOff") }
        if value(13).map({ $0 > 0 }) == true { result.append("equalizer") }
        if let game = bit(17, 6), game { result.append("gameMode") }
        if let sensitivity = bit(17, 3), sensitivity { result.append("touchSensitivity") }
        if let wear = bit(18, 0), wear { result.append("wearDetection") }
        if let wind = bit(18, 4), wind { result.append("windNoise") }
        if let hearing = bit(20, 4), hearing { result.append("hearingProtection") }
        if let soundSpace = bit(20, 0), soundSpace { result.append("soundSpace") }
        if let prompt = bit(20, 1), prompt { result.append("voicePrompts") }
        return result
    }

    /// Stable UI labels; localized by the caller.
    public static let labels: [(key: String, zh: String, en: String)] = [
        ("battery", "电量", "Battery"),
        ("readName", "读取设备名称", "Read device name"),
        ("setName", "修改设备名称", "Rename device"),
        ("readAddress", "读取蓝牙地址", "Read Bluetooth address"),
        ("firmware", "固件信息", "Firmware information"),
        ("disconnectAudio", "断开音频连接", "Disconnect audio"),
        ("repairBluetooth", "重新配对", "Repair Bluetooth pairing"),
        ("autoPowerOff", "无音频自动关机", "Auto power-off"),
        ("sleepTimer", "定时关机", "Sleep timer"),
        ("powerOff", "关机", "Power off"),
        ("equalizer", "均衡器", "Equalizer"),
        ("gameMode", "游戏模式", "Game mode"),
        ("touchSensitivity", "触控灵敏度", "Touch sensitivity"),
        ("wearDetection", "佩戴检测", "Wear detection"),
        ("windNoise", "风噪设置", "Wind noise control"),
        ("hearingProtection", "听力保护", "Hearing protection"),
        ("soundSpace", "空间音效", "Sound space"),
        ("voicePrompts", "语音提示", "Voice prompts")
    ]
}
