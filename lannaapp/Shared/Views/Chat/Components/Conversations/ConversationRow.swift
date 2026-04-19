//
//  ConversationRow.swift
//  lannaapp
//
//  Extracted from ChatComponents.swift
//

import SwiftUI

struct ConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool

    private var hasSharedContext: Bool {
        conversation.sharedContext != nil ||
        (conversation.sharedDocuments?.isEmpty == false)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Project or conversation icon
            Circle()
                .fill(isSelected ? DS.primary : DS.surface)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(conversation.projectName?.prefix(1) ?? conversation.lastMessage.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isSelected ? .white : DS.textPrimary)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.projectName ?? "Conversation")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isSelected ? .white : DS.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Text(formatTimestamp(conversation.lastMessageAt))
                        .font(.system(size: 13))
                        .foregroundColor(isSelected ? .white.opacity(0.7) : DS.textSecondary)
                }

                HStack {
                    Text(conversation.lastMessage.isEmpty ? "No messages yet" : conversation.lastMessage)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : DS.textSecondary)
                        .lineLimit(2)

                    Spacer()

                    HStack(spacing: 4) {
                        // Show shared context indicator
                        if hasSharedContext {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(isSelected ? .white.opacity(0.7) : DS.primary)
                        }

                        // Message count indicator
                        if conversation.messagesCount > 0 {
                            Text("\(conversation.messagesCount)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(isSelected ? Color.white.opacity(0.3) : DS.primary)
                                .cornerRadius(10)
                        }
                    }
                }
            }

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white.opacity(0.7) : DS.textSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(isSelected ? DS.primary : Color.clear)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(DS.textSecondary.opacity(0.3)),
            alignment: .bottom
        )
        .contentShape(Rectangle())
    }

    // Helper function to format timestamps like iMessage
    private func formatTimestamp(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.dateInterval(of: .weekOfYear, for: now)?.contains(date) == true {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d/yy"
            return formatter.string(from: date)
        }
    }
}