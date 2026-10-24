// bomberfish
// HudSettings.swift – CAPerfHudSwift
// created on 2026-10-22

import Foundation
import SwiftUI

/// Shared prefs domain used to communicate with the SpringBoard tweak.
let kCAPerfHUDPrefsDomain = "com.binghaoo.caperfhud"
let kCAPerfHUDSettingsChangedNotification = "com.binghaoo.caperfhud/settingsChanged"

/// Manages all HUD appearance settings with persistence to UserDefaults.
/// When `useCustomOverlay` is on, settings are also synced to a shared plist
/// that the CAPerfHUDOverlay SpringBoard tweak reads.
final class HudSettings: ObservableObject {
    static let shared = HudSettings()

    // MARK: - Custom Overlay (jailbreak)
    @Published var useCustomOverlay: Bool {
        didSet {
            UserDefaults.standard.set(useCustomOverlay, forKey: "HUDUseCustomOverlay")
            scheduleSync()
        }
    }

    // MARK: - HUD Level (persisted)
    @Published var hudLevel: Int32 {
        didSet { UserDefaults.standard.set(Int(hudLevel), forKey: "HUDLevel") }
    }

    // MARK: - Window Size
    @Published var windowWidth: Double {
        didSet { UserDefaults.standard.set(windowWidth, forKey: "HUDWindowWidth"); scheduleSync() }
    }
    @Published var windowHeight: Double {
        didSet { UserDefaults.standard.set(windowHeight, forKey: "HUDWindowHeight"); scheduleSync() }
    }

