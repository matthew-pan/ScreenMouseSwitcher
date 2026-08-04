import AppKit

/// 可视化「显示器排列」缩略图：按真实位置等比绘制各屏矩形，可点击选中。
final class ArrangementView: NSView {
    var screens: [ScreenInfo] = [] { didSet { needsDisplay = true } }
    var selectedIndex: Int? { didSet { needsDisplay = true } }

    /// 点击某屏时回调其排列序号。
    var onSelect: ((Int) -> Void)?
    /// 返回某屏要显示的直达键文本（无则 nil）。
    var labelForIndex: ((Int) -> String?)?

    override var isFlipped: Bool { true }   // 与 CGDisplayBounds 一致：y 向下

    private let outerPadding: CGFloat = 20

    private var boundingBox: CGRect {
        guard let first = screens.first else { return .zero }
        return screens.dropFirst().reduce(first.bounds) { $0.union($1.bounds) }
    }

    private func transform() -> (scale: CGFloat, offset: CGPoint) {
        let box = boundingBox
        guard box.width > 0, box.height > 0 else { return (1, .zero) }
        let availableWidth = bounds.width - outerPadding * 2
        let availableHeight = bounds.height - outerPadding * 2
        let scale = min(availableWidth / box.width, availableHeight / box.height)
        let drawnWidth = box.width * scale
        let drawnHeight = box.height * scale
        let offset = CGPoint(x: (bounds.width - drawnWidth) / 2,
                             y: (bounds.height - drawnHeight) / 2)
        return (scale, offset)
    }

    private func rect(for screen: ScreenInfo) -> CGRect {
        let box = boundingBox
        let (scale, offset) = transform()
        return CGRect(x: (screen.bounds.minX - box.minX) * scale + offset.x,
                      y: (screen.bounds.minY - box.minY) * scale + offset.y,
                      width: screen.bounds.width * scale,
                      height: screen.bounds.height * scale)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()

        guard !screens.isEmpty else { return }

        for screen in screens {
            let frame = rect(for: screen).insetBy(dx: 4, dy: 4)
            let path = NSBezierPath(roundedRect: frame, xRadius: 8, yRadius: 8)
            let selected = (screen.index == selectedIndex)

            (selected ? NSColor.controlAccentColor : NSColor.controlColor).setFill()
            path.fill()
            (selected ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
            path.lineWidth = selected ? 3 : 1.5
            path.stroke()

            var text = "屏 \(screen.index + 1)"
            if let key = labelForIndex?(screen.index), !key.isEmpty {
                text += "\n\(key)"
            }
            drawCenteredText(text, in: frame, selected: selected)
        }
    }

    private func drawCenteredText(_ text: String, in rect: CGRect, selected: Bool) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: selected ? NSColor.white : NSColor.labelColor,
            .paragraphStyle: style
        ]
        let string = text as NSString
        let size = string.boundingRect(with: rect.size,
                                       options: [.usesLineFragmentOrigin],
                                       attributes: attributes).size
        let origin = CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2)
        string.draw(in: CGRect(origin: origin, size: size), withAttributes: attributes)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        for screen in screens where rect(for: screen).contains(point) {
            selectedIndex = screen.index
            onSelect?(screen.index)
            return
        }
    }
}
