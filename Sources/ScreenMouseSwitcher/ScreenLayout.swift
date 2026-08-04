import CoreGraphics

/// 单块屏幕的信息（全局坐标，左上原点，y 向下）。
struct ScreenInfo: Equatable {
    let index: Int                 // 排列序号（左→右、上→下，0 基）
    let displayID: CGDirectDisplayID
    let bounds: CGRect

    var center: CGPoint { CGPoint(x: bounds.midX, y: bounds.midY) }
}

/// 屏幕排列与方向相邻查找。
enum ScreenLayout {
    /// 当前所有活动屏幕，按左→右、上→下排序。
    static func currentScreens() -> [ScreenInfo] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }

        let sorted = ids.sorted { lhs, rhs in
            let a = CGDisplayBounds(lhs)
            let b = CGDisplayBounds(rhs)
            if a.minX != b.minX { return a.minX < b.minX }
            return a.minY < b.minY
        }
        return sorted.enumerated().map {
            ScreenInfo(index: $0.offset, displayID: $0.element, bounds: CGDisplayBounds($0.element))
        }
    }

    /// 包含指定点的屏幕。
    static func screen(containing point: CGPoint, in screens: [ScreenInfo]) -> ScreenInfo? {
        screens.first { $0.bounds.contains(point) }
    }

    /// 从 current 出发，向 direction 方向找最近的相邻屏。
    static func neighbor(of current: ScreenInfo,
                         direction: SwitchDirection,
                         in screens: [ScreenInfo]) -> ScreenInfo? {
        let origin = current.center
        var best: ScreenInfo?
        var bestScore = CGFloat.greatestFiniteMagnitude

        for candidate in screens where candidate.index != current.index {
            let target = candidate.center
            let dx = target.x - origin.x
            let dy = target.y - origin.y

            let primary: CGFloat    // 目标方向上的推进量（需为正）
            let secondary: CGFloat  // 垂直偏移（越小越好）
            switch direction {
            case .right: primary = dx;  secondary = abs(dy)
            case .left:  primary = -dx; secondary = abs(dy)
            case .down:  primary = dy;  secondary = abs(dx)
            case .up:    primary = -dy; secondary = abs(dx)
            }

            guard primary > 1 else { continue }   // 必须真的在该方向上
            let score = primary + secondary * 2   // 垂直偏移加权，优先正对方向的屏
            if score < bestScore {
                bestScore = score
                best = candidate
            }
        }
        return best
    }
}