    // MARK: - Typography & Colors
    @Published var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: "HUDFontSize"); scheduleSync() }
    }
    @Published var backgroundOpacity: Double {
        didSet { UserDefaults.standard.set(backgroundOpacity, forKey: "HUDBackgroundOpacity"); scheduleSync() }
    }
    @Published var cornerRadius: Double {
        didSet { UserDefaults.standard.set(cornerRadius, forKey: "HUDCornerRadius"); scheduleSync() }
    }
    @Published var textColorHex: String {
        didSet { UserDefaults.standard.set(textColorHex, forKey: "HUDTextColor"); scheduleSync() }
    }
    @Published var bgColorHex: String {
        didSet { UserDefaults.standard.set(bgColorHex, forKey: "HUDBgColor"); scheduleSync() }
    }

    // MARK: - Border
    @Published var showBorder: Bool {
        didSet { UserDefaults.standard.set(showBorder, forKey: "HUDShowBorder"); scheduleSync() }
    }
    @Published var borderWidth: Double {
        didSet { UserDefaults.standard.set(borderWidth, forKey: "HUDBorderWidth"); scheduleSync() }
    }

    // MARK: - Metric Visibility (custom overlay)
    @Published var showFPS: Bool {
        didSet { UserDefaults.standard.set(showFPS, forKey: "HUDShowFPS"); scheduleSync() }
    }
    @Published var showCPU: Bool {
        didSet { UserDefaults.standard.set(showCPU, forKey: "HUDShowCPU"); scheduleSync() }
    }
    @Published var showMemory: Bool {
        didSet { UserDefaults.standard.set(showMemory, forKey: "HUDShowMemory"); scheduleSync() }
    }
    @Published var showTemperature: Bool {
        didSet { UserDefaults.standard.set(showTemperature, forKey: "HUDShowTemperature"); scheduleSync() }
    }
    @Published var showPower: Bool {
        didSet { UserDefaults.standard.set(showPower, forKey: "HUDShowPower"); scheduleSync() }
    }
    @Published var showNetwork: Bool {
        didSet { UserDefaults.standard.set(showNetwork, forKey: "HUDShowNetwork"); scheduleSync() }
    }
    @Published var showBattery: Bool {
        didSet { UserDefaults.standard.set(showBattery, forKey: "HUDShowBattery"); scheduleSync() }
    }

    // MARK: - Text Alignment & Auto Height (custom overlay)
    /// 0 = left, 1 = center, 2 = right.
    @Published var textAlignment: Int {
        didSet { UserDefaults.standard.set(textAlignment, forKey: "HUDTextAlignment"); scheduleSync() }
    }
    @Published var autoHeight: Bool {
        didSet { UserDefaults.standard.set(autoHeight, forKey: "HUDAutoHeight"); scheduleSync() }
    }

    // MARK: - Behavior
    @Published var autoApplyOnLaunch: Bool {
        didSet { UserDefaults.standard.set(autoApplyOnLaunch, forKey: "HUDAutoApply") }
    }
    @Published var hapticFeedback: Bool {
        didSet { UserDefaults.standard.set(hapticFeedback, forKey: "HUDHaptic") }
    }

    // MARK: - Debounce
    #if JAILBREAK
    private var syncWorkItem: DispatchWorkItem?
    #endif

    // MARK: - Defaults
    private init() {
        let defaults = UserDefaults.standard

        // Jailbreak edition: the custom overlay is the headline feature, so it
        // starts enabled – the user sees right after respring that the tweak
        // pipeline works, and can switch back to the system HUD in this app.
        #if JAILBREAK
        let overlayDefault = true
        #else
        let overlayDefault = false
        #endif
        self.useCustomOverlay = defaults.object(forKey: "HUDUseCustomOverlay") as? Bool ?? overlayDefault

        self.hudLevel = Int32(defaults.integer(forKey: "HUDLevel"))

        self.windowWidth = defaults.object(forKey: "HUDWindowWidth") as? Double ?? 220
        self.windowHeight = defaults.object(forKey: "HUDWindowHeight") as? Double ?? 80

        self.fontSize = defaults.object(forKey: "HUDFontSize") as? Double ?? 12
        self.backgroundOpacity = defaults.object(forKey: "HUDBackgroundOpacity") as? Double ?? 0.7
        self.cornerRadius = defaults.object(forKey: "HUDCornerRadius") as? Double ?? 12
        self.textColorHex = defaults.string(forKey: "HUDTextColor") ?? "#FFFFFF"
        self.bgColorHex = defaults.string(forKey: "HUDBgColor") ?? "#000000"

        self.showBorder = defaults.bool(forKey: "HUDShowBorder")
        self.borderWidth = defaults.object(forKey: "HUDBorderWidth") as? Double ?? 1

        // Metrics default to the classic FPS/CPU/MEM set; the extras stay off
        // until the user opts in.
        self.showFPS = defaults.object(forKey: "HUDShowFPS") as? Bool ?? true
        self.showCPU = defaults.object(forKey: "HUDShowCPU") as? Bool ?? true
        self.showMemory = defaults.object(forKey: "HUDShowMemory") as? Bool ?? true
        self.showTemperature = defaults.object(forKey: "HUDShowTemperature") as? Bool ?? false
        self.showPower = defaults.object(forKey: "HUDShowPower") as? Bool ?? false
        self.showNetwork = defaults.object(forKey: "HUDShowNetwork") as? Bool ?? false
        self.showBattery = defaults.object(forKey: "HUDShowBattery") as? Bool ?? false

        self.textAlignment = defaults.object(forKey: "HUDTextAlignment") as? Int ?? 1
        self.autoHeight = defaults.object(forKey: "HUDAutoHeight") as? Bool ?? true

        self.autoApplyOnLaunch = defaults.object(forKey: "HUDAutoApply") as? Bool ?? true
        self.hapticFeedback = defaults.object(forKey: "HUDHaptic") as? Bool ?? true
    }

    // MARK: - Reset
    func resetAll() {
        #if JAILBREAK
        useCustomOverlay = true
        #else
        useCustomOverlay = false
        #endif
        hudLevel = 0
        windowWidth = 220
        windowHeight = 80
        fontSize = 12
        backgroundOpacity = 0.7
        cornerRadius = 12
        textColorHex = "#FFFFFF"
        bgColorHex = "#000000"
        showBorder = false
        borderWidth = 1
        showFPS = true
        showCPU = true
        showMemory = true
        showTemperature = false
        showPower = false
        showNetwork = false
        showBattery = false
        textAlignment = 1
        autoHeight = true
        autoApplyOnLaunch = true
        hapticFeedback = true
        syncToSharedPrefs()
    }

    // MARK: - Apply on launch
    /// Re-applies the stored settings on app launch.
    /// NOTE: the system HUD only honours the level selector – QuartzCore has
    /// no setters for size/position/opacity, and writing unknown debug value
    /// slots disturbs the render server (visible as wallpaper flicker).
    func applyAppearance() {
        #if JAILBREAK
        // Jailbreak edition: push everything to the tweak overlay.
        syncToSharedPrefs()
        #else
        // TrollStore edition: restore the last system HUD level.
        CADebugCommon.setPerfHUDLevel(hudLevel)
        #endif
    }

    // MARK: - Shared prefs sync (for SpringBoard tweak)

    /// Debounced sync: batches rapid slider changes into one plist write.
    /// Only compiled into the jailbreak edition (there is no tweak to talk to
    /// in the TrollStore edition).
    private func scheduleSync() {
        #if JAILBREAK
        syncWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.syncToSharedPrefs()
        }
        syncWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
        #endif
    }

    /// Writes all appearance settings to every location the SpringBoard tweak
    /// may look at, and posts a Darwin notification so it reloads them.
    func syncToSharedPrefs() {
        #if JAILBREAK
        let dict: [String: Any] = [
            "enabled": useCustomOverlay,
            "windowWidth": windowWidth,
            "windowHeight": windowHeight,
            "fontSize": fontSize,
            "backgroundOpacity": backgroundOpacity,
            "cornerRadius": cornerRadius,
            "textColorHex": textColorHex,
            "bgColorHex": bgColorHex,
            "showBorder": showBorder,
            "borderWidth": borderWidth,
            "showFPS": showFPS,
            "showCPU": showCPU,
            "showMemory": showMemory,
            "showTemperature": showTemperature,
            "showPower": showPower,
            "showNetwork": showNetwork,
            "showBattery": showBattery,
            "textAlignment": textAlignment,
            "autoHeight": autoHeight
        ]

        // 1. Defaults suite. This is the guaranteed channel: even when the
        //    app is containerized/sandboxed, cfprefsd can always persist the
        //    app's own defaults plist (inside the app data container), which
        //    the tweak discovers by scanning the containers.
        let suite = UserDefaults(suiteName: kCAPerfHUDPrefsDomain)
        for (key, value) in dict {
            suite?.set(value, forKey: key)
        }
        suite?.synchronize()

        // 2. Direct plist writes (work when the app is not sandboxed).
        guard let data = try? PropertyListSerialization.data(fromPropertyList: dict,
                                                             format: .xml,
                                                             options: 0) else {
            return
        }

        // Never direct-write the suite's own file: cfprefsd owns it and would
        // overwrite the change from its cache.
        let suitePath = Self.suitePrefsPath()
        for path in Self.directPrefsPaths() where path != suitePath {
            try? data.write(to: URL(fileURLWithPath: path))
        }

        // Notify the tweak.
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(kCAPerfHUDSettingsChangedNotification as CFString),
            nil, nil, true
        )
        #endif
    }

    #if JAILBREAK
    /// Where the defaults suite plist lives (inside the app data container on
    /// iOS, or $HOME/Library/Preferences for unsandboxed processes).
    static func suitePrefsPath() -> String {
        return NSHomeDirectory() + "/Library/Preferences/\(kCAPerfHUDPrefsDomain).plist"
    }

    /// Direct plist locations shared with the SpringBoard tweak.
    static func directPrefsPaths() -> [String] {
        var paths = ["/var/mobile/Library/Preferences/\(kCAPerfHUDPrefsDomain).plist"]
        if let jbroot = jbrootPath() {
            paths.append("\(jbroot)/var/mobile/Library/Preferences/\(kCAPerfHUDPrefsDomain).plist")
        }
        return paths
    }

    /// Derives the roothide jbroot prefix from the app bundle path
    /// ("/var/containers/Bundle/Application/.jbroot-XXXXXXXX/..."), if any.
    static func jbrootPath() -> String? {
        let bundle = Bundle.main.bundlePath
        guard let marker = bundle.range(of: "/.jbroot-") else { return nil }
        let afterMarker = bundle[marker.upperBound...]
        guard let slash = afterMarker.firstIndex(of: "/") else { return nil }
        return String(bundle[..<marker.lowerBound] + "/" + afterMarker[..<slash])
    }
    #endif
}

// MARK: - Color Helpers
extension HudSettings {
    var textColor: Color {
        Color(hex: textColorHex) ?? .white
    }

    var bgColor: Color {
        Color(hex: bgColorHex) ?? .black
    }
}

extension Color {
    /// Initialize a Color from a hex string like "#RRGGBB" or "#RRGGBBAA".
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let length = hexSanitized.count
        let r, g, b, a: Double
        switch length {
        case 6: // RGB
            r = Double((rgb >> 16) & 0xFF) / 255.0
            g = Double((rgb >> 8) & 0xFF) / 255.0
            b = Double(rgb & 0xFF) / 255.0
            a = 1.0
        case 8: // RGBA
            r = Double((rgb >> 24) & 0xFF) / 255.0
            g = Double((rgb >> 16) & 0xFF) / 255.0
            b = Double((rgb >> 8) & 0xFF) / 255.0
            a = Double(rgb & 0xFF) / 255.0
        default:
            return nil
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// Convert the color to a hex string "#RRGGBB".
    func toHex() -> String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X",
                      Int(round(r * 255)),
                      Int(round(g * 255)),
                      Int(round(b * 255)))
    }
}
