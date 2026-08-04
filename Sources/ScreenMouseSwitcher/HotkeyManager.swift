import CoreGraphics
import Foundation

/// 用 CGEventTap 全局监听按键，按当前配置匹配方向键 / 每屏直达绑定，命中则移动鼠标并吞掉按键。
final class HotkeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var isRunning = false

    /// 当前生效的配置（设置面板保存后调用 reload 更新）。
    private var config: AppConfig = ConfigStore.load()

    /// 只关心这四个修饰键。
    private let relevantModifiers: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]

    func reload(_ newConfig: AppConfig) {
        config = newConfig
    }

    func start() {
        guard eventTap == nil else { return }

        let eventMask = (1 << CGEventType.keyDown.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                manager.reEnable()
                return Unmanaged.passUnretained(event)
            }

            if type == .keyDown, manager.handle(event) {
                return nil // 吞掉该按键
            }
            return Unmanaged.passUnretained(event)
        }

        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                          place: .headInsertEventTap,
                                          options: .defaultTap,
                                          eventsOfInterest: CGEventMask(eventMask),
                                          callback: callback,
                                          userInfo: userInfo) else {
            isRunning = false
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
    }

    func reEnable() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    /// 处理一次按键，返回是否命中并消费。
    private func handle(_ event: CGEvent) -> Bool {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let masked = event.flags.intersection(relevantModifiers).rawValue

        // 方向键：修饰键匹配 + keyCode 是某个箭头。
        if config.directionalEnabled, masked == config.directionalModifierFlags {
            for direction in SwitchDirection.allCases where direction.arrowKeyCode == keyCode {
                MouseMover.moveDirection(direction)
                return true
            }
        }

        // 每屏直达：遍历绑定找完全匹配。
        if config.directEnabled {
            for (index, combo) in config.directBindings
            where combo.keyCode == keyCode && combo.modifierFlags == masked {
                MouseMover.moveToScreen(index: index)
                return true
            }
        }

        return false
    }
}
