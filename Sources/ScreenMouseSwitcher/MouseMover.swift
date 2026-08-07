import CoreGraphics

/// 负责把鼠标移动到目标屏幕中心。
enum MouseMover {
    private static func currentMouseLocation() -> CGPoint? {
        CGEvent(source: nil)?.location
    }

    /// 移动到指定屏的正中心。
    static func move(to screen: ScreenInfo) {
        CGWarpMouseCursorPosition(screen.center)
    }

    /// 向指定方向移动到相邻屏中心（无相邻屏则不动作）。
    static func moveDirection(_ direction: SwitchDirection) {
        guard let location = currentMouseLocation() else { return }
        let screens = ScreenLayout.currentScreens()
        guard screens.count > 1 else { return }

        let current = ScreenLayout.screen(containing: location, in: screens) ?? screens[0]
        // 保留初版最可靠的主快捷键语义：右方向键按排列顺序循环切屏。
        let target = direction == .right
            ? ScreenLayout.nextScreen(after: current, in: screens)
            : ScreenLayout.neighbor(of: current, direction: direction, in: screens)
        if let target {
            move(to: target)
        }
    }

    /// 直达指定排列序号的屏（序号越界则不动作）。
    static func moveToScreen(index: Int) {
        let screens = ScreenLayout.currentScreens()
        guard index >= 0, index < screens.count else { return }
        move(to: screens[index])
    }
}
