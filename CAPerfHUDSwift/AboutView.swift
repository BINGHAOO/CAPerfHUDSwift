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
    @State private var copied = false

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
                Button {
                    UIPasteboard.general.string = lines.joined(separator: "\n")
                    copied = true
                } label: {
                    Label(copied ? loc.string(.diagnosticsCopied) : loc.string(.diagnosticsCopy),
                          systemImage: copied ? "checkmark" : "doc.on.doc")
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
        out.append("HOME: \(NSHomeDirectory())")
        out.append("jbroot: \(HudSettings.jbrootPath() ?? "not derived (not roothide?)")")

        let primary = "/var/mobile/Library/Preferences/\(domain).plist"
        let jbroot = HudSettings.jbrootPath().map { "\($0)/var/mobile/Library/Preferences/\(domain).plist" }
        let suitePath = HudSettings.suitePrefsPath()

        out.append("")
        out.append("== Write test ==")
        // Probe into a throwaway file instead of the live prefs plist: the
        // write test used to overwrite com.binghaoo.caperfhud.plist with a
        // partial dict (metric switches missing), which reset the overlay to
        // FPS/CPU/MEM on every "send settings" tap.
        let probeData: Data? = try? PropertyListSerialization.data(
            fromPropertyList: ["probe": Int(Date().timeIntervalSince1970)],
            format: .xml, options: 0)

        if let probeData = probeData {
            let primaryProbe = primary.replacingOccurrences(of: ".plist", with: ".probe.plist", options: [.backwards])
            do {
                try probeData.write(to: URL(fileURLWithPath: primaryProbe))
                out.append("primary dir: OK")
            } catch {
                out.append("primary dir: FAIL (\(error.localizedDescription))")
            }
            try? fm.removeItem(atPath: primaryProbe)

            if let jbroot = jbroot {
                let jbrootProbe = jbroot.replacingOccurrences(of: ".plist", with: ".probe.plist", options: [.backwards])
                do {
                    try probeData.write(to: URL(fileURLWithPath: jbrootProbe))
                    out.append("jbroot dir: OK")
                } catch {
                    out.append("jbroot dir: FAIL (\(error.localizedDescription))")
                }
                try? fm.removeItem(atPath: jbrootProbe)
            }
        } else {
            out.append("plist serialization: FAIL")
        }
        // Defaults suite round-trip – the guaranteed channel even when the
        // app is sandboxed.
        let suite = UserDefaults(suiteName: domain)
        suite?.set("diag-\(Int(Date().timeIntervalSince1970))", forKey: "diagMarker")
        suite?.synchronize()
        let suiteReadBack = suite?.string(forKey: "diagMarker")
        out.append("suite (UserDefaults): \(suiteReadBack != nil ? "OK" : "FAIL")")

        out.append("")
        out.append("== Files on disk ==")
        out.append("primary: \(fm.fileExists(atPath: primary) ? "exists" : "missing")")
        if let jbroot = jbroot {
            out.append("jbroot: \(fm.fileExists(atPath: jbroot) ? "exists" : "missing")")
        }
        out.append("suite file: \(fm.fileExists(atPath: suitePath) ? "exists" : "missing")")
        out.append("  \(suitePath)")

        out.append("")
        out.append("== Tweak state (written by SpringBoard) ==")
        // The tweak mirrors the diag file next to the prefs file it actually
        // used, so probe every plausible location.
        var diagCandidates: [(String, String)] = [("primary", "/var/mobile/Library/Preferences/\(domain).diag.plist")]
        if let jbroot = jbroot {
            diagCandidates.append(("jbroot", jbroot.replacingOccurrences(of: ".plist", with: ".diag.plist", options: [.backwards])))
        }
        diagCandidates.append(("container", NSHomeDirectory() + "/Library/Preferences/\(domain).diag.plist"))

        var diag: NSDictionary? = nil
        var diagSource = ""
        for (label, path) in diagCandidates {
            if let d = NSDictionary(contentsOfFile: path) {
                diag = d
                diagSource = label
                break
            }
        }

        if let diag = diag {
            out.append("read from: \(diagSource)")
            for key in ["lastReload", "reloadCount", "notifyCount", "prefsFound", "prefsKeyCount", "enabled", "usedPath", "candidateCount", "windowWidth", "windowHeight", "fontSize", "primaryExists", "jbrootExists", "jbrootPrefsPath", "fpsDisplayed", "fpsDisplayLink", "fpsSource", "fpsPanelHz", "fpsPanelScan"] {
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
