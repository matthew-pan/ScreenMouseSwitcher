import CoreGraphics
import Foundation

let config = AppConfig.default
let eventFlags: CGEventFlags = [
    .maskCommand, .maskControl, .maskNumericPad, .maskNonCoalesced
]

precondition(
    HotkeyMatcher.action(keyCode: 124, flags: eventFlags, config: config)
        == .direction(.right),
    "方向键快捷键应忽略系统附加 flags"
)

var directConfig = AppConfig.default
directConfig.directEnabled = true
directConfig.directBindings[1] = KeyCombo(
    modifierFlags: CGEventFlags.maskCommand.rawValue,
    keyCode: 18
)
precondition(
    HotkeyMatcher.action(
        keyCode: 18,
        flags: [.maskCommand, .maskNonCoalesced],
        config: directConfig
    ) == .direct(index: 1),
    "每屏直达快捷键应忽略系统附加 flags"
)
