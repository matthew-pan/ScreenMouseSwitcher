import AppKit
import CoreGraphics

/// 设置窗口：可视化屏幕排列 + 方向键 / 每屏直达的快捷键录入配置。
final class SettingsWindowController: NSWindowController, NSWindowDelegate {

    /// 保存时回调最新配置（供 AppDelegate 重载热键）。
    var onApply: ((AppConfig) -> Void)?

    private var config: AppConfig
    private var screens: [ScreenInfo] = []
    private var selectedIndex: Int?

    // UI 控件
    private let arrangementView = ArrangementView()
    private let directionalCheckbox = NSButton(checkboxWithTitle: "启用方向键切换（←→↑↓ 跳到相邻屏）", target: nil, action: nil)
    private let directionalRecorder = KeyRecorderView()
    private let directCheckbox = NSButton(checkboxWithTitle: "启用每屏直达（给每块屏单独配一个快捷键）", target: nil, action: nil)
    private let directHintLabel = NSTextField(labelWithString: "点击上方屏幕缩略图进行配置")
    private let directRecorder = KeyRecorderView()
    private let clearButton = NSButton(title: "清除该屏", target: nil, action: nil)

    init(config: AppConfig) {
        self.config = config
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 560),
                              styleMask: [.titled, .closable],
                              backing: .buffered,
                              defer: false)
        window.title = "屏幕鼠标切换 · 设置"
        super.init(window: window)
        window.delegate = self
        window.center()
        buildUI()
        reloadScreens()
        syncFromConfig()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) 未实现") }

    // MARK: - 构建界面

    private func buildUI() {
        guard let content = window?.contentView else { return }

        // target-action
        directionalCheckbox.target = self
        directionalCheckbox.action = #selector(directionalToggled)
        directCheckbox.target = self
        directCheckbox.action = #selector(directToggled)
        clearButton.target = self
        clearButton.action = #selector(clearBinding)

        // 方向键录入：只取修饰键，显示为「修饰键 + ←→↑↓」。
        directionalRecorder.labelProvider = { combo in
            modifierSymbols(combo.flags) + " ←→↑↓"
        }
        directionalRecorder.onCapture = { [weak self] combo in
            guard let self else { return }
            self.config.directionalModifierFlags = combo.flags.rawValue
            self.arrangementView.needsDisplay = true
        }

        // 每屏直达录入：捕获完整组合。
        directRecorder.onCapture = { [weak self] combo in
            guard let self, self.config.directEnabled, let index = self.selectedIndex else { return }
            self.config.directBindings[index] = combo
            self.arrangementView.needsDisplay = true
        }

        arrangementView.onSelect = { [weak self] index in
            self?.selectedIndex = index
            self?.updateDirectControls()
        }
        arrangementView.labelForIndex = { [weak self] index in
            guard let self, self.config.directEnabled,
                  let combo = self.config.directBindings[index] else { return nil }
            return comboLabel(combo)
        }

        directHintLabel.textColor = .secondaryLabelColor
        directHintLabel.font = .systemFont(ofSize: 12)

        // 方向键行
        let directionalRow = NSStackView(views: [
            NSTextField(labelWithString: "快捷键："), directionalRecorder,
            NSTextField(labelWithString: "（点按后按下 修饰键+任意键）")
        ])
        directionalRow.orientation = .horizontal
        directionalRow.spacing = 8

        // 直达配置行
        let directRow = NSStackView(views: [
            NSTextField(labelWithString: "快捷键："), directRecorder, clearButton
        ])
        directRow.orientation = .horizontal
        directRow.spacing = 8

        // 底部按钮
        let saveButton = NSButton(title: "保存", target: self, action: #selector(save))
        let cancelButton = NSButton(title: "关闭", target: self, action: #selector(closeWindow))
        let buttonRow = NSStackView(views: [NSView(), cancelButton, saveButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 12

        let stack = NSStackView(views: [
            sectionTitle("显示器排列（点击选择要配置的屏）"),
            arrangementView,
            sectionTitle("方向键切换"),
            directionalCheckbox,
            directionalRow,
            separator(),
            sectionTitle("每屏直达"),
            directCheckbox,
            directHintLabel,
            directRow,
            separator(),
            buttonRow
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            arrangementView.heightAnchor.constraint(equalToConstant: 240),
            arrangementView.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40),
            buttonRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40)
        ])
    }

    private func sectionTitle(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .boldSystemFont(ofSize: 13)
        return field
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalToConstant: 500).isActive = true
        return box
    }

    // MARK: - 屏幕 & 配置同步

    private func reloadScreens() {
        screens = ScreenLayout.currentScreens()
        arrangementView.screens = screens
        if let selectedIndex, selectedIndex >= screens.count {
            self.selectedIndex = nil
        }
        arrangementView.selectedIndex = selectedIndex
        arrangementView.needsDisplay = true
    }

    private func syncFromConfig() {
        directionalCheckbox.state = config.directionalEnabled ? .on : .off
        directionalRecorder.isEnabled = config.directionalEnabled
        directionalRecorder.combo = KeyCombo(modifierFlags: config.directionalModifierFlags, keyCode: 124)
        directCheckbox.state = config.directEnabled ? .on : .off
        updateDirectControls()
    }

    /// 根据当前选中屏与 directEnabled 刷新直达控件。
    private func updateDirectControls() {
        let hasSelection = selectedIndex != nil
        let enabled = config.directEnabled && hasSelection
        directRecorder.isEnabled = enabled
        clearButton.isEnabled = enabled

        if !config.directEnabled {
            directHintLabel.stringValue = "开启「每屏直达」后可为每块屏录入快捷键"
        } else if let index = selectedIndex {
            directHintLabel.stringValue = "正在配置：屏 \(index + 1)"
        } else {
            directHintLabel.stringValue = "点击上方屏幕缩略图进行配置"
        }

        if let index = selectedIndex {
            directRecorder.combo = config.directBindings[index]
        } else {
            directRecorder.combo = nil
        }

        arrangementView.needsDisplay = true
    }

    // MARK: - 动作

    @objc private func directionalToggled() {
        config.directionalEnabled = (directionalCheckbox.state == .on)
        directionalRecorder.isEnabled = config.directionalEnabled
        arrangementView.needsDisplay = true
    }

    @objc private func directToggled() {
        config.directEnabled = (directCheckbox.state == .on)
        updateDirectControls()
    }

    @objc private func clearBinding() {
        guard let index = selectedIndex else { return }
        config.directBindings.removeValue(forKey: index)
        updateDirectControls()
    }

    @objc private func save() {
        if let message = conflictMessage(in: config) {
            let alert = NSAlert()
            alert.messageText = "快捷键冲突"
            alert.informativeText = message
            alert.runModal()
            return
        }
        ConfigStore.save(config)
        onApply?(config)
        closeWindow()
    }

    @objc private func closeWindow() {
        window?.close()
    }

    // MARK: - 冲突检测

    private func conflictMessage(in config: AppConfig) -> String? {
        var seen: [String: String] = [:]
        func check(_ combo: KeyCombo, _ desc: String) -> String? {
            let key = "\(combo.modifierFlags)-\(combo.keyCode)"
            if let existing = seen[key] {
                return "「\(desc)」与「\(existing)」使用了相同的快捷键。"
            }
            seen[key] = desc
            return nil
        }

        if config.directionalEnabled {
            let names: [(SwitchDirection, String)] = [(.left, "左"), (.right, "右"), (.up, "上"), (.down, "下")]
            for (direction, name) in names {
                let combo = KeyCombo(modifierFlags: config.directionalModifierFlags, keyCode: direction.arrowKeyCode)
                if let message = check(combo, "方向键·\(name)") { return message }
            }
        }
        if config.directEnabled {
            for (index, combo) in config.directBindings.sorted(by: { $0.key < $1.key }) {
                if let message = check(combo, "屏 \(index + 1) 直达") { return message }
            }
        }
        return nil
    }

    // MARK: - 屏幕变化

    func screensDidChange() {
        reloadScreens()
        updateDirectControls()
    }
}
