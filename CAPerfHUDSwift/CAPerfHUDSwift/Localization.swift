// bomberfish
// Localization.swift – CAPerfHudSwift
// created on 2026-10-22

import Foundation
import SwiftUI

/// Supported languages
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case chineseSimplified = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .chineseSimplified: return "简体中文"
        }
    }

    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .chineseSimplified: return "🇨🇳"
        }
    }
}

/// Localization keys – all user-facing strings must go through this enum.
enum L10n {
    // MARK: - Navigation / Tabs
    case hud
    case settings
    case about

    // MARK: - HUD level names
    case levelOff
    case levelBasic
    case levelBackdrop
    case levelParticles
    case levelFull
    case levelFrequencies
    case levelPower
    case levelFPSOnly
    case levelDisplay
    case levelGlitches

    // MARK: - HUD level descriptions
    case levelOffDesc
    case levelBasicDesc
    case levelBackdropDesc
    case levelParticlesDesc
    case levelFullDesc
    case levelFrequenciesDesc
    case levelPowerDesc
    case levelFPSOnlyDesc
    case levelDisplayDesc
    case levelGlitchesDesc

    // MARK: - Main view
    case selectHUDLevel
    case applySettings

    // MARK: - Settings sections
    case appearance
    case language
    case advanced
    case reset

    // MARK: - Appearance settings
    case windowSize
    case windowWidth
    case windowHeight
    case position
    case positionX
    case positionY
    case fontSize
    case backgroundOpacity
    case cornerRadius
    case textColor
    case bgColor
    case showBorder
    case borderWidth
    case resetToDefaults
    case experimentalNote

    // MARK: - Language settings
    case selectLanguage
    case followSystem

    // MARK: - Advanced (jailbreak edition)
    case useCustomOverlay
    case useCustomOverlayNote
    case autoApplyOnLaunch
    case hapticFeedback

    // MARK: - HUD mode (jailbreak edition)
    case hudMode
    case modeSystemHUD
    case modeCustomOverlay
    case customOverlayHint
    case appearanceQuickNote

    // MARK: - Edition
    case buildFlavor
    case editionTrollStore
    case editionJailbreak
    case diagnostics
    case diagnosticsSend
    case diagnosticsSent

    // MARK: - About
    case appName
    case appVersion
    case buildNumber
    case description
    case credits
    case sourceCode
    case license
    case systemVersion
    case deviceModel

    // MARK: - Generic
    case done
    case cancel
    case ok
    case on
    case off
    case resetTitle
    case resetMessage
    case yes
    case no
}

