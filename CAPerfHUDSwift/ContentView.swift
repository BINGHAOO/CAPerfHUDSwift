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
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
                hudTab
                    .tabItem {
                        Label(loc.string(.hud), systemImage: "gauge")
                    }
                    .tag(0)

                SettingsView()
                    .tabItem {
                        Label(loc.string(.settings), systemImage: "slider.horizontal.3")
                    }
                    .tag(1)

                AboutView()
                    .tabItem {
                        Label(loc.string(.about), systemImage: "info.circle")
                    }
                    .tag(2)
            }

            // The self-drawn HUD. Hidden on the Settings tab so the appearance
            // preview there is the only visible instance.
            if selectedTab != 1 {
                HudOverlayView()
                    .offset(x: settings.positionX, y: settings.positionY)
                    .transition(.opacity)
            }
        }
        .onAppear {
            currentLevel = CADebugCommon.getPerfHUDLevel()
            PerformanceMonitor.shared.start()

            if settings.autoApplyOnLaunch && settings.hudLevel > 0 {
                CADebugCommon.setPerfHUDLevel(settings.hudLevel)
                currentLevel = CADebugCommon.getPerfHUDLevel()
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
                    HStack {
                        Text(loc.string(.currentLevel))
                        Spacer()
                        Text(levelName(for: Int(currentLevel)))
                            .foregroundColor(.secondary)
                    }
                    Text(loc.string(.overlayHint))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(loc.string(.selectHUDLevel)) {
                    ForEach(Array(CADebugCommon.perfHUDLevelNames.enumerated()), id: \.offset) { pair in
                        levelRow(index: pair.offset)
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

    private func levelRow(index: Int) -> some View {
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
        let animation: Animation? = settings.animateChanges ? .easeInOut(duration: 0.2) : nil
        withAnimation(animation) {
            CADebugCommon.setPerfHUDLevel(level)
            currentLevel = CADebugCommon.getPerfHUDLevel()
            settings.hudLevel = level
        }
        if settings.hapticFeedback {
            UISelectionFeedbackGenerator().selectionChanged()
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
