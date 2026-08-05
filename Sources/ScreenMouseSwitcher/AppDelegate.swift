import AppKit
import ApplicationServices
import ServiceManagement

/// 应用主控制器：状态栏菜单、辅助功能授权、开机自启、热键监听。
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let hotkey = HotkeyManager()
    private var permissionTimer: Timer?
    private var settingsController: SettingsWindowController?
    private var hotkeyError: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        ensureAccessibilityAndStart()

        // 显示器插拔 / 排列变化时通知设置窗口刷新。
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screensChanged() {
        settingsController?.screensDidChange()
    }

    // MARK: - 菜单栏

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "rectangle.on.rectangle.angled",
                                accessibilityDescription: "屏幕鼠标切换")
            image?.isTemplate = true
            button.image = image
        }
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "屏幕鼠标切换  ⌘⌃→", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())

        let statusText: String
        if hotkey.isRunning {
            statusText = "状态：监听中"
        } else if let hotkeyError {
            statusText = "状态：\(hotkeyError)"
        } else {
            statusText = "状态：等待「辅助功能」授权"
        }
        let statusMenuItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let loginItem = NSMenuItem(title: "开机自启", action: #selector(toggleLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = isLoginEnabled() ? .on : .off
        menu.addItem(loginItem)

        let axItem = NSMenuItem(title: "打开「辅助功能」设置…", action: #selector(openAccessibility), keyEquivalent: "")
        axItem.target = self
        menu.addItem(axItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - 辅助功能授权

    private func ensureAccessibilityAndStart() {
        if AXIsProcessTrusted() {
            startHotkey()
            rebuildMenu()
            return
        }

        // 弹出系统授权提示。
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        // 轮询等待用户授权，成功后立即启动监听。
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else { return }
            if AXIsProcessTrusted() {
                timer.invalidate()
                self.permissionTimer = nil
                self.startHotkey()
                self.rebuildMenu()
            }
        }
    }

    private func startHotkey() {
        do {
            try hotkey.start()
            hotkeyError = nil
        } catch {
            hotkeyError = "快捷键监听启动失败，请重新授权并重启"
            NSLog("无法创建全局快捷键事件监听：%@", error.localizedDescription)
        }
    }

    // MARK: - 开机自启（SMAppService）

    private func isLoginEnabled() -> Bool {
        SMAppService.mainApp.status == .enabled
    }

    @objc private func toggleLogin() {
        do {
            if isLoginEnabled() {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "无法修改开机自启设置"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        rebuildMenu()
    }

    // MARK: - 动作

    @objc private func openSettings() {
        if settingsController == nil {
            let controller = SettingsWindowController(config: ConfigStore.load())
            controller.onApply = { [weak self] config in
                self?.hotkey.reload(config)
            }
            settingsController = controller
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsController?.screensDidChange()
        settingsController?.showWindow(nil)
        settingsController?.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func openAccessibility() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
