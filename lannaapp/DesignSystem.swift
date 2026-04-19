//
//  DesignSystem.swift
//  lannaapp
//
//  Legacy DS.* bridge — maps the old design token API to the new SpektTheme.
//  Auth views and any other code using DS.* or Typography.* continues to work
//  and now automatically adopts the Liquid Glass dark theme.
//
//  New code: use SpektTheme directly.
//

import SwiftUI

// MARK: - DS (Legacy Bridge)
struct DS {
    // Colors
    static let primary       = SpektTheme.Colors.accent
    static let secondary     = SpektTheme.Colors.glassRegular
    static let background    = SpektTheme.Colors.base
    static let surface       = SpektTheme.Colors.glassThin
    static let error         = SpektTheme.Colors.destructive
    static let success       = SpektTheme.Colors.positive
    static let textPrimary   = SpektTheme.Colors.textPrimary
    static let textSecondary = SpektTheme.Colors.textSecondary

    // Spacing
    static let spacingXS:  CGFloat = SpektTheme.Spacing.xs
    static let spacingS:   CGFloat = SpektTheme.Spacing.sm
    static let spacingM:   CGFloat = SpektTheme.Spacing.md
    static let spacingL:   CGFloat = SpektTheme.Spacing.lg
    static let spacingXL:  CGFloat = SpektTheme.Spacing.xl
    static let spacingXXL: CGFloat = SpektTheme.Spacing.xxl

    // Radius
    static let cornerRadius: CGFloat = SpektTheme.Radius.md
    static let cardRadius:   CGFloat = SpektTheme.Radius.lg

    // Shadow
    static let shadow = Color.black.opacity(0.30)
}

// MARK: - Typography (Legacy Bridge)
struct Typography {
    static let displayLarge  = SpektTheme.Typography.displayLarge
    static let displayMedium = SpektTheme.Typography.displayMedium
    static let titleLarge    = SpektTheme.Typography.titleLarge
    static let titleMedium   = SpektTheme.Typography.titleMedium
    static let titleSmall    = SpektTheme.Typography.titleSmall
    static let headline      = SpektTheme.Typography.titleMedium
    static let bodyLarge     = SpektTheme.Typography.bodyLarge
    static let bodyMedium    = SpektTheme.Typography.bodyMedium
    static let bodySmall     = SpektTheme.Typography.bodySmall
    static let label         = SpektTheme.Typography.caption
    static let caption       = SpektTheme.Typography.caption
    static let buttonText    = SpektTheme.Typography.titleSmall
}
