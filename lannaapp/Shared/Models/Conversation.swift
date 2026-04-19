//
//  Conversation.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 8/31/25.
//

import Foundation
import FirebaseFirestore

struct Conversation: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var userId: String
    var projectId: String?
    var projectName: String?
    var lastMessage: String
    var lastMessageAt: Date
    var lastMessageTime: Date
    var messagesCount: Int
    var updatedAt: Date
    var createdAt: Date
    var sharedContext: String?
    var sharedDocuments: [SharedDocument]?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        return lhs.id == rhs.id
    }
}

struct Message: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var content: String
    var role: MessageRole
    var createdAt: Date
    var userId: String
    var conversationId: String
    var metadata: MessageMetadata?
    
    enum MessageRole: String, Codable, CaseIterable {
        case user = "user"
        case assistant = "assistant"
        case system = "system"
        
        var displayName: String {
            switch self {
            case .user: return "You"
            case .assistant: return "Lanna AI"
            case .system: return "System"
            }
        }
        
        var isFromUser: Bool {
            return self == .user
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Message, rhs: Message) -> Bool {
        return lhs.id == rhs.id
    }
}

struct MessageMetadata: Codable {
    var tokenCount: Int?
    var processingTime: Double?
    var model: String?
    var temperature: Double?
    var attachments: [String]?
    var audioURL: String?
    var audioDuration: Double?
    var audioStoragePath: String?
    var videoURL: String?
    var videoDuration: Double?
    var videoStoragePath: String?
    var videoThumbnailURL: String?
    var videoThumbnailStoragePath: String?
}

struct SharedDocument: Identifiable, Codable {
    let id: String
    let name: String
    let url: String
    let type: String
    let uploadedAt: Date
}

extension Conversation {
    static let mockConversations = [
        Conversation(
            id: "1",
            userId: "user1",
            projectId: "project1",
            projectName: "The Lost Chronicles",
            lastMessage: "Can you help me develop the main character's backstory?",
            lastMessageAt: Date().addingTimeInterval(-3600),
            lastMessageTime: Date().addingTimeInterval(-3600),
            messagesCount: 12,
            updatedAt: Date().addingTimeInterval(-3600),
            createdAt: Date().addingTimeInterval(-86400 * 2),
            sharedContext: "This is a fantasy novel about a young mage discovering their powers in a world where magic is forbidden.",
            sharedDocuments: []
        ),
        Conversation(
            id: "2",
            userId: "user1",
            projectId: "project2",
            projectName: "Midnight Café",
            lastMessage: "What's a good opening scene for a romantic comedy?",
            lastMessageAt: Date().addingTimeInterval(-7200),
            lastMessageTime: Date().addingTimeInterval(-7200),
            messagesCount: 8,
            updatedAt: Date().addingTimeInterval(-7200),
            createdAt: Date().addingTimeInterval(-86400),
            sharedContext: nil,
            sharedDocuments: nil
        )
    ]
}

extension Message {
    static let mockMessages = [
        Message(
            id: "1",
            content: "Can you help me develop the main character's backstory?",
            role: .user,
            createdAt: Date().addingTimeInterval(-3600),
            userId: "user1",
            conversationId: "1"
        ),
        Message(
            id: "2",
            content: "I'd be happy to help you develop your main character's backstory! Let's start with some key questions about your character...",
            role: .assistant,
            createdAt: Date().addingTimeInterval(-3500),
            userId: "user1",
            conversationId: "1",
            metadata: MessageMetadata(
                tokenCount: 150,
                processingTime: 2.3,
                model: "gpt-4",
                temperature: 0.7
            )
        )
    ]
}
