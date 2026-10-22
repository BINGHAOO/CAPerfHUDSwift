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

    // MARK: - Position
    @Published var positionX: Double {
        didSet { UserDefaults.standard.set(positionX, forKey: "HUDPositionX"); scheduleSync() }
    }
    @Published var positionY: Double {
        didSet { UserDefaults.standard.set(positionY, forKey: "HUDPositionY"); scheduleSync() }
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

    // MARK: - Behavior
    @Published var persistAcrossLaunches: Bool {
        didSet { UserDefaults.standard.set(persistAcrossLaunches, forKey: "HUDPersist") }
    }
    @Published var autoApplyOnLaunch: Bool {
        didSet { UserDefaults.standard.set(autoApplyOnLaunch, forKey: "HUDAutoApply") }
    }
    @Published var hapticFeedback: Bool {
        didSet { UserDefaults.standard.set(hapticFeedback, forKey: "HUDHaptic") }
    }

    // MARK: - Debounce
    private var syncWorkItem: DispatchWorkItem?

    // MARK: - Defaults
    private init() {
        let defaults = UserDefaults.standard

        self.useCustomOverlay = defaults.object(forKey: "HUDUseCustomOverlay") as? Bool ?? false

        self.hudLevel = Int32(defaults.integer(forKey: "HUDLevel"))

        self.windowWidth = defaults.object(forKey: "HUDWindowWidth") as? Double ?? 220
        self.windowHeight = defaults.object(forKey: "HUDWindowHeight") as? Double ?? 80

        self.positionX = defaults.object(forKey: "HUDPositionX") as? Double ?? 0
        self.positionY = defaults.object(forKey: "HUDPositionY") as? Double ?? 0

        self.fontSize = defaults.object(forKey: "HUDFontSize") as? Double ?? 12
        self.backgroundOpacity = defaults.object(forKey: "HUDBackgroundOpacity") as? Double ?? 0.7
        self.cornerRadius = defaults.object(forKey: "HUDCornerRadius") as? Double ?? 12
        self.textColorHex = defaults.string(forKey: "HUDTextColor") ?? "#FFFFFF"
        self.bgColorHex = defaults.string(forKey: "HUDBgColor") ?? "#000000"

        self.showBorder = defaults.bool(forKey: "HUDShowBorder")
        self.borderWidth = defaults.object(forKey: "HUDBorderWidth") as? Double ?? 1

        self.persistAcrossLaunches = defaults.object(forKey: "HUDPersist") as? Bool ?? true
        self.autoApplyOnLaunch = defaults.object(forKey: "HUDAutoApply") as? Bool ?? true
        self.hapticFeedback = defaults.object(forKey: "HUDHaptic") as? Bool ?? true
    }

    // MARK: - Reset
    func resetAll() {
        useCustomOverlay = false
        hudLevel = 0
        windowWidth = 220
        windowHeight = 80
        positionX = 0
        positionY = 0
        fontSize = 12
        backgroundOpacity = 0.7
        cornerRadius = 12
        textColorHex = "#FFFFFF"
        bgColorHex = "#000000"
        showBorder = false
        borderWidth = 1
        persistAcrossLaunches = true
        autoApplyOnLaunch = true
        hapticFeedback = true
        syncToSharedPrefs()
    }

    // MARK: - Apply to system HUD
    /// Pushes the current appearance settings to the Core Animation render server.
    /// The system HUD only honours the level selector; appearance slots are ignored
    /// on most iOS versions. Use the custom overlay tweak for full appearance control.
    func applyAppearance() {
        CADebugCommon.applyHudAppearance(
            fontSize: fontSize,
            positionX: positionX,
            positionY: positionY,
            windowWidth: windowWidth,
            windowHeight: windowHeight,
            backgroundOpacity: backgroundOpacity,
            cornerRadius: cornerRadius
        )
        syncToSharedPrefs()
    }

    // MARK: - Shared prefs sync (for SpringBoard tweak)

    /// Debounced sync: batches rapid slider changes into one plist write.
    private func scheduleSync() {
        syncWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.syncToSharedPrefs()
        }
        syncWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    /// Writes all appearance settings to the shared plist and posts a Darwin
    /// notification so the SpringBoard tweak reloads them.
    func syncToSharedPrefs() {
        let dict: [String: Any] = [
            "enabled": useCustomOverlay,
            "windowWidth": windowWidth,
            "windowHeight": windowHeight,
            "positionX": positionX,
            "positionY": positionY,
            "fontSize": fontSize,
            "backgroundOpacity": backgroundOpacity,
            "cornerRadius": cornerRadius,
            "textColorHex": textColorHex,
            "bgColorHex": bgColorHex,
            "showBorder": showBorder,
            "borderWidth": borderWidth
        ]

        let path = "/var/mobile/Library/Preferences/\(kCAPerfHUDPrefsDomain).plist"
        let url = URL(fileURLWithPath: path)
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: dict,
                                                          format: .xml,
                                                          options: 0)
            try data.write(to: url)
        } catch {
            #if DEBUG
            print("[CAPerfHUDSwift] Failed to write shared prefs: \(error)")
            #endif
        }

        // Notify the tweak.
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(kCAPerfHUDSettingsChangedNotification as CFString),
            nil, nil, true
        )
    }
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
