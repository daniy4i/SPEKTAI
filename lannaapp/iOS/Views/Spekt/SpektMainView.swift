//
//  SpektMainView.swift
//  lannaapp
//
//  Main app container with the Liquid Glass tab bar.
//  Four tabs: Voice (primary), Activity, Signal, Profile.
//

import SwiftUI

// MARK: - Tab Definition
enum SpektTab: Int, CaseIterable, Identifiable {
    case voice    = 0
    case activity = 1
    case signal   = 2
    case profile  = 3

    var id: Int { rawValue }

    var icon: String {
        switch self {
        case .voice:    return "waveform"
        case .activity: return "bolt"
        case .signal:   return "diamond"
        case .profile:  return "person"
        }
    }

    var activeIcon: String {
        switch self {
        case .voice:    return "waveform"
        case .activity: return "bolt.fill"
        case .signal:   return "diamond.fill"
        case .profile:  return "person.fill"
        }
    }

    var label: String {
        switch self {
        case .voice:    return "Home"
        case .activity: return "Activity"
        case .signal:   return "Signal"
        case .profile:  return "Profile"
        }
    }

    var isPrimary: Bool { self == .voice }
}

// MARK: - Tab Bar Item
struct SpektTabItem: View {
    let tab: SpektTab
    let isSelected: Bool
    let action: () -> Void

    private var iconSize: CGFloat { tab.isPrimary ? 22 : 18 }

    var body: some View {
        Button(action: action) {
            ZStack {
                // Ambient glow — renders beneath the pill, bleeds softly outward.
                // Low opacity, small blur: barely noticeable but adds warmth.
                if isSelected {
                    Capsule()
                        .fill(
                            tab.isPrimary
                                ? SpektTheme.Colors.accent.opacity(0.30)
                                : Color.white.opacity(0.09)
                        )
                        .frame(
                            width: tab.isPrimary ? 72 : 62,
                            height: tab.isPrimary ? 52 : 46
                        )
                        .blur(radius: tab.isPrimary ? 14 : 10)
                        .transition(.opacity)
                }

                // Active background pill
                if isSelected {
                    Capsule()
                        .fill(
                            tab.isPrimary
                                ? SpektTheme.Colors.accent
                                : Color.white.opacity(0.13)
                        )
                        .frame(
                            width: tab.isPrimary ? 58 : 52,
                            height: tab.isPrimary ? 40 : 36
                        )
                        .shadow(
                            color: tab.isPrimary
                                ? SpektTheme.Colors.accent.opacity(0.35)
                                : .clear,
                            radius: 12, x: 0, y: 4
                        )
                        .transition(.scale.combined(with: .opacity))
                }

                Image(systemName: isSelected ? tab.activeIcon : tab.icon)
                    .font(.system(size: iconSize, weight: .regular))
                    .foregroundColor(isSelected ? .white : Color.white.opacity(0.38))
                    .scaleEffect(isSelected ? 1.08 : 1.0)
                    .contentTransition(.symbolEffect(.replace.downUp))
            }
            .animation(SpektTheme.Motion.springSnappy, value: isSelected)
            .frame(width: 66, height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.88))
    }
}

// MARK: - Tab Bar
struct SpektTabBar: View {
    @Binding var selected: SpektTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(SpektTab.allCases) { tab in
                SpektTabItem(tab: tab, isSelected: selected == tab) {
                    guard selected != tab else { return }
                    #if os(iOS)
                    HapticEngine.selection()
                    #endif
                    withAnimation(SpektTheme.Motion.springSnappy) {
                        selected = tab
                    }
                }
            }
        }
        .padding(.horizontal, SpektTheme.Spacing.sm)
        .padding(.vertical, SpektTheme.Spacing.xs)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().fill(Color.white.opacity(0.06)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.11), lineWidth: 0.5))
                .shadow(color: Color.black.opacity(0.45), radius: 24, x: 0, y: 10)
        }
    }
}

// MARK: - Main View
struct SpektMainView: View {
    @State private var selected: SpektTab = .voice
    @StateObject private var signalVM = SignalViewModel()

    @ObservedObject private var callSession = CallSessionService.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            // Base — always visible behind translucent layers
            SpektTheme.Colors.base.ignoresSafeArea()

            // Tab content
            tabContent
                .animation(SpektTheme.Motion.springDefault, value: selected)
        }
        // Floating tab bar — insets content automatically
        .safeAreaInset(edge: .bottom) {
            SpektTabBar(selected: $selected)
                .padding(.horizontal, SpektTheme.Spacing.xxl)
                .padding(.bottom, SpektTheme.Spacing.md)
        }
        .ignoresSafeArea(.keyboard)
        .withCallManager()
        // Processing overlay — shown after call ends and app returns to foreground
        .fullScreenCover(isPresented: $callSession.showProcessing) {
            ProcessingView(signalVM: signalVM)
                .preferredColorScheme(.dark)
        }
        // Detect app returning to foreground (user came back from phone app)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                callSession.handleAppForeground()
            }
        }
        // When Activity tab gets new results, switch to it automatically
        .onReceive(NotificationCenter.default.publisher(for: .spektNewCallResults)) { _ in
            withAnimation(SpektTheme.Motion.springSnappy) { selected = .activity }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selected {
        case .voice:
            SpektHomeView(onShowActivity: {
                withAnimation(SpektTheme.Motion.springSnappy) { selected = .activity }
            })
            .transition(.glassReveal)
        case .activity:
            ActivityView()
                .transition(.glassReveal)
        case .signal:
            // Pass the shared SignalViewModel so ProcessingView can push memories into it
            SignalView(vm: signalVM)
                .transition(.glassReveal)
        case .profile:
            SpektProfileView()
                .transition(.glassReveal)
        }
    }
}

#Preview {
    SpektMainView()
        .preferredColorScheme(.dark)
}
