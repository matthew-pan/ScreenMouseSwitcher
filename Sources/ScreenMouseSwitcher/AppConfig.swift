import CoreGraphics
import Foundation

/// 一个快捷键组合：修饰键（CGEventFlags 原始值子集）+ 主键 keyCode。
struct KeyCombo: Codable, Equatable {
    var modifierFlags: UInt64
    var keyCode: Int64

    var flags: CGEventFlags { CGEventFlags(rawValue: modifierFlags) }
}

/// 屏幕切换方向。
enum SwitchDirection: CaseIterable {
    case left, right, up, down

    /// 对应箭头键 keyCode。
    var arrowKeyCode: Int64 {
        switch self {
        case .left: return 123
        case .right: return 124
        case .down: return 125
        case .up: return 126
        }
    }
}

/// 持久化的应用配置。
struct AppConfig: Codable, Equatable {
    /// 方向键切换总开关。
    var directionalEnabled: Bool
    /// 方向键共用的修饰键组合（配合 ←→↑↓）。
    var directionalModifierFlags: UInt64
    /// 每屏直达切换总开关。
    var directEnabled: Bool
    /// 屏幕排列序号(0 基) -> 直达快捷键。
    var directBindings: [Int: KeyCombo]

    static let `default` = AppConfig(
        directionalEnabled: true,
        directionalModifierFlags: CGEventFlags([.maskCommand, .maskControl]).rawValue,
        directEnabled: false,
        directBindings: [:]
    )
}

/// 配置读写（UserDefaults + JSON）。
enum ConfigStore {
    private static let key = "AppConfigV1"

    static func load() -> AppConfig {
        guard let data = UserDefaults.standard.data(forKey: key),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return .default
        }
        return config
    }

    static func save(_ config: AppConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

/// keyCode -> 可读标签，供录入控件与排列图显示。
enum KeyName {
    private static let table: [Int64: String] = [
        // 字母
        0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H",
        34: "I", 38: "J", 40: "K", 37: "L", 46: "M", 45: "N", 31: "O", 35: "P",
        12: "Q", 15: "R", 1: "S", 17: "T", 32: "U", 9: "V", 13: "W", 7: "X",
        16: "Y", 6: "Z",
        // 数字
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9", 29: "0",
        // 符号
        27: "-", 24: "=", 33: "[", 30: "]", 42: "\\", 41: ";", 39: "'",
        43: ",", 47: ".", 44: "/", 50: "`",
        // 功能键
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        // 特殊键
        49: "Space", 36: "↩", 48: "⇥", 53: "⎋", 51: "⌫", 117: "⌦",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        115: "Home", 119: "End", 116: "PgUp", 121: "PgDn"
    ]

    static func label(forKeyCode code: Int64) -> String {
        table[code] ?? "键#\(code)"
    }
}

/// 修饰键符号（按 macOS 习惯顺序：⌃⌥⇧⌘）。
func modifierSymbols(_ flags: CGEventFlags) -> String {
    var symbols = ""
    if flags.contains(.maskControl) { symbols += "⌃" }
    if flags.contains(.maskAlternate) { symbols += "⌥" }
    if flags.contains(.maskShift) { symbols += "⇧" }
    if flags.contains(.maskCommand) { symbols += "⌘" }
    return symbols
}

/// 完整组合标签：修饰键 + 主键。
func comboLabel(_ combo: KeyCombo) -> String {
    modifierSymbols(combo.flags) + KeyName.label(forKeyCode: combo.keyCode)
}

