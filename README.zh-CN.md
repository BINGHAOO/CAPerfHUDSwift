# CAPerfHUDSwift

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

中文 | [English](./README.md)

[CAPerfHUD](https://github.com/khanhduytran0/CAPerfHUD) 的 Swift 重写版。控制 iOS 上的 Core Animation 性能 HUD，并为越狱设备提供可选的跨应用自定义悬浮窗。

## 功能

- **系统 HUD 级别切换** — 在 10 个内置 Core Animation 性能 HUD 级别之间切换（关闭、基础、背景、粒子、完整、频率、功耗、仅帧率、显示、故障）。
- **跨应用自定义悬浮窗（越狱）** — 一个 SpringBoard 插件，在所有应用之上绘制悬浮 HUD。完全可配置：字体大小、位置、尺寸、颜色、透明度、圆角、边框。
- **外观设置** — 调整宽度、高度、X/Y 位置、字体大小、背景透明度、圆角、文字颜色、背景颜色和边框。
- **中英双语界面** — 支持英文和简体中文，可在应用内切换。
- **高级选项** — 跨启动持久化、启动时自动应用、触觉反馈。
- **拖动移动** — 自定义悬浮窗可拖动到屏幕任意位置。

## 系统要求

- iOS 15.0+
- 控制系统 HUD：需要 `com.apple.QuartzCore.debug` 权限（TrollStore 签名的应用可用）。
- 使用跨应用自定义悬浮窗：需要越狱设备。

## 安装

### 应用（`.tipa`）— TrollStore

1. 从 [Releases](https://github.com/BINGHAOO/CAPerfHUDSwift/releases) 页面下载最新的 `CAPerfHUDSwift.tipa`。
2. 通过 TrollStore 安装。

### 插件（`.deb`）— 越狱

1. 从 [Releases](https://github.com/BINGHAOO/CAPerfHUDSwift/releases) 页面下载最新的 `com.binghaoo.caperfhud.overlay_*.deb`。
2. 通过包管理器（Sileo、Zebra、Cydia）安装，或使用 `dpkg -i`。
3. 注销（Respring）。
4. 打开 CAPerfHUDSwift 应用，在 设置 → 高级 中开启 **自定义悬浮窗（越狱）**。

> 插件与应用通过共享 plist `/var/mobile/Library/Preferences/com.binghaoo.caperfhud.plist` 通信。应用将设置写入该文件并发送 Darwin 通知，插件读取后重绘悬浮窗。

## 使用方法

### 系统 HUD

1. 打开应用。
2. 在 **HUD** 标签页中，点击某个级别以启用系统性能 HUD。
3. 使用顶部的 **快速开关** 快速开启/关闭。

### 自定义悬浮窗（越狱）

1. 安装 `CAPerfHUDOverlay` `.deb`（见上文）。
2. 打开应用 → **设置** → **高级** → 开启 **自定义悬浮窗（越狱）**。
3. 在 **设置** → **外观** 中调整：
   - 宽度 / 高度 — 悬浮窗尺寸。
   - 水平 (X) / 垂直 (Y) — 相对于顶部居中的位置偏移。
   - 字体大小 — **系统 HUD 的字体无法修改**，但自定义悬浮窗会使用此值。默认 12 pt；如果文字太小请调大。
   - 背景透明度 / 圆角 — 背景样式。
   - 文字颜色 / 背景颜色 — 任意颜色。
   - 显示边框 — 添加边框并设置宽度。
4. 拖动悬浮窗可重新定位。设置自动保存。

> **字体大小说明：** iOS 内置的系统 HUD 字体大小由 QuartzCore 硬编码，无法通过公开或私有 API 修改。如需更大的文字，请使用自定义悬浮窗插件，可设置任意字体大小。

## 构建

### 前置条件

- macOS + Xcode 15+
- `ldid`（`brew install ldid`）
- 构建插件：[Theos](https://theos.dev/)

### 构建应用（`.tipa`）

```bash
./ipabuild.sh
```

输出文件为 `build/CAPerfHUDSwift.tipa`。

### 构建插件（`.deb`）

```bash
cd tweak
make package FINALPACKAGE=1
```

输出文件在 `tweak/packages/` 目录中。

## GitHub Actions

推送 `v*` 标签会触发工作流，自动构建 `.tipa` 和 `.deb` 并发布到 GitHub Release：

```bash
git tag v1.3.0
git push origin v1.3.0
```

## 架构

```
应用 (.tipa, TrollStore)            SpringBoard 插件 (.deb)
┌──────────────────────┐         ┌──────────────────────────┐
│  CAPerfHUDSwift      │         │  CAPerfHUDOverlay         │
│  ─────────────────   │         │  ───────────────────────  │
│  • 系统 HUD 级别     │         │  • UIWindow (高优先级)    │
│    通过 QuartzCore   │         │  • HUDOverlayView         │
│  • 外观设置          │ ──IPC──▶│    - FPS (CADisplayLink)  │
│  • 写入共享 plist    │         │    - 内存 (task_info)     │
│  • Darwin 通知       │         │    - CPU (host_statistics)│
└──────────────────────┘         └──────────────────────────┘
```

- 系统 HUD 通过 `CARenderServerSetDebugOption` / `CARenderServerSetDebugValue` 控制。渲染服务器只接受 **级别** 参数，外观参数（字体、尺寸、位置等）未暴露。
- 自定义悬浮窗是一个 `UIWindow`，`windowLevel = UIWindowLevelAlert + 1000`，添加在 SpringBoard 中，因此悬浮于所有应用之上。

## 已知限制

- 系统 HUD 的字体大小、位置和尺寸由 QuartzCore 硬编码，**无法**修改。请使用自定义悬浮窗插件以获得完全的外观控制。
- 未越狱时，应用无法在其他应用之上绘制窗口。自定义悬浮窗需要越狱设备。
- 自定义悬浮窗目前不显示 GPU 指标（无稳定的私有 API）。

## 致谢

- [khanhduytran0/CAPerfHUD](https://github.com/khanhduytran0/CAPerfHUD) — 原始 Objective-C 实现。
- [bryce.co — On-Device Render Debugging](https://bryce.co/on-device-render-debugging/) — QuartzCore 调试调用的 Swift 参考。

## 许可证

MIT © Hariz Shirazi
