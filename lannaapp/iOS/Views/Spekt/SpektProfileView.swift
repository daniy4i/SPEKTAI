//
//  SpektProfileView.swift
//  lannaapp
//
//  Profile. One screen. No scroll. No clutter.
//  Identity indicator → 3 glass rows → sign out.
//

import SwiftUI

// MARK: - Profile Row
/// A single tappable glass row with icon, title, optional value, and chevron.
private struct ProfileRow: View {
    let icon      : String
    let title     : String
    var value     : String?       = nil
    var badge     : String?       = nil
    var badgeColor: Color         = SpektTheme.Colors.accent
    var iconColor : Color         = SpektTheme.Colors.textSecondary
    var showChevron: Bool         = true
    let action    : () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            #if os(iOS)
            HapticEngine.selection()
            #endif
            action()
        }) {
            HStack(spacing: 14) {

                // Icon slab
                IconSlab(icon: icon, color: iconColor)

                // Label
                Text(title)
                    .font(SpektTheme.Typography.bodyMedium)
                    .foregroundColor(SpektTheme.Colors.textPrimary)

                Spacer(minLength: 0)

                // Right side — value OR badge
                Group {
                    if let badge {
                        Text(badge)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(badgeColor)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background {
                                Capsule()
                                    .fill(badgeColor.opacity(0.10))
                                    .overlay(Capsule().strokeBorder(badgeColor.opacity(0.18), lineWidth: 0.5))
                            }
                    } else if let value {
                        Text(value)
                            .font(SpektTheme.Typography.bodySmall)
                            .foregroundColor(SpektTheme.Colors.textTertiary)
                    }
                }

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(SpektTheme.Colors.textTertiary.opacity(0.50))
                }
            }
            .padding(.horizontal, SpektTheme.Spacing.md)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.975))
    }
}

// MARK: - Sign Out Row
/// Two-phase destructive action. First tap arms it; second tap fires.
/// Auto-disarms after 2.5 s if not confirmed. No system sheet.
private struct SignOutRow: View {
    @ObservedObject private var authService = AuthService.shared

    @State private var phase: Phase = .idle
    @State private var disarmTask: Task<Void, Never>?

    enum Phase { case idle, armed, signingOut }

    var body: some View {
        Button {
            switch phase {
            case .idle:
                arm()
            case .armed:
                fire()
            case .signingOut:
                break
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(rowIconColor.opacity(0.10))
                        .frame(width: 34, height: 34)
                    Image(systemName: rowIcon)
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(rowIconColor)
                        .contentTransition(.symbolEffect(.replace))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(rowTitle)
                        .font(SpektTheme.Typography.bodyMedium)
                        .foregroundColor(rowTextColor)
                        .animation(SpektTheme.Motion.springSnappy, value: phase)

                    if phase == .armed {
                        Text("Tap again to confirm")
                            .font(.system(size: 11))
                            .foregroundColor(SpektTheme.Colors.destructive.opacity(0.60))
                            .transition(.asymmetric(
                                insertion: .offset(y: 4).combined(with: .opacity),
                                removal:   .opacity
                            ))
                    }
                }

                Spacer()

                // Arm indicator
                if phase == .armed {
                    Circle()
                        .fill(SpektTheme.Colors.destructive)
                        .frame(width: 6, height: 6)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, SpektTheme.Spacing.md)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.975))
        .animation(SpektTheme.Motion.springDefault, value: phase)
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private var rowIcon: String {
        switch phase {
        case .idle:      return "rectangle.portrait.and.arrow.right"
        case .armed:     return "exclamationmark.triangle"
        case .signingOut: return "arrow.circlepath"
        }
    }

    private var rowIconColor: Color {
        phase == .idle ? SpektTheme.Colors.textTertiary : SpektTheme.Colors.destructive
    }

    private var rowTextColor: Color {
        phase == .idle ? SpektTheme.Colors.textTertiary : SpektTheme.Colors.textPrimary
    }

    private var rowTitle: String {
        switch phase {
        case .idle:       return "Sign Out"
        case .armed:      return "Sign Out"
        case .signingOut: return "Signing out…"
        }
    }

    private func arm() {
        #if os(iOS)
        HapticEngine.impact(.light)
        #endif
        withAnimation(SpektTheme.Motion.springDefault) { phase = .armed }

        // Auto-disarm
        disarmTask?.cancel()
        disarmTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(SpektTheme.Motion.springDefault) { phase = .idle }
            }
        }
    }

    private func fire() {
        disarmTask?.cancel()
        #if os(iOS)
        HapticEngine.notify(.warning)
        #endif
        withAnimation(SpektTheme.Motion.springDefault) { phase = .signingOut }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            try? authService.signOut()
        }
    }
}

