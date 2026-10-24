// bomberfish
// ContentView.swift – CAPerfHudSwift
// created on 2023-12-18

import SwiftUI
import QuartzCore

struct ContentView: View {
    @EnvironmentObject var settings: HudSettings
    @EnvironmentObject var loc: LocalizationManager

    @State private var currentLevel: Int32 = 0
    @State private var showResetAlert = false

    var body: some View {
        TabView {
            hudTab
                .tabItem {
                    Label(loc.string(.hud), systemImage: "gauge")
                }

            SettingsView()
                .tabItem {
                    Label(loc.string(.settings), systemImage: "slider.horizontal.3")
                }

            AboutView()
                .tabItem {
                    Label(loc.string(.about), systemImage: "info.circle")
                }
        }
        .onAppear {
            currentLevel = CADebugCommon.getPerfHUDLevel()
            #if JAILBREAK
            // Push the app's current state to the shared plist on launch so
            // the tweak never runs with stale preferences.
            settings.syncToSharedPrefs()
            #endif
            if settings.autoApplyOnLaunch {
                settings.applyAppearance()
            }
        }
        .alert(loc.string(.resetTitle), isPresented: $showResetAlert) {
            Button(loc.string(.no), role: .cancel) { }
            Button(loc.string(.yes), role: .destructive) {
                settings.resetAll()
                CADebugCommon.setPerfHUDLevel(0)
                currentLevel = 0
            }
        } message: {
            Text(loc.string(.resetMessage))
        }
    }

    // MARK: - HUD Tab

    private var hudTab: some View {
        NavigationView {
            List {
                #if JAILBREAK
                Section {
                    Toggle(isOn: systemHUDOn) {
                        Label(loc.string(.modeSystemHUD), systemImage: "gauge")
                    }
                    Toggle(isOn: $settings.useCustomOverlay) {
                        Label(loc.string(.modeCustomOverlay), systemImage: "rectangle.on.rectangle")
                    }
                } header: {
                    Text(loc.string(.hudMode))
                } footer: {
                    Text(loc.string(.hudModeFooter))
                }
                #endif

                systemHUDSection

                #if JAILBREAK
                customOverlaySection
                #endif

                Section {
                    Button {
                        showResetAlert = true
                    } label: {
                        Label(loc.string(.resetToDefaults), systemImage: "arrow.counterclockwise")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(loc.string(.hud))
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Mode toggles (independent – both can be on for comparison)

    #if JAILBREAK
    private var systemHUDOn: Binding<Bool> {
        Binding(
            get: { currentLevel != 0 },
            set: { on in
                if on {
                    applyLevel(settings.hudLevel > 0 ? settings.hudLevel : 1)
                } else {
                    applyLevel(0)
                }
                if settings.hapticFeedback {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
        )
    }
    #endif

    // MARK: - Level picker for the system-rendered Core Animation HUD

    private var systemHUDSection: some View {
        Section(loc.string(.selectHUDLevel)) {
            ForEach(Array(CADebugCommon.perfHUDLevelNames.enumerated()), id: \.offset) { index, name in
                levelRow(index: index, name: name)
            }
        }
    }

    /// Quick appearance controls for the tweak-drawn cross-app overlay.
    #if JAILBREAK
    private var customOverlaySection: some View {
        Section(loc.string(.modeCustomOverlay)) {
            Text(loc.string(.customOverlayHint))
                .font(.caption)
                .foregroundColor(.secondary)

            quickSliderRow(
                title: loc.string(.windowWidth),
                value: $settings.windowWidth,
                range: 100...400,
                step: 10
            )
            quickSliderRow(
                title: loc.string(.windowHeight),
                value: $settings.windowHeight,
                range: 40...300,
                step: 10
            )
            quickSliderRow(
                title: loc.string(.fontSize),
                value: $settings.fontSize,
                range: 8...32,
                step: 1
            )
            quickSliderRow(
                title: loc.string(.backgroundOpacity),
                value: $settings.backgroundOpacity,
                range: 0...1,
                step: 0.05
            ) { String(format: "%.0f%%", $0 * 100) }

            Text(loc.string(.appearanceQuickNote))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func quickSliderRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        valueFormatter: ((Double) -> String)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(valueFormatter.map { $0(value.wrappedValue) } ?? String(format: "%.0f pt", value.wrappedValue))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: range, step: step)
        }
    }
    #endif

    // MARK: - Level Rows

    private func levelRow(index: Int, name: String) -> some View {
        Button(action: {
            applyLevel(Int32(index))
        }) {
            HStack(spacing: 12) {
                Image(systemName: currentLevel == Int32(index) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(currentLevel == Int32(index) ? Color(UIColor.systemBlue) : .secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(levelName(for: index))
                        .foregroundColor(Color(UIColor.label))
                        .font(.body)
                    Text(levelDescription(for: index))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func applyLevel(_ level: Int32) {
        withAnimation(.default) {
            CADebugCommon.setPerfHUDLevel(level)
            currentLevel = CADebugCommon.getPerfHUDLevel()
            settings.hudLevel = level
            if settings.hapticFeedback {
                UISelectionFeedbackGenerator().selectionChanged()
            }
        }
    }

    private func levelName(for index: Int) -> String {
        let keys: [L10n] = [
            .levelOff, .levelBasic, .levelBackdrop, .levelParticles, .levelFull,
            .levelFrequencies, .levelPower, .levelFPSOnly, .levelDisplay, .levelGlitches
        ]
        guard index >= 0 && index < keys.count else { return "" }
        return loc.string(keys[index])
    }

    private func levelDescription(for index: Int) -> String {
        let keys: [L10n] = [
            .levelOffDesc, .levelBasicDesc, .levelBackdropDesc, .levelParticlesDesc,
            .levelFullDesc, .levelFrequenciesDesc, .levelPowerDesc, .levelFPSOnlyDesc,
            .levelDisplayDesc, .levelGlitchesDesc
        ]
        guard index >= 0 && index < keys.count else { return "" }
        return loc.string(keys[index])
    }
}

#Preview {
    ContentView()
        .environmentObject(HudSettings.shared)
        .environmentObject(LocalizationManager.shared)
}
