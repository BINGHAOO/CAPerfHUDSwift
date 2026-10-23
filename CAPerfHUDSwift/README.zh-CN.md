# CAPerfHUDSwift

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

中文 | [English](./README.md)

[CAPerfHUD](https://github.com/khanhduytran0/CAPerfHUD) 的 Swift 重写版。控制 iOS 上的 Core Animation 性能 HUD。同一套代码编译出 **两个版本**：

| | 巨魔版（TrollStore） | 越狱版（Jailbreak） |
|---|---|---|
| 安装包 | `CAPerfHUD-TrollStore.tipa` | `CAPerfHUD-{rootful,rootless,roothide}.deb` |
| 安装方式 | TrollStore | Sileo / Zebra / Cydia / `dpkg -i` |
| 系统 HUD 级别切换 | ✅ | ✅ |
| 跨应用自定义悬浮窗 | ❌ | ✅（内置 SpringBoard 插件） |
| 悬浮窗外观设置 | ❌ | ✅ |

越狱版针对三种越狱类型分别构建：

| 变体 | 适用越狱 | 安装位置 | 包架构 |
|---|---|---|---|
| `CAPerfHUD-rootful.deb` | unc0ver、palera1n rootful、checkra1n | `/Applications` + `/Library/MobileSubstrate/...` | `iphoneos-arm64e` |
| `CAPerfHUD-rootless.deb` | Dopamine、palera1n rootless | `/var/jb/Applications` + `/var/jb/Library/...`（自动重映射） | `iphoneos-arm64` |
| `CAPerfHUD-roothide.deb` | roothide（隐藏越狱的 Dopamine 分支） | jbroot（由 roothide 映射） | `iphoneos-arm64` |

## 功能

- **系统 HUD 级别切换** — 在 10 个内置 Core Animation 性能 HUD 级别之间切换（关闭、基础、背景、粒子、完整、频率、功耗、仅帧率、显示、故障）。两个版本均支持。
- **跨应用自定义悬浮窗（越狱版）** — 一个 SpringBoard 插件，在所有应用之上绘制悬浮 HUD。完全可配置：字体大小、位置、尺寸、颜色、透明度、圆角、边框。
- **拖动移动** — 自定义悬浮窗可拖动到屏幕任意位置。
- **中英双语界面** — 支持英文和简体中文，可在应用内切换。
- **版本标识** — 「关于」页显示当前运行的版本类型（巨魔版 / 越狱版）。

## 系统要求

- iOS 15.0+
- 系统 HUD 控制需要 `com.apple.QuartzCore.debug` 权限 — `.tipa` 通过 `ldid` 签名注入该权限（TrollStore 可用），`.deb` 内的应用同样签名（越狱设备可用）。
- 跨应用自定义悬浮窗需要越狱设备。

## 安装

### 巨魔版（`.tipa`）

1. 从 [Releases](https://github.com/BINGHAOO/CAPerfHUDSwift/releases) 页面下载最新的 `CAPerfHUD-TrollStore.tipa`。
2. 通过 TrollStore 安装。

巨魔版只控制系统 **HUD**，不包含外观设置和自定义悬浮窗。

### 越狱版（`.deb`）

1. 从 [Releases](https://github.com/BINGHAOO/CAPerfHUDSwift/releases) 页面下载与你的越狱类型匹配的 `CAPerfHUD-{rootful|rootless|roothide}.deb`。
2. 通过包管理器（Sileo、Zebra、Cydia）安装，或使用 `dpkg -i`。
3. 注销（Respring）。

`.deb` 包含 **两部分**：

- 控制应用（系统 HUD 级别 + 悬浮窗外观设置）— 安装到 `/Applications`（rootful）、`/var/jb/Applications`（rootless）或 jbroot 的 Applications 目录（roothide）。
- `/Library/MobileSubstrate/DynamicLibraries/CAPerfHUDOverlay.dylib`（或对应的 `/var/jb` / jbroot 路径）— SpringBoard 插件。

> 不确定用哪个变体？**Dopamine** 和 **palera1n (rootless)** → `rootless`。**roothide** → `roothide`。**unc0ver / checkra1n / palera1n rootful** → `rootful`。

### 两个版本能同时安装吗？

可以 — 越狱版使用不同的 Bundle ID（`com.binghaoo.CAPerfHUDJB`），两个版本可以在同一台设备上共存。即使你在设备上隐藏了 TrollStore / 越狱环境也不影响使用：本项目不依赖任何环境检测。

## 使用方法

### 系统 HUD（两个版本均可用）

1. 打开应用。
2. 在 **HUD** 标签页中，点击某个级别以启用系统性能 HUD，点击 **关闭** 即可关闭。

### 自定义悬浮窗（越狱版）

1. 安装越狱版 `.deb`（见上文）并注销。
2. 打开应用 → **设置** → **高级** → 开启 **自定义悬浮窗（越狱）**。
3. 在 **设置** → **外观** 中调整：
   - 宽度 / 高度 — 悬浮窗尺寸。
   - 水平 (X) / 垂直 (Y) — 相对于顶部居中的位置偏移。
   - 字体大小 — **系统 HUD 的字体无法修改**，但自定义悬浮窗会使用此值。默认 12 pt；如果文字太小请调大。
   - 背景透明度 / 圆角 — 背景样式。
   - 文字颜色 / 背景颜色 — 任意颜色。
   - 显示边框 — 添加边框并设置宽度。
4. 拖动悬浮窗可重新定位。设置自动保存。

> 应用与插件通过共享 plist `/var/mobile/Library/Preferences/com.binghaoo.caperfhud.plist` 通信。应用将设置写入该文件并发送 Darwin 通知，插件读取后重绘悬浮窗。

> **字体大小说明：** iOS 内置的系统 HUD 字体大小由 QuartzCore 硬编码，无法通过公开或私有 API 修改。如需更大的文字，请使用自定义悬浮窗插件，可设置任意字体大小。

## 构建

### 前置条件

- macOS + Xcode 15+
- `ldid`（`brew install ldid`）
- 构建越狱版：[Theos](https://theos.dev/)

### 构建巨魔版（`.tipa`）

```bash
./ipabuild.sh
```

输出文件为 `build/CAPerfHUD-TrollStore.tipa`。

### 构建越狱版（`.deb`）

```bash
# 1. 构建应用（带 JAILBREAK 编译条件，ldid 签名）
./ipabuild.sh --jailbreak

# 2. 构建插件 .deb（自动把 .app 打包进 /Applications）
cd tweak
make package FINALPACKAGE=1                                    # rootful
THEOS_PACKAGE_SCHEME=rootless make package FINALPACKAGE=1      # rootless (Dopamine)
THEOS_PACKAGE_SCHEME=rootless make package FINALPACKAGE=1 \
    THEOS=$HOME/theos-roothide                                 # roothide（需 roothide/theos）
```

输出文件在 `tweak/packages/` 目录中。rootless/roothide 方案会自动把所有路径重映射到 `/var/jb`（或 jbroot 前缀），无需修改源码 — 应用与插件通信的 plist 位于 `/var/mobile/Library/Preferences/`，在所有越狱类型下位置相同。

## GitHub Actions

推送 `v*` 标签会触发工作流，自动构建 **两个版本**（以及三种越狱类型的 `.deb`）并发布到 GitHub Release：

```bash
git tag v1.6.0
git push origin v1.6.0
```

## 架构

```
巨魔版 (.tipa)                         越狱版 (.deb)
┌────────────────────────┐             ┌──────────────────────────────┐
│  CAPerfHUDSwift 应用   │             │  /Applications/CAPerfHUDSwift│
│  • 系统 HUD 级别       │             │  • 系统 HUD 级别控制         │
│    通过 QuartzCore     │             │  • 悬浮窗外观设置            │
│  （无插件、无 plist）  │             │  • 写入共享 plist            │
└────────────────────────┘             │  • Darwin 通知               │
                                       ├──────────────────────────────┤
                                       │  SpringBoard 插件            │
                                       │  • UIWindow (高优先级)       │
                                       │  • HUDOverlayView            │
                                       │    - FPS (CADisplayLink)     │
                                       │    - 内存 (task_info)        │
                                       │    - CPU (host_statistics)   │
                                       └──────────────────────────────┘
```

- 两个版本由同一套源码编译，使用 `JAILBREAK` Swift 编译条件区分（`./ipabuild.sh --jailbreak` 传入 `SWIFT_ACTIVE_COMPILATION_CONDITIONS=JAILBREAK`）。
- 系统 HUD 通过 `CARenderServerSetDebugOption` / `CARenderServerSetDebugValue` 控制。渲染服务器只接受 **级别** 参数，外观参数（字体、尺寸、位置等）未暴露。
- 自定义悬浮窗是一个 `UIWindow`，`windowLevel = UIWindowLevelAlert + 1000`，添加在 SpringBoard 中，因此悬浮于所有应用之上。

## 已知限制

- 系统 HUD 的字体大小、位置和尺寸由 QuartzCore 硬编码，**无法**修改。需要完全的外观控制请使用越狱版的自定义悬浮窗。
- 未越狱时，应用无法在其他应用之上绘制窗口 — 因此巨魔版不包含悬浮窗功能。
- 自定义悬浮窗目前不显示 GPU 指标（无稳定的私有 API）。

## 致谢

- [khanhduytran0/CAPerfHUD](https://github.com/khanhduytran0/CAPerfHUD) — 原始 Objective-C 实现。
- [bryce.co — On-Device Render Debugging](https://bryce.co/on-device-render-debugging/) — QuartzCore 调试调用的 Swift 参考。

## 许可证

MIT © Hariz Shirazi
