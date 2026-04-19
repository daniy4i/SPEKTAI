//
//  MainAppView.swift
//  lannaapp
//
//  Root routing: onboarding → auth → SPEKT AI main surface.
//

import SwiftUI

struct MainAppView: View {
    @ObservedObject private var authService = AuthService.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            // Always-present dark base prevents flicker between transitions
            SpektTheme.Colors.base.ignoresSafeArea()

            if !hasCompletedOnboarding {
                OnboardingView(isOnboardingComplete: $hasCompletedOnboarding)
                    .transition(.glassReveal)
            } else if authService.isAuthenticated {
                #if os(iOS)
                SpektMainView()
                    .transition(.glassReveal)
                #else
                // macOS: use existing projects list
                ProjectsListView()
                    .transition(.opacity)
                #endif
            } else {
                LoginView()
                    .transition(.glassReveal)
            }
        }
        .animation(SpektTheme.Motion.springSmooth, value: hasCompletedOnboarding)
        .animation(SpektTheme.Motion.springSmooth, value: authService.isAuthenticated)
        .ignoresSafeArea()
    }
}
