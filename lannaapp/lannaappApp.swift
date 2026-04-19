//
//  SpektApp.swift
//  lannaapp
//
//  App entry point. Forces dark mode globally so all materials
//  (ultraThinMaterial etc.) render in the dark variant.
//

import SwiftUI
import FirebaseCore

@main
struct SpektApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            MainAppView()
                .preferredColorScheme(.dark)  // Lock to dark — design only supports dark
        }
    }
}
