//
//  TaskModels.swift
//  lannaapp
//
//  Task data model for the SPEKT AI task intelligence layer.
//  Mirrors the backend task shape; Codable for REST round-trips.
//

import SwiftUI

// MARK: - Enums

enum TaskStatus: String, Codable, Equatable, CaseIterable {
    case pending
    case completed
    case dismissed

    var label: String {
        switch self {
        case .pending:   return "Pending"
        case .completed: return "Done"
        case .dismissed: return "Dismissed"
        }
    }
}

enum TaskPriority: String, Codable, Equatable, CaseIterable {
    case high
    case medium
    case low

    var label: String {
        switch self {
        case .high:   return "High"
        case .medium: return "Medium"
        case .low:    return "Low"
        }
    }

    var color: Color {
        switch self {
        case .high:   return SpektTheme.Colors.destructive
        case .medium: return SpektTheme.Colors.warning
        case .low:    return SpektTheme.Colors.positive
        }
    }

    var icon: String {
        switch self {
        case .high:   return "exclamationmark.circle.fill"
        case .medium: return "minus.circle.fill"
        case .low:    return "arrow.down.circle.fill"
        }
    }
}

// MARK: - Task Model

struct SpektTask: Identifiable, Codable, Equatable {
    let id             : String
    var title          : String
    var detail         : String?
    var deadline       : String?     // "YYYY-MM-DD" — date-only for display simplicity
    var status         : TaskStatus
    var priority       : TaskPriority
    var sourceSessionId: String?
    let createdAt      : String      // ISO datetime

    // MARK: - Computed

    var isCompleted: Bool { status == .completed }

    var deadlineDate: Date? {
        guard let d = deadline else { return nil }
        return ISO8601DateFormatter.dateOnly.date(from: d)
    }

    var isOverdue: Bool {
        guard let date = deadlineDate, status == .pending else { return false }
        return date < Calendar.current.startOfDay(for: Date())
    }

    var isDueToday: Bool {
        guard let date = deadlineDate else { return false }
        return Calendar.current.isDateInToday(date)
    }

    var isDueThisWeek: Bool {
        guard let date = deadlineDate, !isDueToday, !isOverdue else { return false }
        let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return date <= weekFromNow
    }

    var deadlineDisplay: String? {
        guard let date = deadlineDate else { return nil }
        if isOverdue    { return "Overdue" }
        if isDueToday   { return "Today" }
        let f = DateFormatter()
        f.dateFormat = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
            ? "MMM d"
            : "MMM d, yyyy"
        return f.string(from: date)
    }

    var deadlineColor: Color {
        if isOverdue  { return SpektTheme.Colors.destructive }
        if isDueToday { return SpektTheme.Colors.warning }
        return SpektTheme.Colors.textTertiary
    }
}

// MARK: - Mock Data

extension SpektTask {
    static let mocks: [SpektTask] = [
        SpektTask(
            id:          "demo1",
            title:       "Book dinner at Nobu",
            detail:      "Saturday evening, 2 guests",
            deadline:    ISO8601DateFormatter.dateOnly.string(from: Calendar.current.date(byAdding: .day, value: 1, to: Date())!),
            status:      .pending,
            priority:    .high,
            sourceSessionId: nil,
            createdAt:   ISO8601DateFormatter().string(from: Date())
        ),
        SpektTask(
            id:          "demo2",
            title:       "Send proposal to design team",
            detail:      "Q2 roadmap deck with updated timeline",
            deadline:    ISO8601DateFormatter.dateOnly.string(from: Calendar.current.date(byAdding: .day, value: 3, to: Date())!),
            status:      .pending,
            priority:    .medium,
            sourceSessionId: nil,
            createdAt:   ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        ),
        SpektTask(
            id:          "demo3",
            title:       "Research Miami hotels",
            detail:      "For the late March trip, near South Beach",
            deadline:    nil,
            status:      .pending,
            priority:    .low,
            sourceSessionId: nil,
            createdAt:   ISO8601DateFormatter().string(from: Date().addingTimeInterval(-7200))
        ),
        SpektTask(
            id:          "demo4",
            title:       "Call Alex about Q2 strategy",
            detail:      "Following up on Monday's meeting",
            deadline:    ISO8601DateFormatter.dateOnly.string(from: Date()),
            status:      .pending,
            priority:    .high,
            sourceSessionId: nil,
            createdAt:   ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400))
        ),
        SpektTask(
            id:          "demo5",
            title:       "Order birthday gift for Sarah",
            detail:      "Delivered by Friday",
            deadline:    nil,
            status:      .completed,
            priority:    .medium,
            sourceSessionId: nil,
            createdAt:   ISO8601DateFormatter().string(from: Date().addingTimeInterval(-172800))
        ),
    ]
}

// MARK: - Grouping

enum TaskGroup: String, CaseIterable {
    case overdue    = "OVERDUE"
    case today      = "TODAY"
    case thisWeek   = "THIS WEEK"
    case later      = "LATER"
    case completed  = "COMPLETED"

    var accentColor: Color {
        switch self {
        case .overdue:   return SpektTheme.Colors.destructive
        case .today:     return SpektTheme.Colors.warning
        case .thisWeek:  return SpektTheme.Colors.accent
        case .later:     return SpektTheme.Colors.textSecondary
        case .completed: return SpektTheme.Colors.positive
        }
    }
}

struct TaskSection: Identifiable {
    let id   : TaskGroup
    var tasks: [SpektTask]

    var title: String { id.rawValue }
    var color: Color  { id.accentColor }
}

extension Array where Element == SpektTask {
    func grouped() -> [TaskSection] {
        var overdue  : [SpektTask] = []
        var today    : [SpektTask] = []
        var thisWeek : [SpektTask] = []
        var later    : [SpektTask] = []
        var completed: [SpektTask] = []

        for task in self {
            switch task.status {
            case .completed, .dismissed:
                completed.append(task)
            case .pending:
                if task.isOverdue          { overdue.append(task)  }
                else if task.isDueToday    { today.append(task)    }
                else if task.isDueThisWeek { thisWeek.append(task) }
                else                       { later.append(task)    }
            }
        }

        return [
            TaskSection(id: .overdue,   tasks: overdue),
            TaskSection(id: .today,     tasks: today),
            TaskSection(id: .thisWeek,  tasks: thisWeek),
            TaskSection(id: .later,     tasks: later),
            TaskSection(id: .completed, tasks: completed.prefix(10).map { $0 }),
        ].filter { !$0.tasks.isEmpty }
    }
}

// MARK: - Date Formatter Helper

extension ISO8601DateFormatter {
    static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
