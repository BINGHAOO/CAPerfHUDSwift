// bomberfish
// HudSettings.swift – CAPerfHudSwift
// created on 2026-10-22

import Foundation
import SwiftUI

/// Manages all HUD appearance settings with persistence to UserDefaults.
final class HudSettings: ObservableObject {
    static let shared = HudSettings()

    // MARK: - HUD Level (persisted)
    @Published var hudLevel: Int32 {
        didSet { UserDefaults.standard.set(Int(hudLevel), forKey: "HUDLevel") }
    }

    // MARK: - Window Size
    @Published var windowWidth: Double {
        didSet { UserDefaults.standard.set(windowWidth, forKey: "HUDWindowWidth") }
    }
    @Published var windowHeight: Double {
        didSet { UserDefaults.standard.set(windowHeight, forKey: "HUDWindowHeight") }
    }

    // MARK: - Position
    @Published var positionX: Double {
        didSet { UserDefaults.standard.set(positionX, forKey: "HUDPositionX") }
    }
    @Published var positionY: Double {
        didSet { UserDefaults.standard.set(positionY, forKey: "HUDPositionY") }
    }

    // MARK: - Typography & Colors
    @Published var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: "HUDFontSize") }
    }
    @Published var backgroundOpacity: Double {
        didSet { UserDefaults.standard.set(backgroundOpacity, forKey: "HUDBackgroundOpacity") }
    }
    @Published var cornerRadius: Double {
        didSet { UserDefaults.standard.set(cornerRadius, forKey: "HUDCornerRadius") }
    }
    @Published var textColorHex: String {
        didSet { UserDefaults.standard.set(textColorHex, forKey: "HUDTextColor") }
    }
    @Published var bgColorHex: String {
        didSet { UserDefaults.standard.set(bgColorHex, forKey: "HUDBgColor") }
    }

    // MARK: - Border
    @Published var showBorder: Bool {
        didSet { UserDefaults.standard.set(showBorder, forKey: "HUDShowBorder") }
    }
    @Published var borderWidth: Double {
        didSet { UserDefaults.standard.set(borderWidth, forKey: "HUDBorderWidth") }
    }

    // MARK: - Behavior
    @Published var animateChanges: Bool {
        didSet { UserDefaults.standard.set(animateChanges, forKey: "HUDAnimateChanges") }
    }
    @Published var persistAcrossLaunches: Bool {
        didSet { UserDefaults.standard.set(persistAcrossLaunches, forKey: "HUDPersist") }
    }
    @Published var autoApplyOnLaunch: Bool {
        didSet { UserDefaults.standard.set(autoApplyOnLaunch, forKey: "HUDAutoApply") }
    }
    @Published var hapticFeedback: Bool {
        didSet { UserDefaults.standard.set(hapticFeedback, forKey: "HUDHaptic") }
    }

    // MARK: - Defaults
    private init() {
        let defaults = UserDefaults.standard
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

        self.animateChanges = defaults.object(forKey: "HUDAnimateChanges") as? Bool ?? true
        self.persistAcrossLaunches = defaults.object(forKey: "HUDPersist") as? Bool ?? true
        self.autoApplyOnLaunch = defaults.object(forKey: "HUDAutoApply") as? Bool ?? true
        self.hapticFeedback = defaults.object(forKey: "HUDHaptic") as? Bool ?? true
    }

    // MARK: - Reset
    func resetAll() {
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
        animateChanges = true
        persistAcrossLaunches = true
        autoApplyOnLaunch = true
        hapticFeedback = true
    }

    // MARK: - Apply to system HUD
    /// Pushes the current appearance settings to the Core Animation render server.
    /// The system HUD only honours a subset of these on certain iOS versions.
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
