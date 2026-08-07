# 屏幕鼠标切换（ScreenMouseSwitcher）

一个纯原生的 macOS 后台小工具：用快捷键让鼠标指针在多块屏幕之间快速切换，指针落在目标屏的**正中心**。

[⬇️ 下载最新正式版 DMG](https://github.com/matthew-pan/ScreenMouseSwitcher/releases/latest)

- 不依赖任何第三方工具或库，只用 macOS 自带框架（AppKit / CoreGraphics）。
- 菜单栏后台运行，无 Dock 图标。
- 支持开机自启（系统原生 `SMAppService`）。
- 打包为通用（Apple Silicon + Intel）`.dmg`。

## 功能

- **快捷切屏**：默认 `⌘⌃→` 按屏幕排列顺序切到下一屏，最后一屏会回到第一屏，保持初版可靠的单快捷键体验。`⌘⌃←/↑/↓` 仍可按实际排列跳到对应方向的相邻屏。
- **每屏直达**：给每块屏单独分配一个快捷键，一键直接跳到该屏。
- **可视化设置面板**：类似系统「显示器排列」，按真实位置画出屏幕缩略图，点击某块屏即可为它配置直达快捷键；快捷键采用**录入式**——点按输入框后直接按下想要的组合键即可捕获。
- 保存时自动检测快捷键冲突；显示器插拔 / 排列变化会实时刷新。

## 系统要求

- macOS 13 或更新版本。
- 已安装 Xcode Command Line Tools：

  ```bash
  xcode-select --install
  ```

## 构建

在项目根目录执行：

```bash
chmod +x build.sh
./build.sh
```

完成后产物在 `build/` 下：

- `build/ScreenMouseSwitcher.app` — 应用本体
- `build/ScreenMouseSwitcher-1.0.dmg` — 拖拽安装包

## 安装与授权

1. 从 [GitHub Releases](https://github.com/matthew-pan/ScreenMouseSwitcher/releases/latest) 下载并打开 `ScreenMouseSwitcher-1.0.dmg`，把 **屏幕鼠标切换** 拖到 `Applications`。
2. 首次打开（未签名版）：在 `应用程序` 里 **右键 → 打开**，在弹窗中确认「打开」，以绕过 Gatekeeper。
3. 首次运行会提示授予「辅助功能」权限。到 **系统设置 → 隐私与安全性 → 辅助功能**，勾选「屏幕鼠标切换」。菜单里也有「打开辅助功能设置…」快捷入口。
4. 授权后菜单栏状态变为「监听中」，即可用快捷键切换。

升级或重新部署时，请先退出并删除旧版 App，再安装新版；随后在「辅助功能」中删除旧记录并重新添加 `/Applications/ScreenMouseSwitcher.app`。只运行 `/Applications` 中的安装版本，不要直接运行项目 `build/` 目录中的 App。

菜单栏图标菜单包含：

- **设置…** —— 打开可视化设置面板配置快捷键。
- **开机自启** —— 开关登录时自动启动。
- **打开「辅助功能」设置…**
- **退出**

## 快捷键说明

在菜单栏 **设置…** 里配置：

- **方向键切换**：勾选启用后，点按「快捷键」输入框录入修饰键（默认 `⌘⌃`）。`修饰键+→` 始终按排列顺序循环切到下一屏；`修饰键+←/↑/↓` 按显示器的实际排列跳到对应方向。
- **每屏直达**：勾选启用后，在排列图里点选某块屏，点按输入框直接按下想要的组合键即可录入，之后按该组合直接跳到那块屏。

录入时：需包含至少一个修饰键（⌘⌥⌃⇧）；按 `Esc` 取消当前录入；「清除该屏」可移除某屏的直达键。

默认 `⌘⌃ + 方向键` 不与系统「切换空间」`⌃ + 方向键` 冲突。若想改默认修饰键，可编辑 `Sources/ScreenMouseSwitcher/AppConfig.swift` 里 `AppConfig.default`，或直接在设置面板里改。

> 说明：每屏直达按「屏幕排列序号」（左→右、上→下）保存；更换显示器排列后序号会按新排列重新映射。

## 项目结构

```
.
├── Package.swift                     # SwiftPM 清单
├── build.sh                          # 编译 + 组装 .app + 打 dmg
├── Sources/ScreenMouseSwitcher/
│   ├── main.swift                    # 入口（.accessory 后台运行）
│   ├── AppDelegate.swift             # 菜单栏、授权、开机自启、设置入口
│   ├── AppConfig.swift               # 配置模型 + UserDefaults 持久化 + keyCode 标签
│   ├── ScreenLayout.swift            # 屏幕排列排序 + 方向相邻查找
│   ├── KeyRecorderView.swift         # 录入式快捷键控件
│   ├── HotkeyManager.swift           # CGEventTap 全局热键（按配置多绑定匹配）
│   ├── MouseMover.swift              # 移动鼠标到指定屏/方向/直达
│   ├── ArrangementView.swift         # 可视化「显示器排列」缩略图
│   └── SettingsWindowController.swift# 设置面板
├── scripts/make_icon.swift           # 生成 App 图标
└── docs/superpowers/specs/           # 设计文档
```

## 安装包

https://github.com/matthew-pan/ScreenMouseSwitcher/releases/tag/v1.0

## 版本历史

- **v1.0**（首个正式版）—— 菜单栏后台运行、开机自启、辅助功能授权引导；可视化设置面板（按显示器真实排列画缩略图）；支持**方向键切换**（`⌘⌃←/→/↑/↓` 跳相邻屏）与**每屏直达**（每块屏单配一个快捷键）；快捷键采用**录入式**输入；保存时冲突检测、显示器热插拔实时刷新；打包通用 `.dmg`。
