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
                Section {
                    quickToggleRow
                }

                Section(loc.string(.selectHUDLevel)) {
                    ForEach(Array(CADebugCommon.perfHUDLevelNames.enumerated()), id: \.offset) { index, name in
                        levelRow(index: index, name: name)
                    }
                }

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

    private var quickToggleRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(loc.string(.quickToggle))
                    .font(.headline)
                Text("\(loc.string(.currentLevel)): \(levelDisplayName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle(isOn: Binding(
                get: { currentLevel > 0 },
                set: { newValue in
                    if newValue {
                        let saved = settings.hudLevel > 0 ? settings.hudLevel : 1
                        applyLevel(saved)
                    } else {
                        applyLevel(0)
                    }
                }
            )) {
                EmptyView()
            }
            .labelsHidden()
        }
    }

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

    private var levelDisplayName: String {
        guard currentLevel >= 0 && currentLevel < CADebugCommon.perfHUDLevelNames.count else {
            return loc.string(.levelOff)
        }
        return levelName(for: Int(currentLevel))
    }

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
