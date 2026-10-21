// bomberfish
// CAPerfHudSwiftApp.swift – CAPerfHudSwift
// created on 2023-12-18

import SwiftUI

@main
struct CAPerfHudSwiftApp: App {
    @StateObject private var settings = HudSettings.shared
    @StateObject private var loc = LocalizationManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(loc)
        }
    }
}
