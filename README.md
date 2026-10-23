# CAPerfHUDSwift

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

[中文](./README.zh-CN.md) | English

A Swift alternative to [CAPerfHUD](https://github.com/khanhduytran0/CAPerfHUD). Controls the Core Animation performance HUD on iOS. Ships as **two editions** built from the same codebase:

| | TrollStore Edition | Jailbreak Edition |
|---|---|---|
| Package | `CAPerfHUD-TrollStore.tipa` | `com.binghaoo.caperfhud_*.deb` |
| Install via | TrollStore | Sileo / Zebra / Cydia / `dpkg -i` |
| System HUD level control | ✅ | ✅ |
| Cross-app custom overlay | ❌ | ✅ (SpringBoard tweak included) |
| Overlay appearance settings | ❌ | ✅ |

## Features

- **System HUD Level Control** — Switch between the 10 built-in Core Animation perf HUD levels (Off, Basic, Backdrop, Particles, Full, Frequencies, Power, FPS only, Display, Glitches). Available in both editions.
- **Cross-App Custom Overlay (Jailbreak Edition)** — A SpringBoard tweak that draws a floating HUD over every app. Fully configurable: font size, position, size, colors, opacity, corner radius, border.
- **Drag to Move** — The custom overlay can be dragged anywhere on screen.
- **Bilingual UI** — English and Simplified Chinese, switchable from within the app.
- **Edition Badge** — The About tab shows which edition you are running (TrollStore or Jailbreak).

## Requirements

- iOS 15.0+
- System HUD control requires the `com.apple.QuartzCore.debug` entitlement — the `.tipa` is signed with it via `ldid` (works through TrollStore), and the `.deb` app is signed the same way (works on jailbroken devices).
- The cross-app custom overlay requires a jailbroken device.

## Installation

### TrollStore Edition (`.tipa`)

1. Download the latest `CAPerfHUD-TrollStore.tipa` from the [Releases](https://github.com/BINGHAOO/CAPerfHUDSwift/releases) page.
2. Install it via TrollStore.

The TrollStore edition only controls the **system HUD** — appearance settings and the custom overlay are not included.

### Jailbreak Edition (`.deb`)

1. Download the latest `com.binghaoo.caperfhud_*.deb` from the [Releases](https://github.com/BINGHAOO/CAPerfHUDSwift/releases) page.
2. Install it via your package manager (Sileo, Zebra, Cydia) or with `dpkg -i`.
3. Respring.

The `.deb` installs **both**:

- `/Applications/CAPerfHUDSwift.app` — the control app (system HUD levels + overlay appearance settings).
- `/Library/MobileSubstrate/DynamicLibraries/CAPerfHUDOverlay.dylib` — the SpringBoard tweak.

### Can I install both editions?

Yes — the jailbreak edition uses a different bundle identifier (`com.binghaoo.CAPerfHUDJB`), so the two editions can coexist on the same device. Note that if you hide TrollStore / jailbreak on your device, both still work; the detection-free design means nothing depends on detecting your environment.

## Usage

### System HUD (both editions)

1. Open the app.
2. On the **HUD** tab, tap a level to enable the system performance HUD. Tap **Off** to disable it.

### Custom Overlay (Jailbreak Edition)

1. Install the jailbreak edition `.deb` (see above) and respring.
2. Open the app → **Settings** → **Advanced** → enable **Custom Overlay (Jailbreak)**.
3. Adjust appearance in **Settings** → **Appearance**:
   - Width / Height — overlay window size.
   - Horizontal (X) / Vertical (Y) — position offset from the top-center.
   - Font Size — **the system HUD font cannot be changed**, but the custom overlay respects this value. Default is 12 pt; increase it if the text is too small.
   - Background Opacity / Corner Radius — background styling.
   - Text Color / Background Color — pick any color.
   - Show Border — add a border and set its width.
4. Drag the overlay to reposition it. Settings persist automatically.

> The app and the tweak communicate through a shared plist at `/var/mobile/Library/Preferences/com.binghaoo.caperfhud.plist`. The app writes your settings there and posts a Darwin notification; the tweak reads them and redraws the overlay.

> **Font size note:** The built-in iOS system HUD has a hardcoded font size that cannot be changed via public or private APIs. If you need larger text, use the Custom Overlay tweak, which lets you set any font size.

## Building

### Prerequisites

- macOS with Xcode 15+
- `ldid` (`brew install ldid`)
- For the jailbreak edition: [Theos](https://theos.dev/)

### Build the TrollStore Edition (`.tipa`)

```bash
./ipabuild.sh
```

The output is `build/CAPerfHUD-TrollStore.tipa`.

### Build the Jailbreak Edition (`.deb`)

```bash
# 1. Build the app (compiled with the JAILBREAK flag, signed with entitlements)
./ipabuild.sh --jailbreak

# 2. Build the tweak .deb (bundles the .app at /Applications)
cd tweak
make package FINALPACKAGE=1
```

The `.deb` output is in `tweak/packages/`.

## GitHub Actions

Pushing a `v*` tag triggers a workflow that builds **both editions** and publishes them to a GitHub Release:

```bash
git tag v1.5.0
git push origin v1.5.0
```

## Architecture

```
TrollStore Edition (.tipa)             Jailbreak Edition (.deb)
┌────────────────────────┐             ┌──────────────────────────────┐
│  CAPerfHUDSwift app    │             │  /Applications/CAPerfHUDSwift│
│  • System HUD level    │             │  • System HUD level control  │
│    via QuartzCore      │             │  • Overlay appearance prefs  │
│  (no tweak, no plist)  │             │  • Shared plist write        │
└────────────────────────┘             │  • Darwin notify             │
                                       ├──────────────────────────────┤
                                       │  SpringBoard tweak           │
                                       │  • UIWindow (high level)     │
                                       │  • HUDOverlayView            │
                                       │    - FPS (CADisplayLink)     │
                                       │    - Memory (task_info)      │
                                       │    - CPU (host_statistics)   │
                                       └──────────────────────────────┘
```

- The two editions are compiled from the same sources using the `JAILBREAK` Swift compilation condition (`./ipabuild.sh --jailbreak` passes `SWIFT_ACTIVE_COMPILATION_CONDITIONS=JAILBREAK`).
- The system HUD is controlled through `CARenderServerSetDebugOption` / `CARenderServerSetDebugValue`. Only the **level** is honoured by the render server; appearance slots (font, size, position, etc.) are not exposed.
- The custom overlay is a `UIWindow` with `windowLevel = UIWindowLevelAlert + 1000`, added in SpringBoard so it floats above all apps.

## Known Limitations

- The system HUD's font size, position, and dimensions are hardcoded in QuartzCore and **cannot** be changed. Use the Jailbreak Edition's Custom Overlay for full appearance control.
- Without jailbreak, an app cannot draw windows above other apps — that is why the TrollStore Edition does not include the overlay.
- GPU metrics are not currently shown in the custom overlay (no stable private API).

## Credits

- [khanhduytran0/CAPerfHUD](https://github.com/khanhduytran0/CAPerfHUD) — original Objective-C implementation.
- [bryce.co — On-Device Render Debugging](https://bryce.co/on-device-render-debugging/) — Swift reference for the QuartzCore debug calls.

## License

MIT © Hariz Shirazi
