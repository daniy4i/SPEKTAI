//
//  SpektHistoryView.swift
//  lannaapp
//
//  Conversation history — glass cards, minimal, scannable.
//

import SwiftUI

// MARK: - Data Model
struct ConversationItem: Identifiable {
    let id = UUID()
    let title: String
    let preview: String
    let timestamp: Date
    let durationMin: Int
    let category: Category

    enum Category {
        case general, schedule, tasks, email
        var icon: String {
            switch self {
            case .general:  return "bubble.left.and.bubble.right"
            case .schedule: return "calendar"
            case .tasks:    return "list.bullet"
            case .email:    return "envelope"
            }
        }
        var color: Color {
            switch self {
            case .general:  return SpektTheme.Colors.accent
            case .schedule: return SpektTheme.Colors.positive
            case .tasks:    return SpektTheme.Colors.accentSecondary
            case .email:    return SpektTheme.Colors.warning
            }
        }
    }

    var timeAgo: String {
        let diff = Date().timeIntervalSince(timestamp)
        switch diff {
        case ..<60:      return "just now"
        case ..<3600:    return "\(Int(diff / 60))m ago"
        case ..<86400:   return "\(Int(diff / 3600))h ago"
        default:         return "\(Int(diff / 86400))d ago"
        }
    }
}

extension ConversationItem {
    static let mock: [ConversationItem] = [
        .init(title: "Plan my week",
              preview: "Let's organize your Monday through Friday starting with the high-priority items…",
              timestamp: Date().addingTimeInterval(-3600 * 1.5),
              durationMin: 4,
              category: .schedule),
        .init(title: "Summarize my emails",
              preview: "You have 14 unread messages. Three are flagged as urgent from your team…",
              timestamp: Date().addingTimeInterval(-3600 * 6),
              durationMin: 2,
              category: .email),
        .init(title: "Project status update",
              preview: "Based on the tasks you've completed this week, the project is 68% done…",
              timestamp: Date().addingTimeInterval(-86400 * 1),
              durationMin: 6,
              category: .tasks),
        .init(title: "Morning briefing",
              preview: "Good morning. You have three meetings today starting at 9 AM…",
              timestamp: Date().addingTimeInterval(-86400 * 2),
              durationMin: 3,
              category: .general),
        .init(title: "Q2 goals review",
              preview: "You're tracking well on two of your four Q2 objectives. Let's look at the gaps…",
              timestamp: Date().addingTimeInterval(-86400 * 4),
              durationMin: 8,
              category: .tasks),
        .init(title: "Travel plans for April",
              preview: "I've found three flight options. The most convenient departs at 9:40 AM…",
              timestamp: Date().addingTimeInterval(-86400 * 6),
              durationMin: 5,
              category: .schedule),
    ]
}

// MARK: - Spekt Conversation Row
struct SpektConversationRow: View {
    let item: ConversationItem
    let index: Int

    var body: some View {
        GlassCard(intensity: .thin, cornerRadius: SpektTheme.Radius.md) {
            HStack(spacing: SpektTheme.Spacing.md) {
                // Category icon column
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(item.category.color.opacity(0.13))
                        .frame(width: 40, height: 40)
                    Image(systemName: item.category.icon)
                        .font(.system(size: 15, weight: .light))
                        .foregroundColor(item.category.color)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(SpektTheme.Typography.bodyMedium)
                        .foregroundColor(SpektTheme.Colors.textPrimary)
                        .lineLimit(1)
                    Text(item.preview)
                        .font(SpektTheme.Typography.bodySmall)
                        .foregroundColor(SpektTheme.Colors.textTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                // Meta
                VStack(alignment: .trailing, spacing: 4) {
                    Text(item.timeAgo)
                        .font(SpektTheme.Typography.caption)
                        .foregroundColor(SpektTheme.Colors.textTertiary)
                    Text("\(item.durationMin) min")
                        .font(SpektTheme.Typography.overline)
                        .foregroundColor(SpektTheme.Colors.textTertiary)
                }
            }
            .padding(.horizontal, SpektTheme.Spacing.md)
            .padding(.vertical, SpektTheme.Spacing.md - 2)
        }
        .pressScale(0.98)
        .staggeredAppear(index: index, baseDelay: 0.055)
    }
}

// MARK: - History View
struct SpektHistoryView: View {
    @State private var searchText    = ""
    @State private var headerVisible = false
    @State private var sessions: [ConversationItem] = []