extension L10n {
    /// Returns the localized string for the given language.
    func string(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return en
        case .chineseSimplified:
            return zhHans
        }
    }

    private var en: String {
        switch self {
        // Navigation
        case .hud: return "HUD"
        case .settings: return "Settings"
        case .about: return "About"

        // Level names
        case .levelOff: return "Off"
        case .levelBasic: return "Basic"
        case .levelBackdrop: return "Backdrop"
        case .levelParticles: return "Particles"
        case .levelFull: return "Full"
        case .levelFrequencies: return "Frequencies"
        case .levelPower: return "Power"
        case .levelFPSOnly: return "FPS only"
        case .levelDisplay: return "Display"
        case .levelGlitches: return "Glitches"

        // Level descriptions
        case .levelOffDesc: return "HUD is disabled"
        case .levelBasicDesc: return "Core performance metrics"
        case .levelBackdropDesc: return "Backdrop usage information"
        case .levelParticlesDesc: return "Particle system statistics"
        case .levelFullDesc: return "Complete performance overview"
        case .levelFrequenciesDesc: return "CPU/GPU frequency data"
        case .levelPowerDesc: return "Power consumption metrics"
        case .levelFPSOnlyDesc: return "Frames per second only"
        case .levelDisplayDesc: return "Display refresh information"
        case .levelGlitchesDesc: return "Render glitch detection"

        // Main view
        case .selectHUDLevel: return "Select HUD Level"
        case .applySettings: return "Apply Appearance"

        // Settings sections
        case .appearance: return "Appearance"
        case .language: return "Language"
        case .advanced: return "Advanced"
        case .reset: return "Reset"

        // Appearance
        case .windowSize: return "Window Size"
        case .windowWidth: return "Width"
        case .windowHeight: return "Height"
        case .position: return "Position"
        case .positionX: return "Horizontal (X)"
        case .positionY: return "Vertical (Y)"
        case .fontSize: return "Font Size"
        case .backgroundOpacity: return "Background Opacity"
        case .cornerRadius: return "Corner Radius"
        case .textColor: return "Text Color"
        case .bgColor: return "Background Color"
        case .showBorder: return "Show Border"
        case .borderWidth: return "Border Width"
        case .resetToDefaults: return "Reset to Defaults"
        case .experimentalNote: return "Note: Appearance settings depend on iOS version support. Some options may not affect the system HUD on all devices."

        // Language
        case .selectLanguage: return "Select Language"
        case .followSystem: return "Follow System"

        // Advanced
        case .useCustomOverlay: return "Custom Overlay (Jailbreak)"
        case .useCustomOverlayNote: return "Requires the CAPerfHUDOverlay tweak. Draws a cross-app HUD with full appearance control."
        case .autoApplyOnLaunch: return "Auto-Apply on Launch"
        case .hapticFeedback: return "Haptic Feedback"

        // HUD mode
        case .hudMode: return "HUD Mode"
        case .modeSystemHUD: return "System HUD"
        case .modeCustomOverlay: return "Custom Overlay"
        case .customOverlayHint: return "The custom overlay is now visible on screen. Drag it to reposition. The system HUD has been turned off."
        case .appearanceQuickNote: return "More appearance options (position, colors, border, corner radius) are available in the Settings tab."

        // Edition
        case .buildFlavor: return "Edition"
        case .editionTrollStore: return "TrollStore"
        case .editionJailbreak: return "Jailbreak"
        case .diagnostics: return "Diagnostics"
        case .diagnosticsSend: return "Send settings + notify tweak"
        case .diagnosticsSent: return "Sent – check tweak state below"

        // About
        case .appName: return "CAPerfHUDSwift"
        case .appVersion: return "Version"
        case .buildNumber: return "Build"
        case .description: return "A Swift-based alternative to CAPerfHUD. Controls the Core Animation performance HUD on iOS."
        case .credits: return "Credits"
        case .sourceCode: return "Source Code"
        case .license: return "License"
        case .systemVersion: return "System Version"
        case .deviceModel: return "Device Model"

        // Generic
        case .done: return "Done"
        case .cancel: return "Cancel"
        case .ok: return "OK"
        case .on: return "On"
        case .off: return "Off"
        case .resetTitle: return "Reset Settings"
        case .resetMessage: return "Are you sure you want to reset all settings to defaults?"
        case .yes: return "Yes"
        case .no: return "No"
        }
    }

    private var zhHans: String {
        switch self {
        // Navigation
        case .hud: return "HUD"
        case .settings: return "设置"
        case .about: return "关于"

        // Level names
        case .levelOff: return "关闭"
        case .levelBasic: return "基础"
        case .levelBackdrop: return "背景"
        case .levelParticles: return "粒子"
        case .levelFull: return "完整"
        case .levelFrequencies: return "频率"
        case .levelPower: return "功耗"
        case .levelFPSOnly: return "仅帧率"
        case .levelDisplay: return "显示"
        case .levelGlitches: return "故障"

        // Level descriptions
        case .levelOffDesc: return "HUD 已禁用"
        case .levelBasicDesc: return "核心性能指标"
        case .levelBackdropDesc: return "背景使用信息"
        case .levelParticlesDesc: return "粒子系统统计"
        case .levelFullDesc: return "完整性能概览"
        case .levelFrequenciesDesc: return "CPU/GPU 频率数据"
        case .levelPowerDesc: return "功耗指标"
        case .levelFPSOnlyDesc: return "仅显示帧率"
        case .levelDisplayDesc: return "显示刷新信息"
        case .levelGlitchesDesc: return "渲染故障检测"

        // Main view
        case .selectHUDLevel: return "选择 HUD 级别"
        case .applySettings: return "应用外观"

        // Settings sections
        case .appearance: return "外观"
        case .language: return "语言"
        case .advanced: return "高级"
        case .reset: return "重置"

        // Appearance
        case .windowSize: return "窗口大小"
        case .windowWidth: return "宽度"
        case .windowHeight: return "高度"
        case .position: return "位置"
        case .positionX: return "水平 (X)"
        case .positionY: return "垂直 (Y)"
        case .fontSize: return "字体大小"
        case .backgroundOpacity: return "背景透明度"
        case .cornerRadius: return "圆角"
        case .textColor: return "文字颜色"
        case .bgColor: return "背景颜色"
        case .showBorder: return "显示边框"
        case .borderWidth: return "边框宽度"
        case .resetToDefaults: return "恢复默认设置"
        case .experimentalNote: return "注意：外观设置取决于 iOS 系统版本支持。部分选项可能不会影响所有设备上的系统 HUD。"

        // Language
        case .selectLanguage: return "选择语言"
        case .followSystem: return "跟随系统"

        // Advanced
        case .useCustomOverlay: return "自定义悬浮窗（越狱）"
        case .useCustomOverlayNote: return "需安装 CAPerfHUDOverlay 插件。绘制可完全控制外观的跨应用悬浮窗。"
        case .autoApplyOnLaunch: return "启动时自动应用"
        case .hapticFeedback: return "触觉反馈"

        // HUD mode
        case .hudMode: return "HUD 模式"
        case .modeSystemHUD: return "系统 HUD"
        case .modeCustomOverlay: return "自定义悬浮窗"
        case .customOverlayHint: return "自定义悬浮窗已在屏幕上显示，可拖动调整位置。系统 HUD 已关闭。"
        case .appearanceQuickNote: return "更多外观设置（位置、颜色、边框、圆角）请前往「设置」页。"

        // Edition
        case .buildFlavor: return "版本类型"
        case .editionTrollStore: return "巨魔版（TrollStore）"
        case .editionJailbreak: return "越狱版（Jailbreak）"
        case .diagnostics: return "诊断"
        case .diagnosticsSend: return "发送设置并通知插件"
        case .diagnosticsSent: return "已发送 – 查看下方插件状态"

        // About
        case .appName: return "CAPerfHUDSwift"
        case .appVersion: return "版本"
        case .buildNumber: return "构建"
        case .description: return "CAPerfHUD 的 Swift 替代方案。控制 iOS 上的 Core Animation 性能 HUD。"
        case .credits: return "致谢"
        case .sourceCode: return "源代码"
        case .license: return "许可证"
        case .systemVersion: return "系统版本"
        case .deviceModel: return "设备型号"

        // Generic
        case .done: return "完成"
        case .cancel: return "取消"
        case .ok: return "确定"
        case .on: return "开"
        case .off: return "关"
        case .resetTitle: return "重置设置"
        case .resetMessage: return "确定要将所有设置恢复为默认值吗？"
        case .yes: return "是"
        case .no: return "否"
        }
    }
}

/// Observable localization manager that drives the UI language.
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "AppLanguage")
        }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "AppLanguage"),
           let lang = AppLanguage(rawValue: saved) {
            self.currentLanguage = lang
        } else {
            // Detect system language
            let pref = Locale.preferredLanguages.first ?? "en"
            if pref.hasPrefix("zh") {
                self.currentLanguage = .chineseSimplified
            } else {
                self.currentLanguage = .english
            }
        }
    }

    /// Convenience accessor for localized strings.
    func string(_ key: L10n) -> String {
        key.string(for: currentLanguage)
    }
}

/// SwiftUI environment key for the current language.
private struct AppLanguageKey: EnvironmentKey {
    static let defaultValue: AppLanguage = .english
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }
}