// MARK: - Subscription Sheet
private struct SubscriptionSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SheetScaffold(title: "Subscription") {
            VStack(spacing: SpektTheme.Spacing.lg) {
                // Plan card
                GlassCard(intensity: .regular, cornerRadius: SpektTheme.Radius.lg, isElevated: true) {
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("SPEKT AI Pro")
                                    .font(SpektTheme.Typography.titleMedium)
                                    .foregroundColor(SpektTheme.Colors.textPrimary)
                                Text("Renews May 18, 2026")
                                    .font(SpektTheme.Typography.bodySmall)
                                    .foregroundColor(SpektTheme.Colors.textTertiary)
                            }
                            Spacer()
                            GlassPillTag(label: "Active", dot: SpektTheme.Colors.positive)
                        }
                        .padding(SpektTheme.Spacing.lg)

                        GlassDivider()

                        HStack {
                            Text("$12 / month")
                                .font(SpektTheme.Typography.bodyMedium)
                                .foregroundColor(SpektTheme.Colors.textSecondary)
                            Spacer()
                            GlassPillTag(label: "Renews May 2026", color: SpektTheme.Colors.textTertiary)
                        }
                        .padding(SpektTheme.Spacing.lg)
                    }
                }

                // Feature list
                VStack(alignment: .leading, spacing: SpektTheme.Spacing.sm) {
                    FeatureLine(text: "Unlimited voice sessions")
                    FeatureLine(text: "Full integrations suite")
                    FeatureLine(text: "Priority AI response")
                    FeatureLine(text: "Context memory — 90 days")
                }
                .padding(.horizontal, SpektTheme.Spacing.sm)
            }
        }
    }
}

private struct FeatureLine: View {
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(SpektTheme.Colors.positive)
            Text(text)
                .font(SpektTheme.Typography.bodySmall)
                .foregroundColor(SpektTheme.Colors.textSecondary)
        }
    }
}

// MARK: - Permissions Sheet
private struct PermissionsSheet: View {
    @State private var micOn           = true
    @State private var notificationsOn = true
    @State private var backgroundOn    = false

    // Wired directly to CallManager's AppStorage key
    @AppStorage("spekt_confirmBeforeCalling") private var confirmBeforeCalling = false

    var body: some View {
        SheetScaffold(title: "Permissions") {
            GlassCard(intensity: .thin, cornerRadius: SpektTheme.Radius.lg) {
                VStack(spacing: 0) {
                    PermissionToggleRow(
                        icon:  "mic",
                        title: "Microphone",
                        note:  "Required for voice sessions",
                        iconColor: SpektTheme.Colors.accent,
                        isOn: $micOn
                    )
                    GlassDivider().padding(.leading, 56)

                    PermissionToggleRow(
                        icon:  "bell",
                        title: "Notifications",
                        note:  "Outcome alerts and reminders",
                        iconColor: SpektTheme.Colors.warning,
                        isOn: $notificationsOn
                    )
                    GlassDivider().padding(.leading, 56)

                    PermissionToggleRow(
                        icon:  "arrow.clockwise",
                        title: "Background refresh",
                        note:  "Keep context current",
                        iconColor: SpektTheme.Colors.textSecondary,
                        isOn: $backgroundOn
                    )
                    GlassDivider().padding(.leading, 56)

                    PermissionToggleRow(
                        icon:      "phone.badge.checkmark",
                        title:     "Confirm before calling",
                        note:      "Show prompt before dialling",
                        iconColor: SpektTheme.Colors.positive,
                        isOn:      $confirmBeforeCalling
                    )
                }
            }
        }
    }
}

private struct PermissionToggleRow: View {
    let icon     : String
    let title    : String
    let note     : String
    let iconColor: Color
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            IconSlab(icon: icon, color: iconColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SpektTheme.Typography.bodyMedium)
                    .foregroundColor(SpektTheme.Colors.textPrimary)
                Text(note)
                    .font(.system(size: 11))
                    .foregroundColor(SpektTheme.Colors.textTertiary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(SpektTheme.Colors.accent)
        }
        .padding(.horizontal, SpektTheme.Spacing.md)
        .padding(.vertical, 12)
    }
}

// MARK: - Integrations Sheet
private struct IntegrationsSheet: View {
    @ObservedObject private var manager = IntegrationsManager.shared

