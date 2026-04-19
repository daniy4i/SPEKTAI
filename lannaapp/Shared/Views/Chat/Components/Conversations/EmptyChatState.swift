//
//  EmptyChatState.swift
//  lannaapp
//
//  Extracted from ChatComponents.swift
//

import SwiftUI

struct EmptyChatState: View {
    let projectName: String?
    let onStartChat: () -> Void

    var body: some View {
        VStack(spacing: DS.spacingL) {
            Image(systemName: "message.badge.filled.fill")
                .font(.system(size: 64))
                .foregroundColor(DS.primary.opacity(0.6))

            VStack(spacing: DS.spacingS) {
                Text("Start a Conversation")
                    .font(Typography.titleLarge)
                    .foregroundColor(DS.textPrimary)

                if let projectName = projectName {
                    Text("Create your first conversation in \(projectName)")
                        .font(Typography.bodyMedium)
                        .foregroundColor(DS.textSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Create a new conversation to get started")
                        .font(Typography.bodyMedium)
                        .foregroundColor(DS.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            Button(action: onStartChat) {
                HStack {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                    Text("Start Chat")
                        .font(Typography.buttonText)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, DS.spacingL)
                .padding(.vertical, DS.spacingM)
                .background(DS.primary)
                .cornerRadius(DS.cornerRadius)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(DS.spacingXL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}