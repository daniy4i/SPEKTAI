//
//  GlassComponents.swift
//  lannaapp
//
//  Reusable Liquid Glass components for SPEKT AI.
//  These are the atomic building blocks of the design system.
//

import SwiftUI

// MARK: - Pressable Button Style
/// Physical press feedback for Button controls.
/// Scale contracts + brightness darkens on press (surface recedes under touch).
/// Springs back on release — interactiveSpring ensures sub-20ms response time.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(SpektTheme.Motion.interactiveSpring, value: configuration.isPressed)
    }
}

// MARK: - GlassCard
/// The foundation glass surface. Translucent, layered, softly rounded.
/// Uses ultraThinMaterial as the blur base, overlaid with a tinted glass fill
/// and a directional highlight border to simulate light refraction.
struct GlassCard<Content: View>: View {
    var intensity: GlassIntensity = .regular
    var cornerRadius: CGFloat = SpektTheme.Radius.lg
    var isElevated: Bool = false
    var accentBorder: Bool = false
    @ViewBuilder var content: () -> Content

    enum GlassIntensity {
        case ultraThin, thin, regular, elevated
        var fillOpacity: Double {
            switch self {
            case .ultraThin: 0.03
            case .thin:      0.06
            case .regular:   0.09
            case .elevated:  0.13
            }
        }
    }

    var body: some View {
        content()
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    // Tinted glass fill
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.white.opacity(intensity.fillOpacity))
                    }
                    // Directional highlight border (top-leading light catch)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        accentBorder
                                            ? SpektTheme.Colors.accent.opacity(0.55)
                                            : Color.white.opacity(isElevated ? 0.18 : 0.11),
                                        Color.white.opacity(0.02)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
                    .shadow(
                        color: Color.black.opacity(isElevated ? 0.45 : 0.22),
                        radius: isElevated ? 32 : 12,
                        x: 0, y: isElevated ? 12 : 4
                    )
            }
    }
}

// MARK: - GlassSurface
/// Lighter, flatter surface — for page backgrounds and secondary panels.
struct GlassSurface<Content: View>: View {
    var cornerRadius: CGFloat = SpektTheme.Radius.xl
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(SpektTheme.Colors.glassUltraThin)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(SpektTheme.Colors.glassBorder, lineWidth: 0.5)
                    }
            }
    }
}

// MARK: - GlassActionButton
/// Full-width pill button. Accent fill or glass fill variants.
struct GlassActionButton: View {
    let title: String
    var icon: String? = nil
    var style: FillStyle = .accent
    var isLoading: Bool = false
    let action: () -> Void

    enum FillStyle { case accent, glass, destructive }

    var body: some View {
        Button(action: {
            #if os(iOS)
            HapticEngine.impact(.light)
            #endif
            action()
        }) {
            HStack(spacing: SpektTheme.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(foreground)
                        .scaleEffect(0.72)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                }
                Text(isLoading ? "Loading…" : title)
                    .font(SpektTheme.Typography.titleSmall)
            }
            .foregroundColor(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpektTheme.Spacing.md)
            .background(background)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isLoading)
    }

    private var foreground: Color {
        switch style {
        case .accent, .destructive: return .white
        case .glass:                return SpektTheme.Colors.textPrimary
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .accent:
            Capsule().fill(SpektTheme.Colors.accent)
        case .destructive:
            Capsule().fill(SpektTheme.Colors.destructive)
        case .glass:
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().fill(Color.white.opacity(0.08)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
        }
    }
}

// MARK: - GlassTextField
/// Text field with glass background — integrates into dark layouts.
struct GlassTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var icon: String? = nil

    var body: some View {
        HStack(spacing: SpektTheme.Spacing.sm) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(SpektTheme.Colors.textTertiary)
                    .frame(width: 20)
            }
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(SpektTheme.Typography.bodyMedium)
            .foregroundColor(SpektTheme.Colors.textPrimary)
            .tint(SpektTheme.Colors.accent)
        }
        .padding(.horizontal, SpektTheme.Spacing.md)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: SpektTheme.Radius.md, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: SpektTheme.Radius.md, style: .continuous)
                        .fill(SpektTheme.Colors.glassThin)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: SpektTheme.Radius.md, style: .continuous)
                        .strokeBorder(SpektTheme.Colors.glassBorder, lineWidth: 0.5)
                }
        }
    }
}

// MARK: - GlassDivider
struct GlassDivider: View {
    var opacity: Double = 0.09
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(opacity))
            .frame(height: 0.5)
    }
}

// MARK: - IconSlab
/// Standardised icon container used in all list rows.
/// 36×36, cornerRadius 9, icon at 15pt light weight.
/// Single source of truth — keeps all rows visually aligned.
struct IconSlab: View {
    let icon : String
    var color: Color  = SpektTheme.Colors.accent
    var size : CGFloat = 36

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(color.opacity(0.12))
                .frame(width: size, height: size)
            Image(systemName: icon)
                .font(.system(size: 15, weight: .light))
                .foregroundColor(color)
        }
    }
}

// MARK: - GlassPillTag
/// Small status / label pill — used for metadata and state badges.
struct GlassPillTag: View {
    let label: String
    var color: Color = SpektTheme.Colors.textSecondary
    var dot: Color? = nil

    var body: some View {
        HStack(spacing: 5) {
            if let dot {
                Circle().fill(dot).frame(width: 5, height: 5)
            }
            Text(label)
                .font(SpektTheme.Typography.overline)
                .foregroundColor(color)
        }
        .padding(.horizontal, SpektTheme.Spacing.sm + 2)
        .padding(.vertical, SpektTheme.Spacing.xs)
        .background {
            Capsule()
                .fill(Color.white.opacity(0.07))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.09), lineWidth: 0.5))
        }
    }
}

// MARK: - GlassSettingsRow
/// Navigation / settings row with icon, title, optional subtitle and chevron.
struct GlassSettingsRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var showChevron: Bool = true
    var iconColor: Color = SpektTheme.Colors.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SpektTheme.Spacing.md) {
                IconSlab(icon: icon, color: iconColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(SpektTheme.Typography.bodyMedium)
                        .foregroundColor(SpektTheme.Colors.textPrimary)
                    if let sub = subtitle {
                        Text(sub)
                            .font(SpektTheme.Typography.bodySmall)
                            .foregroundColor(SpektTheme.Colors.textTertiary)
                    }
                }
                Spacer()
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(SpektTheme.Colors.textTertiary)
                }
            }
            .padding(.horizontal, SpektTheme.Spacing.md)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.985))
    }
}