    var body: some View {
        SheetScaffold(title: "Integrations") {
            GlassCard(intensity: .thin, cornerRadius: SpektTheme.Radius.lg) {
                VStack(spacing: 0) {
                    ForEach(Array(IntegrationType.allCases.enumerated()), id: \.element.id) { i, type in
                        ProfileIntegrationRow(type: type)
                        if i < IntegrationType.allCases.count - 1 {
                            GlassDivider().padding(.leading, 56)
                        }
                    }
                }
            }
        }
        .alert("Enable in Settings", isPresented: $manager.showDeniedAlert) {
            Button("Open Settings") { manager.openSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(manager.deniedService) access was denied. Open Settings to allow it.")
        }
        .onAppear { manager.refreshAll() }
    }
}

private struct ProfileIntegrationRow: View {
    let type: IntegrationType
    @ObservedObject private var manager = IntegrationsManager.shared

    private var status: IntegrationStatus { manager.status(for: type) }

    var body: some View {
        HStack(spacing: 14) {
            IconSlab(icon: type.icon, color: SpektTheme.Colors.textSecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(type.title)
                    .font(SpektTheme.Typography.bodyMedium)
                    .foregroundColor(SpektTheme.Colors.textPrimary)
                Text(type.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(SpektTheme.Colors.textTertiary)
            }

            Spacer()

            statusControl
        }
        .padding(.horizontal, SpektTheme.Spacing.md)
        .padding(.vertical, 12)
        .animation(SpektTheme.Motion.springSnappy, value: status)
    }

    @ViewBuilder
    private var statusControl: some View {
        switch status {

        case .loading:
            ProgressView()
                .scaleEffect(0.72)
                .tint(SpektTheme.Colors.accent)
                .frame(width: 70)

        case .authorized:
            // Already connected — tap label is informational only
            HStack(spacing: 4) {
                Circle()
                    .fill(SpektTheme.Colors.positive)
                    .frame(width: 5, height: 5)
                Text("Connected")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(SpektTheme.Colors.positive)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                Capsule()
                    .fill(SpektTheme.Colors.positive.opacity(0.10))
                    .overlay(Capsule().strokeBorder(SpektTheme.Colors.positive.opacity(0.20), lineWidth: 0.5))
            }

        case .denied:
            Button {
                #if os(iOS)
                HapticEngine.impact(.light)
                #endif
                manager.openSettings()
            } label: {
                Text("Enable →")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(SpektTheme.Colors.warning)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background {
                        Capsule()
                            .fill(SpektTheme.Colors.warning.opacity(0.10))
                            .overlay(Capsule().strokeBorder(SpektTheme.Colors.warning.opacity(0.20), lineWidth: 0.5))
                    }
            }
            .buttonStyle(PressableButtonStyle(scale: 0.94))

        case .notDetermined:
            Button {
                #if os(iOS)
                HapticEngine.selection()
                #endif
                manager.connect(type)
            } label: {
                Text("Connect")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(SpektTheme.Colors.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background {
                        Capsule()
                            .fill(SpektTheme.Colors.accent.opacity(0.10))
                            .overlay(Capsule().strokeBorder(SpektTheme.Colors.accent.opacity(0.20), lineWidth: 0.5))
                    }
            }
            .buttonStyle(PressableButtonStyle(scale: 0.94))
        }
    }
}

// MARK: - Sheet Scaffold
/// Reusable bottom sheet wrapper — consistent header, background, and padding.
private struct SheetScaffold<Content: View>: View {
    let title  : String
    @ViewBuilder var content: () -> Content

    @Environment(\.dismiss) private var dismiss
    @State private var contentVisible = false

    var body: some View {
        ZStack {
            SpektTheme.Colors.base.ignoresSafeArea()

            VStack(alignment: .leading, spacing: SpektTheme.Spacing.xl) {
                // Sheet handle + title
                VStack(alignment: .leading, spacing: SpektTheme.Spacing.md) {
                    HStack {
                        Spacer()
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 36, height: 4)
                        Spacer()
                    }

                    Text(title)
                        .font(SpektTheme.Typography.titleLarge)
                        .foregroundColor(SpektTheme.Colors.textPrimary)
                }

                content()
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 10)

                Spacer()
            }
            .padding(.horizontal, SpektTheme.Spacing.xl)
            .padding(.top, SpektTheme.Spacing.lg)
        }
        .onAppear {
            withAnimation(SpektTheme.Motion.springDefault.delay(0.08)) {
                contentVisible = true
            }
        }
    }
}

// MARK: - Profile View
struct SpektProfileView: View {
    @ObservedObject private var authService    = AuthService.shared
    @ObservedObject private var integrations   = IntegrationsManager.shared

    @State private var showSubscription  = false
    @State private var showPermissions   = false
    @State private var showIntegrations  = false

    @State private var identityVisible   = false
    @State private var rowsVisible       = false

