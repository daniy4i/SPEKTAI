//
//  TypingIndicator.swift
//  lannaapp
//
//  Extracted from ChatComponents.swift
//

import SwiftUI

struct TypingIndicator: View {
    @State private var animationOffset: CGFloat = 0

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(DS.primary)

            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(DS.textSecondary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(1.0 + sin(animationOffset + Double(index) * 0.5) * 0.5)
                        .animation(
                            Animation.easeInOut(duration: 1.2)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: animationOffset
                        )
                }
            }

            Spacer()
        }
        .padding(.horizontal, DS.spacingM)
        .padding(.vertical, DS.spacingS)
        .background(DS.surface)
        .cornerRadius(DS.cornerRadius)
        .onAppear {
            animationOffset = .pi * 2
        }
    }
}