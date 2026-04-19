//
//  ActivityView.swift
//  lannaapp
//
//  A vertical timeline of outcomes — not a chat log, not a message feed.
//  Each item is an action the AI completed on your behalf.
//  Minimal. Scannable. Expandable.
//

import SwiftUI

// MARK: - Category
enum ActivityCategory: String {
    case booking       = "booking"
    case scheduling    = "scheduling"
    case travel        = "travel"
    case communication = "communication"
    case research      = "research"
    case tasks         = "tasks"
    case shopping      = "shopping"

    var icon: String {
        switch self {
        case .booking:       return "fork.knife"
        case .scheduling:    return "calendar"
        case .travel:        return "airplane"
        case .communication: return "envelope"
        case .research:      return "magnifyingglass"
        case .tasks:         return "checkmark.circle"
        case .shopping:      return "bag"
        }
    }

    var label: String {
        switch self {
        case .booking:       return "Booking"
        case .scheduling:    return "Scheduling"
        case .travel:        return "Travel"
        case .communication: return "Communication"
        case .research:      return "Research"
        case .tasks:         return "Tasks"
        case .shopping:      return "Shopping"
        }
    }

    var color: Color {
        switch self {
        case .booking:       return SpektTheme.Colors.positive
        case .scheduling:    return SpektTheme.Colors.accent
        case .travel:        return SpektTheme.Colors.warning
        case .communication: return SpektTheme.Colors.accentSecondary
        case .research:      return Color.white.opacity(0.55)
        case .tasks:         return SpektTheme.Colors.positive
        case .shopping:      return SpektTheme.Colors.warning
        }
    }
}

// MARK: - Activity Item
struct ActivityItem: Identifiable {
    let id       = UUID()
    let action   : String          // Short outcome — the headline
    let detail   : String          // One-line summary
    let expanded : String          // Full detail shown on expand
    let context  : String?         // Why it happened — the "intent" behind it
    let category : ActivityCategory
    let timestamp: Date

    var timeAgo: String {
        let d = Date().timeIntervalSince(timestamp)
        switch d {
        case ..<60:    return "just now"
        case ..<3600:  return "\(Int(d / 60))m ago"
        case ..<86400: return "\(Int(d / 3600))h ago"
        default:       return "\(Int(d / 86400))d ago"
        }
    }

    var exactTime: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d · h:mm a"
        return f.string(from: timestamp)
    }
}

