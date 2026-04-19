//
//  AdrianaNotification.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 10/1/25.
//

import Foundation

// MARK: - Notification Types

enum AdrianaNotificationType: String, CaseIterable, Codable {
    case morningBrief = "morning_brief"
    case preMeetingPrep = "pre_meeting_prep"
    case timeToLeave = "time_to_leave"
    case focusAndBreak = "focus_and_break"
    case endOfDayRecap = "end_of_day_recap"

    var displayName: String {
        switch self {
        case .morningBrief:
            return "Morning Brief"
        case .preMeetingPrep:
            return "Pre-Meeting Prep"
        case .timeToLeave:
            return "Time-to-Leave"
        case .focusAndBreak:
            return "Focus & Break Nudges"
        case .endOfDayRecap:
            return "End-of-Day Recap"
        }
    }

    var emoji: String {
        switch self {
        case .morningBrief:
            return "🌅"
        case .preMeetingPrep:
            return "📑"
        case .timeToLeave:
            return "🚗"
        case .focusAndBreak:
            return "⏱️"
        case .endOfDayRecap:
            return "🌙"
        }
    }

    var description: String {
        switch self {
        case .morningBrief:
            return "Short daily summary (today's meetings, weather, headlines, affirmation)"
        case .preMeetingPrep:
            return "30-60 min before events: attendees, agenda, directions, key notes"
        case .timeToLeave:
            return "Travel-time + weather + buffer reminder for on-time arrival"
        case .focusAndBreak:
            return "Gentle reminders for deep work sessions and breaks"
        case .endOfDayRecap:
            return "Brief reflection: completed tasks, meetings summary, tomorrow's items"
        }
    }

    var defaultTime: String {
        switch self {
        case .morningBrief:
            return "07:30"
        case .preMeetingPrep:
            return "00:45" // 45 minutes before
        case .timeToLeave:
            return "00:15" // 15 minutes buffer
        case .focusAndBreak:
            return "00:25" // 25 minute Pomodoro
        case .endOfDayRecap:
            return "18:30"
        }
    }
}

// MARK: - Notification Settings Model

struct AdrianaNotificationSettings: Codable, Identifiable {
    var id: String { type.rawValue }
    let type: AdrianaNotificationType
    var isEnabled: Bool
    var scheduledTime: String? // HH:mm format for time-based notifications
    var leadTimeMinutes: Int? // Minutes before event for event-based notifications
    var intervalMinutes: Int? // For recurring notifications like focus nudges
    var lastSyncedAt: Date?
    var updatedAt: Date
    var createdAt: Date

    init(
        type: AdrianaNotificationType,
        isEnabled: Bool = false,
        scheduledTime: String? = nil,
        leadTimeMinutes: Int? = nil,
        intervalMinutes: Int? = nil,
        lastSyncedAt: Date? = nil,
        updatedAt: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.type = type
        self.isEnabled = isEnabled
        self.scheduledTime = scheduledTime ?? (type.requiresScheduledTime ? type.defaultTime : nil)
        self.leadTimeMinutes = leadTimeMinutes ?? (type.requiresLeadTime ? Int(type.defaultTime.split(separator: ":").last!)! : nil)
        self.intervalMinutes = intervalMinutes ?? (type.requiresInterval ? 25 : nil)
        self.lastSyncedAt = lastSyncedAt
        self.updatedAt = updatedAt
        self.createdAt = createdAt
    }
}

// MARK: - Notification Type Extensions

extension AdrianaNotificationType {
    var requiresScheduledTime: Bool {
        switch self {
        case .morningBrief, .endOfDayRecap:
            return true
        case .preMeetingPrep, .timeToLeave, .focusAndBreak:
            return false
        }
    }

    var requiresLeadTime: Bool {
        switch self {
        case .preMeetingPrep, .timeToLeave:
            return true
        case .morningBrief, .focusAndBreak, .endOfDayRecap:
            return false
        }
    }

    var requiresInterval: Bool {
        switch self {
        case .focusAndBreak:
            return true
        case .morningBrief, .preMeetingPrep, .timeToLeave, .endOfDayRecap:
            return false
        }
    }

    var isEventBased: Bool {
        switch self {
        case .preMeetingPrep, .timeToLeave:
            return true
        case .morningBrief, .focusAndBreak, .endOfDayRecap:
            return false
        }
    }
}

// MARK: - Firebase Mappings

extension AdrianaNotificationSettings {
    func toFirebaseDict() -> [String: Any] {
        var dict: [String: Any] = [
            "type": type.rawValue,
            "isEnabled": isEnabled,
            "updatedAt": updatedAt.timeIntervalSince1970,
            "createdAt": createdAt.timeIntervalSince1970
        ]

        if let scheduledTime = scheduledTime {
            dict["scheduledTime"] = scheduledTime
        }
        if let leadTimeMinutes = leadTimeMinutes {
            dict["leadTimeMinutes"] = leadTimeMinutes
        }
        if let intervalMinutes = intervalMinutes {
            dict["intervalMinutes"] = intervalMinutes
        }
        if let lastSyncedAt = lastSyncedAt {
            dict["lastSyncedAt"] = lastSyncedAt.timeIntervalSince1970
        }

        return dict
    }

    static func fromFirebaseDict(_ dict: [String: Any]) -> AdrianaNotificationSettings? {
        guard let typeString = dict["type"] as? String,
              let type = AdrianaNotificationType(rawValue: typeString),
              let isEnabled = dict["isEnabled"] as? Bool else {
            return nil
        }

        let scheduledTime = dict["scheduledTime"] as? String
        let leadTimeMinutes = dict["leadTimeMinutes"] as? Int
        let intervalMinutes = dict["intervalMinutes"] as? Int

        let updatedAtTimestamp = dict["updatedAt"] as? Double ?? Date().timeIntervalSince1970
        let createdAtTimestamp = dict["createdAt"] as? Double ?? Date().timeIntervalSince1970
        let lastSyncedAtTimestamp = dict["lastSyncedAt"] as? Double

        return AdrianaNotificationSettings(
            type: type,
            isEnabled: isEnabled,
            scheduledTime: scheduledTime,
            leadTimeMinutes: leadTimeMinutes,
            intervalMinutes: intervalMinutes,
            lastSyncedAt: lastSyncedAtTimestamp != nil ? Date(timeIntervalSince1970: lastSyncedAtTimestamp!) : nil,
            updatedAt: Date(timeIntervalSince1970: updatedAtTimestamp),
            createdAt: Date(timeIntervalSince1970: createdAtTimestamp)
        )
    }
}
