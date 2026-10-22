// bomberfish
// EnvironmentDetector.swift – CAPerfHudSwift
// created on 2026-10-23
//
// Detects the runtime environment (jailbreak, TrollStore, iOS version,
// installed tweak) and exposes feature-availability flags so the UI can
// show or hide options and tell the user what works on their device.

import Foundation
import UIKit

/// Represents the detected runtime environment.
struct EnvironmentInfo {
    let isJailbroken: Bool
    let isTrollStore: Bool
    let hasQuartzDebugEntitlement: Bool
    let tweakInstalled: Bool
    let systemVersion: String
    let systemVersionMajor: Int

    /// The system HUD level switching works only with the
    /// `com.apple.QuartzCore.debug` entitlement (TrollStore or jailbreak).
    var systemHUDAvailable: Bool { hasQuartzDebugEntitlement }

    /// The cross-app custom overlay requires a jailbroken device with the
    /// CAPerfHUDOverlay tweak installed.
    var customOverlayAvailable: Bool { isJailbroken && tweakInstalled }

    /// Human-readable environment summary (used in UI).
    var summary: String {
        var parts: [String] = []
        parts.append("iOS \(systemVersion)")
        if isJailbroken { parts.append("Jailbreak") }
        if isTrollStore { parts.append("TrollStore") }
        if parts.count == 1 { parts.append("Stock") }
        return parts.joined(separator: " · ")
    }
}

final class EnvironmentDetector {
    static let shared = EnvironmentDetector()

    private(set) var info: EnvironmentInfo

    private init() {
        self.info = EnvironmentDetector.detect()
    }

    /// Re-run detection (call after a respring or if the environment changes).
    func refresh() {
        self.info = EnvironmentDetector.detect()
    }

    // MARK: - Detection

    private static func detect() -> EnvironmentInfo {
        let systemVersion = UIDevice.current.systemVersion
        let major = Int(systemVersion.split(separator: ".").first ?? "0") ?? 0

        let jailbroken = detectJailbreak()
        let trollStore = detectTrollStore()
        let hasDebugEnt = detectQuartzDebugEntitlement()
        let tweak = detectTweakInstalled()

        return EnvironmentInfo(
            isJailbroken: jailbroken,
            isTrollStore: trollStore,
            hasQuartzDebugEntitlement: hasDebugEnt,
            tweakInstalled: tweak,
            systemVersion: systemVersion,
            systemVersionMajor: major
        )
    }

    // MARK: - Jailbreak detection

    private static func detectJailbreak() -> Bool {
        // 1. Check for common jailbreak files/directories.
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/Applications/Zebra.app",
            "/Applications/Installer.app",
            "/bin/bash",
            "/bin/sh",
            "/etc/apt",
            "/usr/sbin/sshd",
            "/usr/bin/ssh",
            "/private/var/lib/apt",
            "/private/var/stash",
            "/Library/MobileSubstrate/DynamicLibraries",
            "/Library/PreferenceBundles",
            "/var/lib/dpkg",
            "/var/cache/apt",
            "/var/log/syslog"
        ]
        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }

        // 2. Check if we can write outside the sandbox.
        let testPath = "/private/jailbreak_test_\(UUID().uuidString)"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true
        } catch {
            // not jailbroken (or not allowed to write there)
        }

        // 3. Check for Cydia URL scheme.
        if let url = URL(string: "cydia://"), UIApplication.shared.canOpenURL(url) {
            return true
        }

        // 4. fork() – returns -1 in a sandboxed app, a real PID when jailbroken.
        let pid = fork()
        if pid == 0 {
            // Child process – exit immediately, we only used fork() as a probe.
            _exit(0)
        }
        if pid > 0 {
            return true
        }

        return false
    }

    // MARK: - TrollStore detection

    private static func detectTrollStore() -> Bool {
        // TrollStore installs apps with specific markers.
        // 1. Check the TrollStore URL scheme.
        if let url = URL(string: "trollstore://"), UIApplication.shared.canOpenURL(url) {
            return true
        }

        // 2. TrollStore leaves a "TrollStore" helper in the app bundle or
        //    signs with a particular identity. Check for the .app path that
        //    TrollStore uses (sideloaded apps live under /var/containers/...
        //    but TrollStore installs to a special location on iOS 14-16).
        let bundlePath = Bundle.main.bundlePath
        if bundlePath.contains("TrollStore") {
            return true
        }

        // 3. Check for the TrollStore persistence helper plist.
        let trollStorePlist = "/var/mobile/Library/Preferences/com.opa334.TrollStore.plist"
        if FileManager.default.fileExists(atPath: trollStorePlist) {
            return true
        }

        return false
    }

    // MARK: - QuartzCore debug entitlement detection

    /// The system HUD control requires the `com.apple.QuartzCore.debug`
    /// entitlement. We check this by actually calling the render server; if
    /// the entitlement is missing the call silently does nothing.
    private static func detectQuartzDebugEntitlement() -> Bool {
        // Try to read the current perf HUD debug option. On a device with
        // the entitlement this returns 0 or the active level; without it,
        // the dynamic symbol may still return 0 so we also try to SET a
        // known value and read it back.
        let getOpt = unsafeBitCast(dlsym(dlopen("/System/Library/Frameworks/QuartzCore.framework/QuartzCore", 2), "CARenderServerGetDebugOption"), to: (@convention(c) (Int32, Int32) -> Int32).self)
        let setOpt = unsafeBitCast(dlsym(dlopen("/System/Library/Frameworks/QuartzCore.framework/QuartzCore", 2), "CARenderServerSetDebugOption"), to: (@convention(c) (Int32, Int32, Int32) -> Void).self)

        guard getOpt != nil, setOpt != nil else { return false }

        let CA_DEBUG_OPTION_PERF_HUD: Int32 = 0x24
        let before = getOpt(0, CA_DEBUG_OPTION_PERF_HUD)
        // Toggle to a non-zero value and see if it sticks.
        setOpt(0, CA_DEBUG_OPTION_PERF_HUD, 1)
        let after = getOpt(0, CA_DEBUG_OPTION_PERF_HUD)
        // Restore.
        setOpt(0, CA_DEBUG_OPTION_PERF_HUD, before)

        return after == 1
    }

    // MARK: - Tweak installation detection

    /// The CAPerfHUDOverlay tweak drops its plist in SpringBoard's
    /// preference filter directory. We also check for the shared prefs
    /// domain and the tweak dylib.
    private static func detectTweakInstalled() -> Bool {
        let tweakPaths = [
            "/Library/MobileSubstrate/DynamicLibraries/CAPerfHUDOverlay.dylib",
            "/Library/MobileSubstrate/DynamicLibraries/CAPerfHUDOverlay.plist",
            "/usr/lib/TweakInject/CAPerfHUDOverlay.dylib"
        ]
        for path in tweakPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        // Also check the shared prefs plist the app writes.
        let prefs = "/var/mobile/Library/Preferences/com.binghaoo.caperfhud.plist"
        return FileManager.default.fileExists(atPath: prefs)
    }
}