    private var displayEmail: String {
        authService.user?.email
            ?? UserDefaults.standard.string(forKey: "mockAuth_email")
            ?? "spekt@user.com"
    }

    private var initials: String {
        let name = displayEmail.components(separatedBy: "@").first ?? ""
        let parts = name.components(separatedBy: CharacterSet(charactersIn: "._-"))
        return parts.prefix(2).compactMap { $0.first.map { String($0).uppercased() } }.joined()
    }

    var body: some View {
        ZStack {
            SpektTheme.Colors.base.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                // ── Identity indicator ────────────────────────────────────────
                identityIndicator
                    .padding(.horizontal, SpektTheme.Spacing.xl)
                    .padding(.top, 72)
                    .opacity(identityVisible ? 1 : 0)
                    .offset(y: identityVisible ? 0 : -8)

                Spacer().frame(height: 44)

                // ── Main rows ─────────────────────────────────────────────────
                GlassCard(intensity: .thin, cornerRadius: SpektTheme.Radius.lg) {
                    VStack(spacing: 0) {
                        ProfileRow(
                            icon:       "sparkles",
                            title:      "Subscription",
                            badge:      "Pro",
                            badgeColor: SpektTheme.Colors.accent,
                            iconColor:  SpektTheme.Colors.accent
                        ) {
                            showSubscription = true
                        }

                        GlassDivider().padding(.leading, 56)

                        ProfileRow(
                            icon:      "lock.shield",
                            title:     "Permissions",
                            value:     "Mic · Notifications",
                            iconColor: SpektTheme.Colors.positive
                        ) {
                            showPermissions = true
                        }

                        GlassDivider().padding(.leading, 56)

                        ProfileRow(
                            icon:      "square.grid.2x2",
                            title:     "Integrations",
                            value:     integrations.connectedCount == 0
                                         ? "None connected"
                                         : "\(integrations.connectedCount) connected",
                            iconColor: SpektTheme.Colors.accentSecondary
                        ) {
                            showIntegrations = true
                        }
                    }
                }
                .padding(.horizontal, SpektTheme.Spacing.xl)
                .opacity(rowsVisible ? 1 : 0)
                .offset(y: rowsVisible ? 0 : 12)

                Spacer()

                // ── Destructive zone ──────────────────────────────────────────
                destructiveZone
                    .padding(.horizontal, SpektTheme.Spacing.xl)
                    .padding(.bottom, SpektTheme.Spacing.xl)
                    .opacity(rowsVisible ? 1 : 0)
            }
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .presentationBackground(SpektTheme.Colors.base)
                .presentationCornerRadius(SpektTheme.Radius.xl)
        }
        .sheet(isPresented: $showPermissions) {
            PermissionsSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .presentationBackground(SpektTheme.Colors.base)
                .presentationCornerRadius(SpektTheme.Radius.xl)
        }
        .sheet(isPresented: $showIntegrations) {
            IntegrationsSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .presentationBackground(SpektTheme.Colors.base)
                .presentationCornerRadius(SpektTheme.Radius.xl)
        }
        .onAppear {
            withAnimation(SpektTheme.Motion.springDefault.delay(0.05)) { identityVisible = true }
            withAnimation(SpektTheme.Motion.springDefault.delay(0.16)) { rowsVisible     = true }
        }
    }

    // MARK: Identity Indicator
    private var identityIndicator: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                SpektTheme.Colors.accent.opacity(0.75),
                                SpektTheme.Colors.accentSecondary.opacity(0.45)
                            ],
                            center: UnitPoint(x: 0.35, y: 0.3),
                            startRadius: 0,
                            endRadius: 20
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5))

                Text(initials.isEmpty ? "SP" : initials)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.92))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(displayEmail)
                    .font(SpektTheme.Typography.bodyMedium)
                    .foregroundColor(SpektTheme.Colors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Circle()
                        .fill(SpektTheme.Colors.positive)
                        .frame(width: 5, height: 5)
                    Text("Active")
                        .font(.system(size: 11))
                        .foregroundColor(SpektTheme.Colors.textTertiary)
                }
            }

            Spacer()

            // Info button — top-right of identity row
            Button {
                #if os(iOS)
                HapticEngine.selection()
                #endif
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(SpektTheme.Colors.textTertiary)
            }
            .buttonStyle(PressableButtonStyle(scale: 0.88))
            .padding(.top, 8)
        }
    }

    // MARK: Destructive Zone
    private var destructiveZone: some View {
        GlassCard(intensity: .ultraThin, cornerRadius: SpektTheme.Radius.lg) {
            SignOutRow()
        }
    }
}

// MARK: - Preview
#Preview {
    SpektProfileView()
        .preferredColorScheme(.dark)
}
