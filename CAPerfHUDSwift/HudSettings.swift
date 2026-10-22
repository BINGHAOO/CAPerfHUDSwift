// bomberfish
// HudSettings.swift – CAPerfHudSwift
// created on 2026-10-22

import Foundation
import SwiftUI

/// Manages all HUD settings with optional persistence to UserDefaults.
///
/// Appearance values drive the in-app `HudOverlayView`. The system Core
/// Animation HUD only accepts a level, so it is not affected by them.
final class HudSettings: ObservableObject {
    static let shared = HudSettings()

    // MARK: - HUD Level (system HUD)
    @Published var hudLevel: Int32 {
        didSet { save("HUDLevel", Int(hudLevel)) }
    }

    // MARK: - Window Size
    @Published var windowWidth: Double {
        didSet { save("HUDWindowWidth", windowWidth) }
    }
    @Published var windowHeight: Double {
        didSet { save("HUDWindowHeight", windowHeight) }
    }

    // MARK: - Position
    @Published var positionX: Double {
        didSet { save("HUDPositionX", positionX) }
    }
    @Published var positionY: Double {
        didSet { save("HUDPositionY", positionY) }
    }

    // MARK: - Typography & Colors
    @Published var fontSize: Double {
        didSet { save("HUDFontSize", fontSize) }
    }
    @Published var backgroundOpacity: Double {
        didSet { save("HUDBackgroundOpacity", backgroundOpacity) }
    }
    @Published var cornerRadius: Double {
        didSet { save("HUDCornerRadius", cornerRadius) }
    }
    @Published var textColorHex: String {
        didSet { save("HUDTextColor", textColorHex) }
    }
    @Published var bgColorHex: String {
        didSet { save("HUDBgColor", bgColorHex) }
    }

    // MARK: - Border
    @Published var showBorder: Bool {
        didSet { save("HUDShowBorder", showBorder) }
    }
    @Published var borderWidth: Double {
        didSet { save("HUDBorderWidth", borderWidth) }
    }

    // MARK: - Behavior
    @Published var animateChanges: Bool {
        didSet { save("HUDAnimateChanges", animateChanges) }
    }
    /// Always persisted so the switch itself survives a relaunch.
    @Published var persistAcrossLaunches: Bool {
        didSet { UserDefaults.standard.set(persistAcrossLaunches, forKey: "HUDPersist") }
    }
    @Published var autoApplyOnLaunch: Bool {
        didSet { save("HUDAutoApply", autoApplyOnLaunch) }
    }
    @Published var hapticFeedback: Bool {
        didSet { save("HUDHaptic", hapticFeedback) }
    }

    // MARK: - Init
    private init() {
        let d = UserDefaults.standard
        let persist = d.object(forKey: "HUDPersist") as? Bool ?? true

        func storedDouble(_ key: String, _ fallback: Double) -> Double {
            persist ? (d.object(forKey: key) as? Double ?? fallback) : fallback
        }
        func storedBool(_ key: String, _ fallback: Bool) -> Bool {
            persist ? (d.object(forKey: key) as? Bool ?? fallback) : fallback
        }
        func storedString(_ key: String, _ fallback: String) -> String {
            persist ? (d.string(forKey: key) ?? fallback) : fallback
        }

        self.persistAcrossLaunches = persist
        self.hudLevel = persist ? Int32(d.integer(forKey: "HUDLevel")) : 0

        self.windowWidth = storedDouble("HUDWindowWidth", 220)
        self.windowHeight = storedDouble("HUDWindowHeight", 80)

        self.positionX = storedDouble("HUDPositionX", 0)
        self.positionY = storedDouble("HUDPositionY", 110)

        self.fontSize = storedDouble("HUDFontSize", 13)
        self.backgroundOpacity = storedDouble("HUDBackgroundOpacity", 0.65)
        self.cornerRadius = storedDouble("HUDCornerRadius", 12)
        self.textColorHex = storedString("HUDTextColor", "#FFFFFF")
        self.bgColorHex = storedString("HUDBgColor", "#000000")

        self.showBorder = storedBool("HUDShowBorder", false)
        self.borderWidth = storedDouble("HUDBorderWidth", 1)

        self.animateChanges = storedBool("HUDAnimateChanges", true)
        self.autoApplyOnLaunch = storedBool("HUDAutoApply", true)
        self.hapticFeedback = storedBool("HUDHaptic", true)
    }

    // MARK: - Persistence
    private func save(_ key: String, _ value: Any) {
        guard persistAcrossLaunches else { return }
        UserDefaults.standard.set(value, forKey: key)
    }

    // MARK: - Reset
    func resetAll() {
        hudLevel = 0
        windowWidth = 220
        windowHeight = 80
        positionX = 0
        positionY = 110
        fontSize = 13
        backgroundOpacity = 0.65
        cornerRadius = 12
        textColorHex = "#FFFFFF"
        bgColorHex = "#000000"
        showBorder = false
        borderWidth = 1
        animateChanges = true
        persistAcrossLaunches = true
        autoApplyOnLaunch = true
        hapticFeedback = true
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