extension ActivityItem {
    static let samples: [ActivityItem] = [
        .init(
            action:    "Booked dinner at Carbone",
            detail:    "Carbone NYC · Fri 8PM · 2 guests",
            expanded:  "Reservation confirmed at Carbone, New York. Friday, April 18 at 8:00 PM for 2 guests. Confirmation #CB-4821. Deposit not required.",
            context:   "You wanted to celebrate your promotion",
            category:  .booking,
            timestamp: Date().addingTimeInterval(-3_600 * 2)
        ),
        .init(
            action:    "Scheduled meeting with Alex",
            detail:    "Zoom · Mon 3PM · 45 min",
            expanded:  "Calendar invite sent to alex@company.com. Monday April 22 at 3:00 PM EDT. 45-minute block titled 'Q2 Strategy Sync.' Zoom link generated and included.",
            context:   "Following your Q2 planning thread",
            category:  .scheduling,
            timestamp: Date().addingTimeInterval(-3_600 * 5)
        ),
        .init(
            action:    "Found flights to Miami",
            detail:    "AA 847 · Apr 22 · $189 one-way",
            expanded:  "Best option: American Airlines AA 847. Departs JFK 9:40 AM, arrives MIA 1:04 PM. $189 one-way, Main Cabin. 3 seats remaining at this price.",
            context:   "You asked to check spring getaway options",
            category:  .travel,
            timestamp: Date().addingTimeInterval(-3_600 * 9)
        ),
        .init(
            action:    "Drafted email to the team",
            detail:    "8 recipients · Q2 roadmap update",
            expanded:  "Draft saved to your outbox. Subject: 'Q2 Roadmap Update — Key Changes.' 3 paragraphs covering timeline shift, resourcing, and next steps. Awaiting your review before sending.",
            context:   "You asked to communicate the timeline change",
            category:  .communication,
            timestamp: Date().addingTimeInterval(-86_400 * 1 - 3_600 * 2)
        ),
        .init(
            action:    "Planned weekly agenda",
            detail:    "15 tasks · 3 focus blocks · 2 meetings",
            expanded:  "Week of April 22 structured. Monday/Wednesday: deep work 9–12AM. Tuesday: 2 team calls. Backlog trimmed to 15 prioritized items. Buffer time on Friday afternoon.",
            context:   "Sunday evening planning routine",
            category:  .tasks,
            timestamp: Date().addingTimeInterval(-86_400 * 1 - 3_600 * 8)
        ),
        .init(
            action:    "Ordered birthday gift for Sarah",
            detail:    "Mejuri · Delivered Fri · $124",
            expanded:  "Ordered Mejuri Gold Vermeil Sunburst Ring, Size 7. Estimated delivery Friday April 19. Gift message included: 'Happy Birthday, Sarah!' Order #MJR-92847.",
            context:   "Sarah's birthday is Saturday",
            category:  .shopping,
            timestamp: Date().addingTimeInterval(-86_400 * 3)
        ),
        .init(
            action:    "Summarized market research",
            detail:    "42 pages → 5 key insights",
            expanded:  "Condensed Andreessen Horowitz 2025 State of AI report (42 pages) into 5 executive insights. Key finding: enterprise adoption up 3.4× YoY. Full summary saved to Notes.",
            context:   "Prep for your board presentation",
            category:  .research,
            timestamp: Date().addingTimeInterval(-86_400 * 4)
        ),
        .init(
            action:    "Set reminder for dentist",
            detail:    "Dr. Park · Apr 29 · 10:30 AM",
            expanded:  "Reminder added: Dentist appointment, Dr. Park's office, 10:30 AM April 29. 60-minute block. Travel time alert set for 9:45 AM based on your usual commute.",
            context:   nil,
            category:  .tasks,
            timestamp: Date().addingTimeInterval(-86_400 * 5)
        ),
    ]
}

// MARK: - Grouping
struct ActivityGroup: Identifiable {
    let id    : String
    let title : String
    let items : [ActivityItem]
}

extension [ActivityItem] {
    func groupedByDate() -> [ActivityGroup] {
        let cal = Calendar.current
        let now = Date()

        func key(for date: Date) -> String {
            if cal.isDateInToday(date)     { return "TODAY" }
            if cal.isDateInYesterday(date) { return "YESTERDAY" }
            let days = cal.dateComponents([.day], from: date, to: now).day ?? 0
            return days < 7 ? "THIS WEEK" : "EARLIER"
        }

        let grouped = Dictionary(grouping: self) { key(for: $0.timestamp) }
        return ["TODAY", "YESTERDAY", "THIS WEEK", "EARLIER"].compactMap { k in
            guard let items = grouped[k], !items.isEmpty else { return nil }
            return ActivityGroup(
                id: k, title: k,
                items: items.sorted { $0.timestamp > $1.timestamp }
            )
        }
    }
}

// MARK: - Section Header
private struct ActivitySectionHeader: View {
    let title: String

    var body: some View {
        HStack(spacing: SpektTheme.Spacing.md) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.2)
                .foregroundColor(SpektTheme.Colors.textTertiary)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.5)
        }
        .padding(.horizontal, SpektTheme.Spacing.xl)
    }
}

