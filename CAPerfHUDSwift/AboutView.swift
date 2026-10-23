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
        NavigationView {
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
                    infoRow(title: loc.string(.buildFlavor), value: editionName)
                    infoRow(title: loc.string(.appVersion), value: appVersion)
                    infoRow(title: loc.string(.buildNumber), value: buildNumber)
                }

                Section {
                    infoRow(title: loc.string(.systemVersion), value: "iOS \(systemVersion)")
                    infoRow(title: loc.string(.deviceModel), value: deviceModel)
                }

                #if JAILBREAK
                Section {
                    NavigationLink(destination: DiagnosticsView()) {
                        Label(loc.string(.diagnostics), systemImage: "stethoscope")
                    }
                }
                #endif

                Section(loc.string(.credits)) {
                    Link(destination: URL(string: "https://github.com/BINGHAOO/CAPerfHUDSwift")!) {
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

    private var editionName: String {
        #if JAILBREAK
        return loc.string(.editionJailbreak)
        #else
        return loc.string(.editionTrollStore)
        #endif
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

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
    }
}

#if JAILBREAK
/// Shows what the app and the SpringBoard tweak actually see on disk, so the
/// app↔tweak settings pipeline can be verified on any jailbreak flavour.
struct DiagnosticsView: View {
    @EnvironmentObject var loc: LocalizationManager
    @State private var lines: [String] = []
    @State private var notifySent = false

    var body: some View {
        List {
            Section {
                Button {
                    HudSettings.shared.syncToSharedPrefs()
                    notifySent = true
                    run()
                } label: {
                    Label(notifySent ? loc.string(.diagnosticsSent) : loc.string(.diagnosticsSend),
                          systemImage: "paperplane")
                }
            }
            Section {
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle(loc.string(.diagnostics))
        .onAppear(perform: run)
    }

    private func run() {
        var out: [String] = []
        let fm = FileManager.default
        let domain = kCAPerfHUDPrefsDomain as String

        out.append("== App ==")
        out.append("bundlePath: \(Bundle.main.bundlePath)")
        out.append("jbroot: \(HudSettings.jbrootPath() ?? "not derived (not roothide?)")")

        let primary = "/var/mobile/Library/Preferences/\(domain).plist"
        let jbroot = HudSettings.jbrootPath().map { "\($0)/var/mobile/Library/Preferences/\(domain).plist" }

        out.append("")
        out.append("== Write test ==")
        let testDict: [String: Any] = [
            "enabled": HudSettings.shared.useCustomOverlay,
            "windowWidth": HudSettings.shared.windowWidth,
            "windowHeight": HudSettings.shared.windowHeight,
            "fontSize": HudSettings.shared.fontSize,
            "backgroundOpacity": HudSettings.shared.backgroundOpacity,
            "cornerRadius": HudSettings.shared.cornerRadius,
            "textColorHex": HudSettings.shared.textColorHex,
            "bgColorHex": HudSettings.shared.bgColorHex,
            "showBorder": HudSettings.shared.showBorder,
            "borderWidth": HudSettings.shared.borderWidth,
            "positionX": HudSettings.shared.positionX,
            "positionY": HudSettings.shared.positionY
        ]
        let data = try? PropertyListSerialization.data(fromPropertyList: testDict, format: .xml, options: 0)

        do {
            try data?.write(to: URL(fileURLWithPath: primary))
            out.append("primary: OK")
        } catch {
            out.append("primary: FAIL (\(error.localizedDescription))")
        }
        if let jbroot = jbroot {
            do {
                try data?.write(to: URL(fileURLWithPath: jbroot))
                out.append("jbroot: OK")
            } catch {
                out.append("jbroot: FAIL (\(error.localizedDescription))")
            }
        }

        out.append("")
        out.append("== Read back ==")
        for (label, path) in [("primary", primary), ("jbroot", jbroot ?? "")] where !path.isEmpty {
            if let dict = NSDictionary(contentsOfFile: path) {
                out.append("\(label): exists, enabled=\(dict["enabled"] ?? "?"), w=\(dict["windowWidth"] ?? "?"), h=\(dict["windowHeight"] ?? "?")")
            } else {
                out.append("\(label): MISSING or unreadable")
            }
        }

        out.append("")
        out.append("== Tweak state (written by SpringBoard) ==")
        let diagPath = "/var/mobile/Library/Preferences/\(domain).diag.plist"
        if fm.fileExists(atPath: diagPath), let diag = NSDictionary(contentsOfFile: diagPath) {
            for key in ["lastReload", "reloadCount", "notifyCount", "prefsFound", "enabled", "usedPath", "windowWidth", "windowHeight", "fontSize", "primaryExists", "jbrootExists", "jbrootPrefsPath"] {
                if let v = diag[key] {
                    out.append("\(key): \(v)")
                }
            }
        } else {
            out.append("diag file not found – tweak never reloaded (respring once, then re-open this page)")
        }

        lines = out
    }
}
#endif

#Preview {
    AboutView()
        .environmentObject(LocalizationManager.shared)
}
