import AppKit

// 后台运行的菜单栏工具：无 Dock 图标（.accessory 等价于 LSUIElement）。
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
