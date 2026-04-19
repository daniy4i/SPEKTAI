//
//  SpektModels.swift
//  lannaapp
//
//  Data models for SPEKT AI backend integration.
//  Codable for JSON serialization / deserialization.
//

import Foundation

// MARK: - Memory

struct SpektMemory: Identifiable, Codable, Equatable {
    let id: String
    var content: String
    var timestamp: Date
    var isPinned: Bool

    enum CodingKeys: String, CodingKey {
        case id, content, timestamp
        case isPinned = "is_pinned"
    }
}

extension SpektMemory {
    static let mocks: [SpektMemory] = [
        SpektMemory(
            id: "m1",
            content: "Prefers morning calls before 10 AM",
            timestamp: Date().addingTimeInterval(-3_600 * 2),
            isPinned: true
        ),
        SpektMemory(
            id: "m2",
            content: "Works with design team on Tuesdays and Thursdays",
            timestamp: Date().addingTimeInterval(-3_600 * 26),
            isPinned: false
        ),
        SpektMemory(
            id: "m3",
            content: "Traveling to Miami in late March",
            timestamp: Date().addingTimeInterval(-3_600 * 50),
            isPinned: false
        ),
        SpektMemory(
            id: "m4",
            content: "Prefers bullet point summaries over prose",
            timestamp: Date().addingTimeInterval(-3_600 * 72),
            isPinned: true
        ),
        SpektMemory(
            id: "m5",
            content: "Team: Alex (design), Jordan (eng), Sam (PM)",
            timestamp: Date().addingTimeInterval(-3_600 * 96),
            isPinned: false
        ),
        SpektMemory(
            id: "m6",
            content: "Prefers restaurants in SoHo for client dinners",
            timestamp: Date().addingTimeInterval(-3_600 * 144),
            isPinned: false
        ),
    ]
}

// MARK: - Usage Patterns

struct UsagePattern: Codable {
    var sessionsThisWeek: Int
    var avgSessionMinutes: Double
    var peakMorning: String
    var peakAfternoon: String
    var hourlyActivity: [Double]   // 24 values, each 0.0–1.0
    var categories: [CategoryUsage]

    enum CodingKeys: String, CodingKey {
        case sessionsThisWeek   = "sessions_this_week"
        case avgSessionMinutes  = "avg_session_minutes"
        case peakMorning        = "peak_morning"
        case peakAfternoon      = "peak_afternoon"
        case hourlyActivity     = "hourly_activity"
        case categories
    }

    static let mock = UsagePattern(
        sessionsThisWeek: 14,
        avgSessionMinutes: 4.2,
        peakMorning: "8–10 AM",
        peakAfternoon: "2–4 PM",
        hourlyActivity: [
            0.05, 0.03, 0.02, 0.02, 0.04, 0.10,
            0.22, 0.45, 0.75, 0.92, 0.80, 0.60,
            0.50, 0.40, 0.55, 0.88, 0.70, 0.45,
            0.30, 0.20, 0.15, 0.10, 0.07, 0.05,
        ],
        categories: [
            CategoryUsage(name: "Planning",    count: 28, fraction: 0.32),
            CategoryUsage(name: "Scheduling",  count: 19, fraction: 0.22),
            CategoryUsage(name: "Research",    count: 16, fraction: 0.18),
            CategoryUsage(name: "Analysis",    count: 14, fraction: 0.16),
            CategoryUsage(name: "Drafting",    count: 10, fraction: 0.12),
        ]
    )
}

struct CategoryUsage: Codable, Identifiable {
    var id: String { name }
    let name: String
    let count: Int
    let fraction: Double
}

// MARK: - API Request / Response

struct AddMemoryRequest: Codable {
    let content: String
}

struct PreferencesPayload: Codable {
    let voiceTone: String
    let style: String
    let format: String
    let language: String
    let detailLevel: String

    enum CodingKeys: String, CodingKey {
        case voiceTone   = "voice_tone"
        case style, format, language
        case detailLevel = "detail_level"
    }
}