// MARK: - Timeline Dot
/// The node on the timeline spine.
/// Outer ring + inner filled dot. The connecting line runs below when not last.
private struct TimelineDot: View {
    let color: Color
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Dot — aligned with the card title (~24pt from top of row)
            ZStack {
                Circle()
                    .strokeBorder(color.opacity(0.30), lineWidth: 1.0)
                    .frame(width: 14, height: 14)
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
            }
            .padding(.top, 17)

            // Connecting line to the next item
            if !isLast {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.10),
                                Color.white.opacity(0.03),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 1)
            }
        }
        .frame(width: 20)
    }
}

// MARK: - Activity Card
/// Expandable glass card. Collapsed = headline + subtitle.
/// Expanded = full detail + context + timestamp + category badge.
private struct ActivityCard: View {
    let item      : ActivityItem
    let isExpanded: Bool
    let onTap     : () -> Void

    var body: some View {
        GlassCard(
            intensity:    isExpanded ? .regular : .ultraThin,
            cornerRadius: SpektTheme.Radius.md,
            isElevated:   isExpanded
        ) {
            VStack(spacing: 0) {
                headerRow
                    .contentShape(Rectangle())
                    .cardPress()
                    .onTapGesture(perform: onTap)

                if isExpanded {
                    GlassDivider()
                        .padding(.horizontal, SpektTheme.Spacing.md)

                    expandedBody
                        .transition(.cardBodyReveal)
                }
            }
        }
        .animation(SpektTheme.Motion.springDefault, value: isExpanded)
    }

    // ── Header (always visible) ───────────────────────────────────────────
    private var headerRow: some View {
        HStack(alignment: .top, spacing: SpektTheme.Spacing.sm) {
            // Category icon
            Image(systemName: item.category.icon)
                .font(.system(size: 13, weight: .light))
                .foregroundColor(item.category.color)
                .frame(width: 20, height: 20)
                .padding(.top, 1)

            // Title + subtitle
            VStack(alignment: .leading, spacing: 3) {
                Text(item.action)
                    .font(SpektTheme.Typography.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(SpektTheme.Colors.textPrimary)
                    .lineLimit(isExpanded ? 2 : 1)

                Text(item.detail)
                    .font(SpektTheme.Typography.bodySmall)
                    .foregroundColor(SpektTheme.Colors.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: SpektTheme.Spacing.xs)

            // Timestamp
            Text(item.timeAgo)
                .font(SpektTheme.Typography.caption)
                .foregroundColor(SpektTheme.Colors.textTertiary.opacity(0.7))
                .fixedSize()
        }
        .padding(.horizontal, SpektTheme.Spacing.md)
        .padding(.vertical, 13)
    }

    // ── Expanded body ─────────────────────────────────────────────────────
    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: SpektTheme.Spacing.md) {

            // Full detail
            Text(item.expanded)
                .font(SpektTheme.Typography.bodySmall)
                .foregroundColor(SpektTheme.Colors.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            // Context note — the intent behind the action
            if let ctx = item.context {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "lightbulb.min")
                        .font(.system(size: 11, weight: .light))
                        .foregroundColor(SpektTheme.Colors.warning.opacity(0.80))
                        .padding(.top, 1)
                    Text(ctx)
                        .font(SpektTheme.Typography.bodySmall)
                        .foregroundColor(SpektTheme.Colors.textTertiary)
                        .italic()
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, SpektTheme.Spacing.sm)
                .padding(.vertical, SpektTheme.Spacing.sm)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(SpektTheme.Colors.warning.opacity(0.06))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(SpektTheme.Colors.warning.opacity(0.10), lineWidth: 0.5)
                        }
                }
            }

            // Meta row — timestamp + category badge
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .font(.system(size: 10, weight: .light))
                    Text(item.exactTime)
                        .font(SpektTheme.Typography.caption)
                }
                .foregroundColor(SpektTheme.Colors.textTertiary)

                Spacer()

                GlassPillTag(label: item.category.label, dot: item.category.color)
            }
        }
        .padding(.horizontal, SpektTheme.Spacing.md)
        .padding(.top, SpektTheme.Spacing.md)
        .padding(.bottom, SpektTheme.Spacing.md + 2)
    }
}

