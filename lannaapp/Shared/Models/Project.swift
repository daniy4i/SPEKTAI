//
//  Project.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 8/31/25.
//

import Foundation
import FirebaseFirestore

struct Project: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var createdAt: Date
    var updatedAt: Date
    var ownerUid: String
    var type: ProjectType
    var status: ProjectStatus
    var coverImage: String?
    var activeConversationId: String?
    var conversationsCount: Int
    var isPinned: Bool
    
    // MARK: - Hashable Implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Project, rhs: Project) -> Bool {
        return lhs.id == rhs.id
    }
    
    enum ProjectType: String, Codable, CaseIterable {
        case story = "story"
        case script = "script"
        case animation = "animation"
        case general = "general"
        
        var displayName: String {
            switch self {
            case .story: return "Story"
            case .script: return "Script"
            case .animation: return "Animation"
            case .general: return "General"
            }
        }
        
        var systemImage: String {
            switch self {
            case .story: return "book.closed"
            case .script: return "doc.text"
            case .animation: return "play.rectangle"
            case .general: return "folder"
            }
        }
    }
    
    enum ProjectStatus: String, Codable, CaseIterable {
        case draft = "draft"
        case inProgress = "in_progress"
        case completed = "completed"
        case archived = "archived"
        
        var displayName: String {
            switch self {
            case .draft: return "Draft"
            case .inProgress: return "In Progress"
            case .completed: return "Completed"
            case .archived: return "Archived"
            }
        }
        
        var color: String {
            switch self {
            case .draft: return "gray"
            case .inProgress: return "blue"
            case .completed: return "green"
            case .archived: return "orange"
            }
        }
    }
}

extension Project {
    static let mockProjects = [
        Project(
            id: "1",
            title: "The Lost Chronicles",
            description: "An epic fantasy adventure about a young mage discovering ancient secrets.",
            createdAt: Date().addingTimeInterval(-86400 * 7),
            updatedAt: Date().addingTimeInterval(-3600),
            ownerUid: "user1",
            type: .story,
            status: .inProgress,
            coverImage: nil,
            activeConversationId: "conv1",
            conversationsCount: 3,
            isPinned: true
        ),
        Project(
            id: "2",
            title: "Midnight Café",
            description: "A romantic comedy screenplay set in a 24-hour coffee shop.",
            createdAt: Date().addingTimeInterval(-86400 * 3),
            updatedAt: Date().addingTimeInterval(-1800),
            ownerUid: "user1",
            type: .script,
            status: .draft,
            coverImage: nil,
            activeConversationId: nil,
            conversationsCount: 0,
            isPinned: false
        ),
        Project(
            id: "3",
            title: "Space Explorer",
            description: "Animated short film about a curious robot exploring distant planets.",
            createdAt: Date().addingTimeInterval(-86400 * 14),
            updatedAt: Date().addingTimeInterval(-86400 * 2),
            ownerUid: "user1",
            type: .animation,
            status: .completed,
            coverImage: nil,
            activeConversationId: "conv3",
            conversationsCount: 1,
            isPinned: false
        )
    ]
}