    private var filtered: [ConversationItem] {
        guard !searchText.isEmpty else { return sessions }
        return sessions.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.preview.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            SpektTheme.Colors.base.ignoresSafeArea()

            ScrollView {
                VStack(spacing: SpektTheme.Spacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: SpektTheme.Spacing.sm) {
                        HStack {
                            Text("History")
                                .font(SpektTheme.Typography.displayMedium)
                                .foregroundColor(SpektTheme.Colors.textPrimary)
                            Spacer()
                            if !sessions.isEmpty {
                                GlassPillTag(
                                    label: "\(sessions.count) session\(sessions.count == 1 ? "" : "s")",
                                    color: SpektTheme.Colors.textTertiary
                                )
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .animation(SpektTheme.Motion.springDefault, value: sessions.count)

                        // Search bar — only shown when there's something to search
                        if !sessions.isEmpty {
                            HStack(spacing: SpektTheme.Spacing.sm) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 14, weight: .light))
                                    .foregroundColor(SpektTheme.Colors.textTertiary)
                                TextField("Search conversations…", text: $searchText)
                                    .font(SpektTheme.Typography.bodyMedium)
                                    .foregroundColor(SpektTheme.Colors.textPrimary)
                                    .tint(SpektTheme.Colors.accent)
                                if !searchText.isEmpty {
                                    Button {
                                        withAnimation(SpektTheme.Motion.springSnappy) { searchText = "" }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(SpektTheme.Colors.textTertiary)
                                    }
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding(.horizontal, SpektTheme.Spacing.md)
                            .padding(.vertical, 11)
                            .background {
                                RoundedRectangle(cornerRadius: SpektTheme.Radius.md, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: SpektTheme.Radius.md, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.5)
                                    }
                            }
                            .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, SpektTheme.Spacing.xl)
                    .opacity(headerVisible ? 1 : 0)
                    .offset(y: headerVisible ? 0 : -10)

                    // Content
                    if sessions.isEmpty {
                        // No sessions yet
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 32, weight: .ultraLight))
                                .foregroundColor(SpektTheme.Colors.textTertiary.opacity(0.40))
                            Text("No sessions yet.")
                                .font(SpektTheme.Typography.bodyMedium)
                                .foregroundColor(SpektTheme.Colors.textSecondary)
                            Text("Your call history will appear here after your first conversation.")
                                .font(SpektTheme.Typography.bodySmall)
                                .foregroundColor(SpektTheme.Colors.textTertiary.opacity(0.60))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, SpektTheme.Spacing.xxl)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, SpektTheme.Spacing.xxxl)
                        .transition(.opacity)
                    } else if filtered.isEmpty {
                        VStack(spacing: SpektTheme.Spacing.md) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 32, weight: .ultraLight))
                                .foregroundColor(SpektTheme.Colors.textTertiary)
                            Text("No results for \"\(searchText)\"")
                                .font(SpektTheme.Typography.bodyMedium)
                                .foregroundColor(SpektTheme.Colors.textTertiary)
                        }
                        .padding(.top, SpektTheme.Spacing.xxxl)
                        .transition(.opacity)
                    } else {
                        VStack(spacing: SpektTheme.Spacing.sm) {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { i, item in
                                SpektConversationRow(item: item, index: i)
                            }
                        }
                        .padding(.horizontal, SpektTheme.Spacing.xl)
                    }

                    Spacer(minLength: SpektTheme.Spacing.xxl)
                }
                .padding(.top, SpektTheme.Spacing.xl)
                .animation(SpektTheme.Motion.springDefault, value: sessions.isEmpty)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            withAnimation(SpektTheme.Motion.springDefault.delay(0.08)) {
                headerVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .spektNewCallResults)) { notification in
            guard let results = notification.object as? CallSessionResults else { return }

            // Build a ConversationItem from the call results
            let title: String = {
                if let first = results.keyOutcomes.first {
                    return String(first.prefix(50))
                }
                return String(results.summary.prefix(50))
            }()

            // Duration is unknown client-side — approximate from transcript length
            let wordCount    = results.transcript.split(separator: " ").count
            let durationMin  = max(1, wordCount / 130)   // ~130 words/min speaking pace

            let item = ConversationItem(
                title:       title,
                preview:     results.summary,
                timestamp:   Date(),
                durationMin: durationMin,
                category:    results.tasks.count > 0 ? .tasks : .general
            )
            withAnimation(SpektTheme.Motion.springDefault) {
                sessions.insert(item, at: 0)
            }
            #if os(iOS)
            HapticEngine.selection()
            #endif
        }
    }
}

#Preview {
    SpektHistoryView()
        .preferredColorScheme(.dark)
}
