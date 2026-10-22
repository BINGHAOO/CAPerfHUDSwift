# CAPerfHUDSwift

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

[中文](./README.zh-CN.md) | English

A Swift alternative to [CAPerfHUD](https://github.com/khanhduytran0/CAPerfHUD). Controls the Core Animation performance HUD on iOS, with an optional cross-app custom overlay for jailbroken devices.

## Features

- **System HUD Level Control** — Switch between the 10 built-in Core Animation perf HUD levels (Off, Basic, Backdrop, Particles, Full, Frequencies, Power, FPS only, Display, Glitches).
- **Cross-App Custom Overlay (Jailbreak)** — A SpringBoard tweak that draws a floating HUD over every app. Fully configurable: font size, position, size, colors, opacity, corner radius, border.
- **Appearance Settings** — Adjust width, height, X/Y position, font size, background opacity, corner radius, text color, background color, and border.
- **Bilingual UI** — English and Simplified Chinese, switchable from within the app.
- **Advanced Options** — Persist settings across launches, auto-apply on launch, haptic feedback.
- **Drag to Move** — The custom overlay can be dragged anywhere on screen.
- **Environment Detection** — Automatically detects jailbreak, TrollStore, and iOS version. Shows which features are available on your device and disables unsupported options with clear explanations.

## Requirements

- iOS 15.0+
- For the system HUD control: a device with the `com.apple.QuartzCore.debug` entitlement (works on TrollStore-signed apps).
- For the cross-app custom overlay: a jailbroken device.

## Installation

### App (`.tipa`) — TrollStore

1. Download the latest `CAPerfHUDSwift.tipa` from the [Releases](https://github.com/BINGHAOO/CAPerfHUDSwift/releases) page.
2. Install it via TrollStore.

### Tweak (`.deb`) — Jailbreak

1. Download the latest `com.binghaoo.caperfhud.overlay_*.deb` from the [Releases](https://github.com/BINGHAOO/CAPerfHUDSwift/releases) page.
2. Install it via your package manager (Sileo, Zebra, Cydia) or with `dpkg -i`.
3. Respring.
4. Open the CAPerfHUDSwift app and enable **Custom Overlay (Jailbreak)** in Settings → Advanced.

> The tweak and the app communicate through a shared plist at `/var/mobile/Library/Preferences/com.binghaoo.caperfhud.plist`. The app writes your settings there and posts a Darwin notification; the tweak reads them and redraws the overlay.

## Usage

### System HUD

1. Open the app.
2. On the **HUD** tab, tap a level to enable the system performance HUD.
3. Use the **Quick Toggle** at the top to turn it on/off quickly.

### Custom Overlay (Jailbreak)

1. Install the `CAPerfHUDOverlay` `.deb` (see above).
2. Open the app → **Settings** → **Advanced** → enable **Custom Overlay (Jailbreak)**.
3. Adjust appearance in **Settings** → **Appearance**:
   - Width / Height — overlay window size.
   - Horizontal (X) / Vertical (Y) — position offset from the top-center.
   - Font Size — **the system HUD font cannot be changed**, but the custom overlay respects this value. Default is 12 pt; increase it if the text is too small.
   - Background Opacity / Corner Radius — background styling.
   - Text Color / Background Color — pick any color.
   - Show Border — add a border and set its width.
4. Drag the overlay to reposition it. Settings persist automatically.

> **Font size note:** The built-in iOS system HUD has a hardcoded font size that cannot be changed via public or private APIs. If you need larger text, use the Custom Overlay tweak, which lets you set any font size.

## Environment Detection

The app automatically detects your runtime environment and shows what works on your device:

| Feature | TrollStore | Jailbreak | Stock / Sideloaded |
|---------|:----------:|:---------:|:------------------:|
| System HUD level switching | ✅ | ✅ | ❌ |
| Custom cross-app overlay | ❌ | ✅ (with tweak) | ❌ |
| Appearance settings (overlay) | ❌ | ✅ | ❌ |

- The **HUD** tab shows an "Environment" section with the detected status (iOS version, jailbreak, TrollStore) and whether each feature is available.
- If the system HUD is unavailable, the level selector is replaced with an explanation.
- If the custom overlay is unavailable (not jailbroken or tweak not installed), its toggle is disabled with a reason.
- The **About** tab lists the full environment report.

## Building

### Prerequisites

- macOS with Xcode 15+
- `ldid` (`brew install ldid`)
- For the tweak: [Theos](https://theos.dev/)

### Build the App (`.tipa`)

```bash
./ipabuild.sh
```

The output is `build/CAPerfHUDSwift.tipa`.

### Build the Tweak (`.deb`)

```bash
cd tweak
make package FINALPACKAGE=1
```

The output is in `tweak/packages/`.

## GitHub Actions

Pushing a `v*` tag triggers a workflow that builds both the `.tipa` and the `.deb` and publishes them to a GitHub Release:

```bash
git tag v1.3.0
git push origin v1.3.0
```

## Architecture

```
App (.tipa, TrollStore)          SpringBoard Tweak (.deb)
┌──────────────────────┐         ┌──────────────────────────┐
│  CAPerfHUDSwift      │         │  CAPerfHUDOverlay         │
│  ─────────────────   │         │  ───────────────────────  │
│  • System HUD level  │         │  • UIWindow (high level)  │
│    via QuartzCore    │         │  • HUDOverlayView         │
│  • Appearance prefs  │ ──IPC──▶│    - FPS (CADisplayLink)  │
│  • Shared plist write│         │    - Memory (task_info)   │
│  • Darwin notify     │         │    - CPU (host_statistics)│
└──────────────────────┘         └──────────────────────────┘
```

- The system HUD is controlled through `CARenderServerSetDebugOption` / `CARenderServerSetDebugValue`. Only the **level** is honoured by the render server; appearance slots (font, size, position, etc.) are not exposed.
- The custom overlay is a `UIWindow` with `windowLevel = UIWindowLevelAlert + 1000`, added in SpringBoard so it floats above all apps.

## Known Limitations

- The system HUD's font size, position, and dimensions are hardcoded in QuartzCore and **cannot** be changed. Use the Custom Overlay tweak for full appearance control.
- Without jailbreak, an app cannot draw windows above other apps. The Custom Overlay requires a jailbroken device.
- GPU metrics are not currently shown in the custom overlay (no stable private API).

## Credits

- [khanhduytran0/CAPerfHUD](https://github.com/khanhduytran0/CAPerfHUD) — original Objective-C implementation.
- [bryce.co — On-Device Render Debugging](https://bryce.co/on-device-render-debugging/) — Swift reference for the QuartzCore debug calls.

## License

MIT © Hariz Shirazi
