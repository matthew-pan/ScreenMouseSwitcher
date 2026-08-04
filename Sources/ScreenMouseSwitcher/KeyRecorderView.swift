import AppKit
import CoreGraphics

/// 录入式快捷键控件：点按后按下快捷键即可捕获（要求至少一个修饰键）。
final class KeyRecorderView: NSView {

    /// 捕获到新的快捷键组合时回调。
    var onCapture: ((KeyCombo) -> Void)?
    /// 自定义组合的显示文本（如方向键只显示修饰键）。默认用 comboLabel。
    var labelProvider: ((KeyCombo) -> String)?
    /// 是否可交互。
    var isEnabled: Bool = true { didSet { needsDisplay = true } }
    /// 当前组合。
    var combo: KeyCombo? { didSet { needsDisplay = true } }

    private var recording = false
    private var flashMessage: String?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { isEnabled }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 26).isActive = true
        widthAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) 未实现") }

    // MARK: - 交互

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        recording = true
        flashMessage = nil
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    override func resignFirstResponder() -> Bool {
        recording = false
        needsDisplay = true
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        guard recording else {
            super.keyDown(with: event)
            return
        }

        // Esc 取消。
        if event.keyCode == 53 {
            recording = false
            window?.makeFirstResponder(nil)
            needsDisplay = true
            return
        }

        let flags = Self.cgFlags(from: event.modifierFlags)
        guard !flags.isEmpty else {
            // 无修饰键：提示并继续等待。
            flashMessage = "需配合 ⌘⌥⌃⇧"
            needsDisplay = true
            return
        }

        let captured = KeyCombo(modifierFlags: flags.rawValue, keyCode: Int64(event.keyCode))
        combo = captured
        recording = false
        flashMessage = nil
        window?.makeFirstResponder(nil)
        onCapture?(captured)
        needsDisplay = true
    }

    /// 录制中吞掉 performKeyEquivalent，避免系统快捷键抢走按键。
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if recording {
            keyDown(with: event)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    // MARK: - 绘制

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)

        (isEnabled ? NSColor.textBackgroundColor : NSColor.windowBackgroundColor).setFill()
        path.fill()
        (recording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = recording ? 2 : 1
        path.stroke()

        let text: String
        let color: NSColor
        if let flashMessage {
            text = flashMessage
            color = .systemRed
        } else if recording {
            text = "请按下快捷键…"
            color = .secondaryLabelColor
        } else if let combo {
            text = labelProvider?(combo) ?? comboLabel(combo)
            color = isEnabled ? .labelColor : .disabledControlTextColor
        } else {
            text = "点按后录入快捷键"
            color = .placeholderTextColor
        }

        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: color,
            .paragraphStyle: style
        ]
        let string = text as NSString
        let size = string.size(withAttributes: attributes)
        let origin = CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2)
        string.draw(at: origin, withAttributes: attributes)
    }

    // MARK: - 工具

    static func cgFlags(from modifiers: NSEvent.ModifierFlags) -> CGEventFlags {
        var flags = CGEventFlags()
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if modifiers.contains(.shift) { flags.insert(.maskShift) }
        return flags
    }
}
