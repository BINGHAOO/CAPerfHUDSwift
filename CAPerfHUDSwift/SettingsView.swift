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
                appearanceSection
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

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section {
            // Live preview – every slider below updates this immediately.
            VStack(spacing: 8) {
                HudOverlayView(isPreview: true)
                    .frame(maxWidth: .infinity)
                Text(loc.string(.previewLabel))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

            Text(loc.string(.appearanceNote))
                .font(.caption)
                .foregroundColor(.secondary)

            sliderRow(
                title: loc.string(.windowWidth),
                value: $settings.windowWidth,
                range: 120...320,
                step: 10,
                format: "%.0f pt"
            )
            sliderRow(
                title: loc.string(.windowHeight),
                value: $settings.windowHeight,
                range: 50...200,
                step: 10,
                format: "%.0f pt"
            )

            sliderRow(
                title: loc.string(.positionX),
                value: $settings.positionX,
                range: -300...300,
                step: 10,
                format: "%.0f"
            )
            sliderRow(
                title: loc.string(.positionY),
                value: $settings.positionY,
                range: -300...300,
                step: 10,
                format: "%.0f"
            )

            sliderRow(
                title: loc.string(.fontSize),
                value: $settings.fontSize,
                range: 8...28,
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
                    range: 0...6,
                    step: 1,
                    format: "%.0f pt"
                )
            }

            colorPickerRow(title: loc.string(.textColor), hex: $settings.textColorHex)
            colorPickerRow(title: loc.string(.bgColor), hex: $settings.bgColorHex)
        } header: {
            Text(loc.string(.appearance))
        }
    }

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
            toggleRow(
                title: loc.string(.persistAcrossLaunches),
                subtitle: loc.string(.persistDesc),
                isOn: $settings.persistAcrossLaunches
            )
            toggleRow(
                title: loc.string(.autoApplyOnLaunch),
                subtitle: loc.string(.autoApplyDesc),
                isOn: $settings.autoApplyOnLaunch
            )
            toggleRow(
                title: loc.string(.hapticFeedback),
                subtitle: loc.string(.hapticDesc),
                isOn: $settings.hapticFeedback
            )
            toggleRow(
                title: loc.string(.animateChanges),
                subtitle: loc.string(.animateDesc),
                isOn: $settings.animateChanges
            )
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

    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

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
}

#Preview {
    SettingsView()
        .environmentObject(HudSettings.shared)
        .environmentObject(LocalizationManager.shared)
}
