//
//  SpektTheme.swift
//  lannaapp
//
//  Design foundation for SPEKT AI — Liquid Glass design language.
//  All new views use SpektTheme directly. Legacy DS.* bridges here.
//

import SwiftUI

// MARK: - Color Hex Initializer
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64, r: UInt64, g: UInt64, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - SpektTheme
enum SpektTheme {

    // MARK: Colors
    enum Colors {
        /// True base: #08080D — deep near-black with a cool blue undertone
        static let base        = Color(hex: "#08080D")
        static let baseRaised  = Color(hex: "#0F0F1A")

        // Glass tints — white layered over dark at increasing opacity
        static let glassUltraThin = Color.white.opacity(0.04)
        static let glassThin      = Color.white.opacity(0.07)
        static let glassRegular   = Color.white.opacity(0.10)
        static let glassElevated  = Color.white.opacity(0.14)
        static let glassBorder    = Color.white.opacity(0.10)
        static let glassHighlight = Color.white.opacity(0.20)

        // Accent — soft indigo (Apple‑adjacent, not garish)
        static let accent          = Color(hex: "#5E5CE6")
        static let accentSecondary = Color(hex: "#BF5AF2")
        static let accentGlow      = Color(hex: "#5E5CE6").opacity(0.22)

        // Text hierarchy
        static let textPrimary   = Color.white
        static let textSecondary = Color.white.opacity(0.55)
        static let textTertiary  = Color.white.opacity(0.30)

        // Semantic
        static let positive    = Color(hex: "#34C759")
        static let destructive = Color(hex: "#FF375F")
        static let warning     = Color(hex: "#FF9F0A")
    }

    // MARK: Spacing
    enum Spacing {
        static let xs:   CGFloat = 4
        static let sm:   CGFloat = 8
        static let md:   CGFloat = 16
        static let lg:   CGFloat = 24
        static let xl:   CGFloat = 32
        static let xxl:  CGFloat = 48
        static let xxxl: CGFloat = 64
    }

    // MARK: Radius
    enum Radius {
        static let sm:   CGFloat = 10
        static let md:   CGFloat = 16
        static let lg:   CGFloat = 24
        static let xl:   CGFloat = 32
        static let pill: CGFloat = 9999
    }

    // MARK: Typography
    enum Typography {
        static let displayLarge  = Font.system(size: 34, weight: .bold,     design: .default)
        static let displayMedium = Font.system(size: 28, weight: .semibold, design: .default)
        static let titleLarge    = Font.system(size: 22, weight: .semibold, design: .default)
        static let titleMedium   = Font.system(size: 18, weight: .semibold, design: .default)
        static let titleSmall    = Font.system(size: 16, weight: .semibold, design: .default)
        static let bodyLarge     = Font.system(size: 17, weight: .regular,  design: .default)
        static let bodyMedium    = Font.system(size: 15, weight: .regular,  design: .default)
        static let bodySmall     = Font.system(size: 13, weight: .regular,  design: .default)
        static let caption       = Font.system(size: 11, weight: .medium,   design: .default)
        static let overline      = Font.system(size: 10, weight: .semibold, design: .default)
        static let mono          = Font.system(size: 13, weight: .regular,  design: .monospaced)
    }

    // MARK: Motion
    enum Motion {
        // ── Semantic springs (use these in views) ─────────────────────────
        /// Standard: smooth, physical. Default for state transitions. (~0.35s feel)
        static let springDefault     = Animation.spring(response: 0.42, dampingFraction: 0.78)
        /// Snappy: instant taps, toggles, selection feedback. (~0.20s feel)
        static let springSnappy      = Animation.spring(response: 0.26, dampingFraction: 0.84)
        /// Bouncy: weight + return. Orb, CTA confirmation. (~0.45s feel)
        static let springBouncy      = Animation.spring(response: 0.50, dampingFraction: 0.62)
        /// Smooth: slow, authoritative page-level transitions. (~0.60s feel)
        static let springSmooth      = Animation.spring(response: 0.62, dampingFraction: 0.92)
        /// Interactive: finger-follows-touch. Press states, direct drag. (~0.18s feel)
        static let interactiveSpring = Animation.spring(response: 0.20, dampingFraction: 0.80)

        // ── Temporal aliases (spec-compliant naming) ───────────────────────
        /// ~0.20s — immediate feedback, icon swaps
        static var fast:   Animation { springSnappy }
        /// ~0.35s — standard transitions, card expand/collapse
        static var normal: Animation { springDefault }
        /// ~0.60s — page entries, ambient shifts
        static var slow:   Animation { springSmooth }

        // ── Duration-based (for non-spring use: loaders, skeletons) ───────
        static let short  = Animation.easeInOut(duration: 0.18)
        static let medium = Animation.easeInOut(duration: 0.30)
        static let long   = Animation.easeInOut(duration: 0.50)

        // ── Continuous loops ────────────────────────────────────────────────
        /// Breathing idle state
        static func breathe(_ duration: Double = 3.8) -> Animation {
            .easeInOut(duration: duration).repeatForever(autoreverses: true)
        }
        /// Slow rotation
        static func rotate(_ duration: Double = 20.0) -> Animation {
            .linear(duration: duration).repeatForever(autoreverses: false)
        }
    }
}
