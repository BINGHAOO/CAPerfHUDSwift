// bomberfish
// SettingsView.swift – CAPerfHudSwift
// created on 2026-10-22

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: HudSettings
    @EnvironmentObject var loc: LocalizationManager

    @State private var showResetAlert = false

    var body: some View {
        NavigationView {
            List {
                #if JAILBREAK
                appearanceSection
                #endif
                languageSection
                advancedSection
                resetSection
            }
            .navigationTitle(loc.string(.settings))
            .alert(loc.string(.resetTitle), isPresented: $showResetAlert) {
                Button(loc.string(.no), role: .cancel) { }
                Button(loc.string(.yes), role: .destructive) {
                    settings.resetAll()
                }
            } message: {
                Text(loc.string(.resetMessage))
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Appearance (jailbreak edition only – configures the tweak overlay)

    #if JAILBREAK
    private var appearanceSection: some View {
        Section {
            sliderRow(
                title: loc.string(.windowWidth),
                value: $settings.windowWidth,
                range: 100...400,
                step: 10,
                format: "%.0f pt"
            )
            sliderRow(
                title: loc.string(.windowHeight),
                value: $settings.windowHeight,
                range: 40...300,
                step: 10,
                format: "%.0f pt"
            )

            sliderRow(
                title: loc.string(.positionX),
                value: $settings.positionX,
                range: -200...200,
                step: 10,
                format: "%.0f"
            )
            sliderRow(
                title: loc.string(.positionY),
                value: $settings.positionY,
                range: -200...200,
                step: 10,
                format: "%.0f"
            )

            sliderRow(
                title: loc.string(.fontSize),
                value: $settings.fontSize,
                range: 8...32,
                step: 1,
                format: "%.0f pt"
            )

            sliderRow(
                title: loc.string(.backgroundOpacity),
                value: $settings.backgroundOpacity,
                range: 0...1,
                step: 0.05,
                format: "%.0f%%"
            ) { value in
                String(format: "%.0f%%", value * 100)
            }

            sliderRow(
                title: loc.string(.cornerRadius),
                value: $settings.cornerRadius,
                range: 0...40,
                step: 1,
                format: "%.0f pt"
            )

            Toggle(isOn: $settings.showBorder) {
                Text(loc.string(.showBorder))
            }

            if settings.showBorder {
                sliderRow(
                    title: loc.string(.borderWidth),
                    value: $settings.borderWidth,
                    range: 0...10,
                    step: 1,
                    format: "%.0f pt"
                )
            }

            colorPickerRow(title: loc.string(.textColor), hex: $settings.textColorHex)
            colorPickerRow(title: loc.string(.bgColor), hex: $settings.bgColorHex)

            Button {
                settings.applyAppearance()
                if settings.hapticFeedback {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } label: {
                Label(loc.string(.applySettings), systemImage: "checkmark.circle")
            }

            Text(loc.string(.experimentalNote))
                .font(.caption)
                .foregroundColor(.secondary)
        } header: {
            Text(loc.string(.appearance))
        }
    }
    #endif

    // MARK: - Language

    private var languageSection: some View {
        Section(loc.string(.language)) {
            Picker(loc.string(.selectLanguage), selection: $loc.currentLanguage) {
                ForEach(AppLanguage.allCases) { lang in
                    Text("\(lang.flag)  \(lang.displayName)").tag(lang)
                }
            }
            .pickerStyle(.menu)
        }
    }

    // MARK: - Advanced

    private var advancedSection: some View {
        Section(loc.string(.advanced)) {
            #if JAILBREAK
            Toggle(isOn: $settings.autoApplyOnLaunch) {
                Text(loc.string(.autoApplyOnLaunch))
            }
            #endif
            Toggle(isOn: $settings.hapticFeedback) {
                Text(loc.string(.hapticFeedback))
            }
        }
    }

    // MARK: - Reset

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                showResetAlert = true
            } label: {
                Label(loc.string(.resetToDefaults), systemImage: "arrow.counterclockwise")
            }
        }
    }

    // MARK: - Row Builders

    #if JAILBREAK
    private func sliderRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        format: String,
        valueFormatter: ((Double) -> String)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(valueFormatter.map { $0(value.wrappedValue) } ?? String(format: format, value.wrappedValue))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: range, step: step)
        }
    }

    private func colorPickerRow(title: String, hex: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            ColorPicker("", selection: Binding(
                get: { Color(hex: hex.wrappedValue) ?? .black },
                set: { newColor in
                    hex.wrappedValue = newColor.toHex()
                }
            ), supportsOpacity: false)
            .labelsHidden()
        }
    }
    #endif
}

#Preview {
    SettingsView()
        .environmentObject(HudSettings.shared)
        .environmentObject(LocalizationManager.shared)
}
