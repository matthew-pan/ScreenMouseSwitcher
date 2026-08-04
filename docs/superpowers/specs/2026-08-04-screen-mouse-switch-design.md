# 屏幕间鼠标快捷切换 — 设计文档

日期：2026-08-04

## 目标

在接了扩展屏幕的 Mac 上，用一个全局快捷键 `⌘⌃ + →`，把鼠标指针瞬间移动到**另一块屏幕的正中心**，方便在多屏之间快速切换焦点位置。

## 约束

- **不使用任何第三方工具或库**（不用 Hammerspoon、Karabiner、cliclick 等）。
- 只用 macOS 系统自带的框架（AppKit / CoreGraphics）和原生工具链（`swiftc` / `lipo` / `hdiutil` / `iconutil`）。
- 交付为标准 macOS 应用，打包成拖拽安装的通用（arm64 + x86_64）`.dmg`。

## 形态

- 一个 `.app` 包，`LSUIElement = true`（后台运行，无 Dock 图标）。
- 菜单栏状态图标，菜单包含：
  - 开机自启开关（`SMAppService`）
  - 打开「辅助功能」设置
  - 退出
- 首次运行检测并引导「辅助功能」授权。

## 核心逻辑

1. **热键监听**：用 `CGEventTap` 拦截 `keyDown` 事件。当修饰键正好是 `⌘⌃`（Command + Control，且不含 Option/Shift）且 keyCode 为右箭头（`124`）时触发，并返回 `nil` 吞掉该事件，避免向下传递。
2. **移动鼠标**：
   - 用 `CGEvent(source: nil)?.location` 取当前鼠标全局坐标（左上原点，y 向下）。
   - 用 `CGGetActiveDisplayList` 取所有活动显示器；用 `CGGetDisplaysWithPoint` 找出鼠标当前所在显示器。
   - 选出列表中的**下一块**显示器（多屏按顺序循环；两屏即来回切换）。
   - 用 `CGDisplayBounds` 算出目标屏中心，`CGWarpMouseCursorPosition` 瞬移过去。
   - 只有一块屏时不动作。
3. **坐标系一致性**：`CGEvent.location`、`CGDisplayBounds`、`CGWarpMouseCursorPosition` 都使用全局、左上原点、y 向下的坐标，无需翻转。

## 权限

- `CGEventTap` 需要「辅助功能」权限。若未授权，`CGEvent.tapCreate` 返回 `nil`。
- 启动时用 `AXIsProcessTrustedWithOptions` 提示授权；用定时器轮询，一旦授权成功立即（重新）安装事件监听。

## 构建与打包（全部原生工具链）

- 用 SwiftPM（`Package.swift`）+ `swiftc` 编译可执行文件。
- 分别编译 `arm64-apple-macosx` 与 `x86_64-apple-macosx`，用 `lipo -create` 合成**通用二进制**。
- `build.sh` 负责：编译 → 通用二进制 → 组装 `.app`（写 `Info.plist`、放二进制、用 `iconutil` 生成 `.icns`）→ 用 `hdiutil` 打成 `.dmg`（含指向 `/Applications` 的软链接）。
- 预留签名/公证 hook：`codesign` 与 `notarytool` 步骤先以占位注释形式保留，后续补开发者账号即可启用。

## 交付物

1. `Sources/ScreenMouseSwitcher/` — Swift 源码（入口、AppDelegate/菜单栏、热键监听、鼠标移动、权限检查、图标生成器）。
2. `Package.swift` — SwiftPM 清单。
3. `build.sh` — 一键编译 + 组装 .app + 打 dmg。
4. `README.md` — 安装、授权、后续签名说明。
5. 本设计文档。

## 前置条件

- 已安装 Xcode Command Line Tools（`xcode-select --install`）。
- 不签名版首次打开需在 Finder 里右键「打开」以绕过 Gatekeeper；或到「系统设置 → 隐私与安全性」允许。

## 后续可扩展

- 快捷键、目标位置（中心/相对位置）可做成偏好设置。
- 支持自定义每块屏的落点。
- 补齐 Developer ID 签名 + 公证，实现对外分发免右键打开。
