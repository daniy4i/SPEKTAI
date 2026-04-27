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
        // ── Brand palette (SPEKT AI Brand Guidelines v2.0) ─────────────────
        static let neonGreen  = Color(hex: "#39FF14") // PRIMARY — action, CTA, energy
        static let signalRed  = Color(hex: "#E94560") // SECONDARY — urgency, warnings, LIVE
        static let void_      = Color(hex: "#08080D") // BACKGROUND — the absence
        static let skullBlue  = Color(hex: "#4A7CDB") // ACCENT — eyes of intelligence
        static let bone       = Color(hex: "#E8E6E1") // TEXT — primary on dark
        static let laserGold  = Color(hex: "#D4A843") // ACCENT — luxury, sparingly
        static let ash        = Color(hex: "#3A3A42") // STRUCTURE — secondary surfaces
        static let brandGray  = Color(hex: "#8B8B9E") // BODY — subtle text

        // ── App surface ─────────────────────────────────────────────────────
        static let base        = Color(hex: "#08080D")
        static let baseRaised  = Color(hex: "#0F0F14")

        // Glass tints — white layered over dark at increasing opacity
        static let glassUltraThin = Color.white.opacity(0.04)
        static let glassThin      = Color.white.opacity(0.07)
        static let glassRegular   = Color.white.opacity(0.10)
        static let glassElevated  = Color.white.opacity(0.14)
        static let glassBorder    = Color.white.opacity(0.10)
        static let glassHighlight = Color.white.opacity(0.20)

        // ── Accent mappings ─────────────────────────────────────────────────
        static let accent          = neonGreen                    // CTAs, primary actions
        static let accentSecondary = skullBlue                    // secondary actions
        static let accentGlow      = neonGreen.opacity(0.18)

        // ── Text hierarchy ──────────────────────────────────────────────────
        static let textPrimary   = bone                           // #E8E6E1
        static let textSecondary = Color(hex: "#E8E6E1").opacity(0.55)
        static let textTertiary  = Color(hex: "#8B8B9E")

        // ── Semantic ────────────────────────────────────────────────────────
        static let positive    = neonGreen                        // success states
        static let destructive = signalRed                        // #E94560
        static let warning     = laserGold                        // #D4A843
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
    // Georgia (serif) for headlines/body — Courier New for labels/data
    // Per SPEKT AI Brand Guidelines v2.0: never use sans-serif
    enum Typography {
        // Headlines — Georgia, the weight of permanence
        static let displayLarge  = Font.custom("Georgia",      size: 34)
        static let displayMedium = Font.custom("Georgia",      size: 28)
        static let titleLarge    = Font.custom("Georgia",      size: 22)
        static let titleMedium   = Font.custom("Georgia",      size: 18)
        static let titleSmall    = Font.custom("Georgia",      size: 16)

        // Body — Georgia, sentence case
        static let bodyLarge     = Font.custom("Georgia",      size: 17)
        static let bodyMedium    = Font.custom("Georgia",      size: 15)
        static let bodySmall     = Font.custom("Georgia",      size: 13)

        // Labels & data — Courier New, the precision of code
        static let caption       = Font.custom("Courier New",  size: 11)
        static let overline      = Font.custom("Courier New",  size: 10)
        static let mono          = Font.custom("Courier New",  size: 13)
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
