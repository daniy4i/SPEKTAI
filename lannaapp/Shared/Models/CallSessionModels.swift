//
//  CallSessionModels.swift
//  lannaapp
//
//  Data models for the SPEKT AI call pipeline.
//  Mirrors the JSON shapes returned by spekt-backend.
//

import Foundation

// MARK: - Session Status

enum CallSessionStatus: String, Codable, Equatable {
    case pending
    case inCall          = "in_call"
    case processing
    case transcribing
    case extracting
    case ready
    case failed

    /// Human-readable label shown in ProcessingView
    var displayText: String {
        switch self {
        case .pending:       return "Waiting for call…"
        case .inCall:        return "Call in progress…"
        case .processing:    return "Processing your call…"
        case .transcribing:  return "Transcribing conversation…"
        case .extracting:    return "Extracting insights…"
        case .ready:         return "Results ready."
        case .failed:        return "Something went wrong."
        }
    }

    var isTerminal: Bool { self == .ready || self == .failed }

    /// 0.0 – 1.0 progress fraction for the progress bar
    var progressFraction: Double {
        switch self {
        case .pending:      return 0.05
        case .inCall:       return 0.15
        case .processing:   return 0.35
        case .transcribing: return 0.55
        case .extracting:   return 0.78
        case .ready:        return 1.00
        case .failed:       return 1.00
        }
    }
}

// MARK: - Session Status Response (from GET /api/sessions/:id/status)

struct CallSessionStatusResponse: Decodable {
    let sessionId: String
    let status   : CallSessionStatus
    let progress : String?
    let results  : CallSessionResults?
    let error    : String?

    enum CodingKeys: String, CodingKey {
        case sessionId, status, progress, results, error
    }
}

// MARK: - Session Results

struct CallSessionResults: Decodable {
    let transcript         : String
    let summary            : String
    let keyOutcomes        : [String]                   // mapped from "key_outcomes"
    let tasks              : [ExtractedTask]
    let memories           : [ExtractedMemory]
    let preferencesUpdates : [ExtractedPreferenceUpdate]
    let processedAt        : String

    // Custom decoder so keyOutcomes can fall back to [] on older backend responses.
    private enum CodingKeys: String, CodingKey {
        case transcript, summary, tasks, memories, processedAt
        case keyOutcomes        = "key_outcomes"
        case preferencesUpdates = "preferences_updates"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        transcript          = try  c.decode(String.self,                               forKey: .transcript)
        summary             = try  c.decode(String.self,                               forKey: .summary)
        keyOutcomes         = (try? c.decode([String].self,                            forKey: .keyOutcomes))         ?? []
        tasks               = (try? c.decode([ExtractedTask].self,                     forKey: .tasks))               ?? []
        memories            = (try? c.decode([ExtractedMemory].self,                   forKey: .memories))            ?? []
        preferencesUpdates  = (try? c.decode([ExtractedPreferenceUpdate].self,         forKey: .preferencesUpdates))  ?? []
        processedAt         = (try? c.decode(String.self,                              forKey: .processedAt))         ?? ""
    }
}

// MARK: - Extracted Task

struct ExtractedTask: Decodable, Identifiable {
    let id      : String
    let title   : String
    let detail  : String?
    let dueDate : String?   // JSON key is "deadline" — see CodingKeys below
    let priority: String    // "high" | "medium" | "low"

    // The backend stores the date as "deadline" (from the intelligence prompt).
    // "dueDate" / "due_date" would never match — explicit mapping required.
    private enum CodingKeys: String, CodingKey {
        case id, title, detail, priority
        case dueDate = "deadline"
    }

    var priorityColor: String {
        switch priority {
        case "high":   return "destructive"
        case "medium": return "warning"
        default:       return "positive"
        }
    }
}

// MARK: - Extracted Memory

struct ExtractedMemory: Decodable, Identifiable {
    let id     : String
    let content: String
}

// MARK: - Extracted Preference Update

struct ExtractedPreferenceUpdate: Decodable {
    let field : String
    let value : String
    let reason: String?
}

// MARK: - Initiate Response (from POST /api/sessions/initiate)

struct InitiateSessionResponse: Decodable {
    let sessionId  : String
    let phoneNumber: String
    let expiresIn  : Int
}
