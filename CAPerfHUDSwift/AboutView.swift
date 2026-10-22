// bomberfish
// AboutView.swift – CAPerfHudSwift
// created on 2026-10-22

import SwiftUI
import UIKit
import Darwin

struct AboutView: View {
    @EnvironmentObject var loc: LocalizationManager

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private var systemVersion: String {
        UIDevice.current.systemVersion
    }

    private var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    var body: some View {
        let env = EnvironmentDetector.shared.info
        return NavigationView {
            List {
                Section {
                    VStack(spacing: 12) {
                        if let icon = appIconImage {
                            Image(uiImage: icon)
                                .resizable()
                                .frame(width: 80, height: 80)
                                .cornerRadius(18)
                        }
                        Text(loc.string(.appName))
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(loc.string(.description))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section {
                    infoRow(title: loc.string(.appVersion), value: appVersion)
                    infoRow(title: loc.string(.buildNumber), value: buildNumber)
                }

                Section {
                    infoRow(title: loc.string(.systemVersion), value: "iOS \(systemVersion)")
                    infoRow(title: loc.string(.deviceModel), value: deviceModel)
                }

                Section(loc.string(.environment)) {
                    infoRow(title: loc.string(.jailbreakStatus),
                            value: env.isJailbroken ? loc.string(.detected) : loc.string(.notDetected),
                            valueColor: env.isJailbroken ? .green : .secondary)
                    infoRow(title: loc.string(.trollStoreStatus),
                            value: env.isTrollStore ? loc.string(.detected) : loc.string(.notDetected),
                            valueColor: env.isTrollStore ? .green : .secondary)
                    infoRow(title: loc.string(.systemHUDAvailable),
                            value: env.systemHUDAvailable ? loc.string(.supported) : loc.string(.notSupported),
                            valueColor: env.systemHUDAvailable ? .green : .red)
                    infoRow(title: loc.string(.customOverlayAvailable),
                            value: env.customOverlayAvailable ? loc.string(.supported) : loc.string(.notSupported),
                            valueColor: env.customOverlayAvailable ? .green : .red)
                }

                Section(loc.string(.credits)) {
                    Link(destination: URL(string: "https://github.com/BomberFish/CAPerfHUDSwift")!) {
                        Label(loc.string(.sourceCode), systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    Link(destination: URL(string: "https://github.com/khanhduytran0/CAPerfHUD")!) {
                        Label("CAPerfHUD (original)", systemImage: "link")
                    }
                }

                Section {
                    Text("MIT License © Hariz Shirazi")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(loc.string(.about))
        }
        .navigationViewStyle(.stack)
    }

    private var appIconImage: UIImage? {
        guard let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
              let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
              let iconFileName = iconFiles.last else {
            // Fallback: try to get the app icon from the asset catalog
            if let image = UIImage(named: "AppIcon") {
                return image
            }
            return nil
        }
        return UIImage(named: iconFileName)
    }

    private func infoRow(title: String, value: String, valueColor: Color = .secondary) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(valueColor)
                .monospacedDigit()
        }
    }
}

#Preview {
    AboutView()
        .environmentObject(LocalizationManager.shared)
}