// MARK: - Timeline Row
/// Composes the TimelineDot + ActivityCard side by side.
/// Animates in with opacity + slide + blur as the row appears.
private struct TimelineRow: View {
    let item      : ActivityItem
    let index     : Int
    let isLast    : Bool
    let isExpanded: Bool
    let onTap     : () -> Void

    @State private var appeared = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            TimelineDot(color: item.category.color, isLast: isLast)

            ActivityCard(item: item, isExpanded: isExpanded, onTap: onTap)
                // Bottom gap between cards (also adds space for the connecting line)
                .padding(.bottom, isLast ? 0 : 10)
        }
        // Scroll-triggered appearance
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .onAppear {
            // LazyVStack fires onAppear as rows enter the viewport.
            // Small per-index delay makes the initial load feel staggered.
            withAnimation(
                SpektTheme.Motion.springDefault.delay(Double(index) * 0.055)
            ) {
                appeared = true
            }
        }
    }
}

// MARK: - Compact Task Card
/// Inline task card shown in the Activity feed's Tasks panel.
private struct CompactTaskCard: View {
    let task    : SpektTask
    let onToggle: () -> Void

    @State private var appeared = false

    var body: some View {
        GlassCard(intensity: .thin, cornerRadius: SpektTheme.Radius.md) {
            HStack(spacing: 12) {
                // Left priority stripe
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(task.priority.color)
                    .frame(width: 3)
                    .padding(.vertical, 4)

                // Checkbox
                TaskCheckbox(
                    isCompleted: task.isCompleted,
                    priority: task.priority,
                    onToggle: onToggle
                )

                // Title + detail
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(SpektTheme.Typography.bodySmall)
                        .foregroundColor(SpektTheme.Colors.textPrimary)
                        .lineLimit(1)
                        .strikethrough(task.isCompleted)
                    if let detail = task.detail {
                        Text(detail)
                            .font(SpektTheme.Typography.caption)
                            .foregroundColor(SpektTheme.Colors.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                // Deadline badge
                if let label = task.deadlineDisplay {
                    Text(label)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(task.deadlineColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background {
                            Capsule()
                                .fill(task.deadlineColor.opacity(0.12))
                                .overlay(Capsule().strokeBorder(task.deadlineColor.opacity(0.22), lineWidth: 0.5))
                        }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .cardPress()
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(SpektTheme.Motion.springDefault) { appeared = true }
        }
    }
}

// MARK: - Activity View
struct ActivityView: View {
    @State private var expandedID   : UUID?  = nil
    @State private var headerVisible          = false
    @State private var statsVisible           = false
    @State private var searchQuery  : String  = ""
    @State private var showTasksView          = false

    // Live items — empty until real calls produce results
    @State private var liveItems: [ActivityItem] = []
    @ObservedObject private var taskService = TaskService.shared

    private var filtered: [ActivityItem] {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            return liveItems
        }
        let q = searchQuery.lowercased()
        return liveItems.filter {
            $0.action.lowercased().contains(q)   ||
            $0.detail.lowercased().contains(q)   ||
            $0.expanded.lowercased().contains(q) ||
            $0.category.label.lowercased().contains(q)
        }
    }
    private var groups     : [ActivityGroup] { filtered.groupedByDate() }
    private var totalCount : Int             { liveItems.count }

    var body: some View {
        ZStack {
            SpektTheme.Colors.base.ignoresSafeArea()

            // Background dim when a card is expanded
            if expandedID != nil {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .animation(SpektTheme.Motion.springDefault, value: expandedID)
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // ── Header ─────────────────────────────────────────────
                    headerSection
                        .padding(.horizontal, SpektTheme.Spacing.xl)
                        .padding(.top, SpektTheme.Spacing.xl)
                        .opacity(headerVisible ? 1 : 0)
                        .offset(y: headerVisible ? 0 : -10)

                    // ── Search ─────────────────────────────────────────────
                    HStack(spacing: SpektTheme.Spacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(SpektTheme.Colors.textTertiary)
                        TextField("Search outcomes…", text: $searchQuery)
                            .font(SpektTheme.Typography.bodySmall)
                            .foregroundColor(SpektTheme.Colors.textPrimary)
                            .tint(SpektTheme.Colors.accent)
                        if !searchQuery.isEmpty {
                            Button {
                                withAnimation(SpektTheme.Motion.springSnappy) { searchQuery = "" }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(SpektTheme.Colors.textTertiary)
                            }
                            .buttonStyle(.plain)
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
                    .padding(.horizontal, SpektTheme.Spacing.xl)
                    .padding(.top, SpektTheme.Spacing.md)
                    .opacity(headerVisible ? 1 : 0)
                    .animation(SpektTheme.Motion.springSnappy, value: searchQuery.isEmpty)

                    // ── Pending Tasks Panel ────────────────────────────────
                    if !taskService.pendingTasks.isEmpty && searchQuery.isEmpty {
                        pendingTasksPanel
                            .padding(.top, SpektTheme.Spacing.md)
                    }

                    // ── Empty states ───────────────────────────────────────
                    if liveItems.isEmpty && searchQuery.isEmpty {
                        // No calls made yet
                        VStack(spacing: 12) {
                            Image(systemName: "waveform.path")
                                .font(.system(size: 32, weight: .ultraLight))
                                .foregroundColor(SpektTheme.Colors.textTertiary.opacity(0.45))
                            Text("No activity yet.")
                                .font(SpektTheme.Typography.bodyMedium)
                                .foregroundColor(SpektTheme.Colors.textSecondary)
                            Text("Outcomes from your calls will appear here.")
                                .font(SpektTheme.Typography.bodySmall)
                                .foregroundColor(SpektTheme.Colors.textTertiary.opacity(0.65))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, SpektTheme.Spacing.xxl)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 72)
                        .transition(.opacity)
                    } else if groups.isEmpty && !searchQuery.isEmpty {
                        // Search returned nothing
                        VStack(spacing: SpektTheme.Spacing.sm) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 28, weight: .ultraLight))
                                .foregroundColor(SpektTheme.Colors.textTertiary)
                            Text("No outcomes match \"\(searchQuery)\"")
                                .font(SpektTheme.Typography.bodySmall)
                                .foregroundColor(SpektTheme.Colors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                        .transition(.opacity)
                    }

                    // ── Timeline groups ────────────────────────────────────
                    ForEach(groups) { group in
                        ActivitySectionHeader(title: group.title)
                            .padding(.top, 28)
                            .padding(.bottom, 14)

                        LazyVStack(spacing: 0, pinnedViews: []) {
                            ForEach(Array(group.items.enumerated()), id: \.element.id) { i, item in
                                TimelineRow(
                                    item:       item,
                                    index:      i,
                                    isLast:     i == group.items.count - 1,
                                    isExpanded: expandedID == item.id
                                ) {
                                    withAnimation(SpektTheme.Motion.springDefault) {
                                        expandedID = expandedID == item.id ? nil : item.id
                                    }
                                    #if os(iOS)
                                    HapticEngine.selection()
                                    #endif
                                }
                            }
                        }
                        .padding(.horizontal, SpektTheme.Spacing.xl)
                    }

                    Spacer(minLength: 120)
                }
            }
        }
        .onAppear { staggerIn() }
        // Receive new call results and prepend as an activity item
        .onReceive(NotificationCenter.default.publisher(for: .spektNewCallResults)) { notification in
            guard let results = notification.object as? CallSessionResults else { return }

            // Headline: first key outcome if available, else trimmed summary
            let headline: String = {
                if let first = results.keyOutcomes.first {
                    return String(first.prefix(80))
                }
                return String(results.summary.prefix(72))
            }()

            // Detail line: task + memory counts
            let detailParts = [
                results.tasks.count    > 0 ? "\(results.tasks.count) task\(results.tasks.count == 1 ? "" : "s")"       : nil,
                results.memories.count > 0 ? "\(results.memories.count) memor\(results.memories.count == 1 ? "y" : "ies")" : nil,
            ].compactMap { $0 }
            let detail = detailParts.isEmpty ? "Call processed" : detailParts.joined(separator: " · ")

            // Expanded body: full summary + all key outcomes
            var expandedParts = [results.summary]
            if !results.keyOutcomes.isEmpty {
                expandedParts.append("\nKey outcomes:\n" + results.keyOutcomes.map { "• \($0)" }.joined(separator: "\n"))
            }

            let newItem = ActivityItem(
                action:    headline,
                detail:    detail,
                expanded:  expandedParts.joined(separator: "\n"),
                context:   results.keyOutcomes.count > 1 ? results.keyOutcomes.dropFirst().first : nil,
                category:  results.tasks.count > 0 ? .tasks : .research,
                timestamp: Date()
            )
            withAnimation(SpektTheme.Motion.springDefault) {
                liveItems.insert(newItem, at: 0)
            }
            #if os(iOS)
            HapticEngine.notify(.success)
            #endif
        }
    }

    // MARK: Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SpektTheme.Spacing.sm) {
            Text("Activity")
                .font(SpektTheme.Typography.displayMedium)
                .foregroundColor(SpektTheme.Colors.textPrimary)

            if statsVisible {
                HStack(spacing: SpektTheme.Spacing.sm) {
                    GlassPillTag(
                        label: "\(totalCount) outcomes",
                        color: SpektTheme.Colors.textTertiary
                    )
                    GlassPillTag(
                        label: "This week",
                        dot:   SpektTheme.Colors.accent
                    )
                }
                .transition(.fadeDrift)
            }
        }
    }

    private func staggerIn() {
        withAnimation(SpektTheme.Motion.springDefault.delay(0.05)) { headerVisible = true }
        withAnimation(SpektTheme.Motion.springDefault.delay(0.22)) { statsVisible  = true }
    }

    // MARK: - Pending Tasks Panel

    private var pendingTasksPanel: some View {
        VStack(spacing: 0) {
            // Section header
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    Text("TASKS")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.8)
                        .foregroundColor(SpektTheme.Colors.textTertiary)

                    // Overdue badge
                    if taskService.overdueCount > 0 {
                        Text("\(taskService.overdueCount) overdue")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(SpektTheme.Colors.destructive)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background {
                                Capsule().fill(SpektTheme.Colors.destructive.opacity(0.12))
                            }
                    }
                }
                Spacer()
                Button {
                    #if os(iOS)
                    HapticEngine.selection()
                    #endif
                    showTasksView = true
                } label: {
                    HStack(spacing: 3) {
                        Text("See all \(taskService.pendingTasks.count)")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(SpektTheme.Colors.accent)
                }
                .buttonStyle(PressableButtonStyle(scale: 0.92))
            }
            .padding(.horizontal, SpektTheme.Spacing.xl)
            .padding(.bottom, 10)

            // Compact task cards (max 3)
            VStack(spacing: SpektTheme.Spacing.sm) {
                ForEach(taskService.pendingTasks.prefix(3)) { task in
                    CompactTaskCard(task: task) {
                        taskService.toggleComplete(id: task.id)
                    }
                }
            }
            .padding(.horizontal, SpektTheme.Spacing.xl)
        }
        .sheet(isPresented: $showTasksView) {
            TasksView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(SpektTheme.Colors.base)
                .presentationCornerRadius(SpektTheme.Radius.xl)
        }
    }
}

// MARK: - Preview
#Preview {
    ActivityView()
        .preferredColorScheme(.dark)
}
