import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class FirestoreService: ObservableObject {
    private let db = Firestore.firestore()
    
    // MARK: - Save Message
    func saveMessage(_ message: Any, to conversationId: String) async throws {
        // Firebase temporarily disabled
        return
        
        /*
        var messageData: [String: Any] = [
            "content": message.text,
            "role": message.isFromUser ? "user" : "assistant",
            "timestamp": message.timestamp,
            "userId": userId
        ]
        
        // Add media attachments if present
        if !message.mediaAttachments.isEmpty {
            let mediaData = message.mediaAttachments.map { attachment in
                return [
                    "id": attachment.id.uuidString,
                    "type": attachment.type.rawValue,
                    "url": attachment.url,
                    "thumbnailUrl": attachment.thumbnailUrl as Any,
                    "width": attachment.width as Any,
                    "height": attachment.height as Any,
                    "duration": attachment.duration as Any,
                    "mimeType": attachment.mimeType as Any,
                    "storageRef": attachment.storageRef
                ]
            }
            messageData["mediaAttachments"] = mediaData
        }
        
        try await db
            .collection("users")
            .document(userId)
            .collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(message.id)
            .setData(messageData)
        */
    }
    
    // MARK: - Load Messages
    func loadMessages(for conversationId: String) async throws -> [FirestoreMessage] {
        // Firebase temporarily disabled - return empty array
        /*
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreError.notAuthenticated
        }
        
        let snapshot = try await db
            .collection("users")
            .document(userId)
            .collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "timestamp")
            .getDocuments()
        
        return snapshot.documents.compactMap { doc -> FirestoreMessage? in
            let data = doc.data()
            guard let content = data["content"] as? String,
                  let role = data["role"] as? String,
                  let timestamp = data["timestamp"] as? Timestamp else {
                return nil
            }
            
            // Parse media attachments if present
            var mediaAttachments: [MediaAttachment] = []
            if let mediaData = data["mediaAttachments"] as? [[String: Any]] {
                mediaAttachments = mediaData.compactMap { attachmentData in
                    guard let type = attachmentData["type"] as? String,
                          let url = attachmentData["url"] as? String,
                          let storageRef = attachmentData["storageRef"] as? String,
                          let mediaType = MediaAttachment.MediaType(rawValue: type) else {
                        return nil
                    }
                    
                    return MediaAttachment(
                        type: mediaType,
                        url: url,
                        thumbnailUrl: attachmentData["thumbnailUrl"] as? String,
                        width: attachmentData["width"] as? Int,
                        height: attachmentData["height"] as? Int,
                        duration: attachmentData["duration"] as? Double,
                        mimeType: attachmentData["mimeType"] as? String,
                        storageRef: storageRef
                    )
                }
            }
            
            return FirestoreMessage(
                id: doc.documentID,
                text: content,
                isFromUser: role == "user",
                timestamp: timestamp.dateValue(),
                mediaAttachments: mediaAttachments
            )
        }
        */
        
        // Temporary stub - return empty array
        return []
    }
    
    // MARK: - Save Conversation
    func saveOrUpdateConversation(_ conversation: FirestoreConversation) async throws {
        // Firebase temporarily disabled
        /*
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreError.notAuthenticated
        }
        
        let conversationData: [String: Any] = [
            "id": conversation.id,
            "projectId": conversation.projectId,
            "projectName": conversation.projectName,
            "lastMessage": conversation.lastMessage,
            "lastMessageTime": conversation.lastMessageTime,
            "userId": userId,
            "createdAt": conversation.createdAt
        ]
        
        try await db
            .collection("users")
            .document(userId)
            .collection("conversations")
            .document(conversation.id)
            .setData(conversationData, merge: true)
        */
        
        // Temporary stub - do nothing
        return
    }
    
    // MARK: - Load Conversations
    func loadConversations() async throws -> [FirestoreConversation] {
        // Firebase temporarily disabled - return empty array
        /*
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreError.notAuthenticated
        }
        
        let snapshot = try await db
            .collection("users")
            .document(userId)
            .collection("conversations")
            .order(by: "lastMessageTime", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc -> FirestoreConversation? in
            let data = doc.data()
            guard let id = data["id"] as? String,
                  let projectName = data["projectName"] as? String,
                  let lastMessage = data["lastMessage"] as? String,
                  let lastMessageTime = data["lastMessageTime"] as? Timestamp,
                  let createdAt = data["createdAt"] as? Timestamp else {
                return nil
            }
            
            // projectId might be missing in old documents, so make it optional
            let projectId = data["projectId"] as? String ?? id  // fallback to conversation id if missing
            
            return FirestoreConversation(
                id: id,
                projectId: projectId,
                projectName: projectName,
                lastMessage: lastMessage,
                lastMessageTime: lastMessageTime.dateValue(),
                createdAt: createdAt.dateValue()
            )
        }
        */
        
        // Temporary stub - return empty array
        return []
    }
    
    // MARK: - Delete Conversation
    func deleteConversation(_ conversationId: String) async throws {
        // Firebase temporarily disabled
        /*
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreError.notAuthenticated
        }
        
        let conversationRef = db
            .collection("users")
            .document(userId)
            .collection("conversations")
            .document(conversationId)
        
        // Delete all messages in the conversation
        let messagesSnapshot = try await conversationRef
            .collection("messages")
            .getDocuments()
        
        for message in messagesSnapshot.documents {
            try await message.reference.delete()
        }
        
        // Delete the conversation
        try await conversationRef.delete()
        */
        
        // Temporary stub - do nothing
        return
    }
}

// MARK: - Models
struct FirestoreMessage {
    let id: String
    let text: String
    let isFromUser: Bool
    let timestamp: Date
    let mediaAttachments: [MediaAttachment]
    
    init(id: String = UUID().uuidString, text: String, isFromUser: Bool, timestamp: Date = Date(), mediaAttachments: [MediaAttachment] = []) {
        self.id = id
        self.text = text
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.mediaAttachments = mediaAttachments
    }
}

struct FirestoreConversation {
    let id: String
    let projectId: String
    let projectName: String
    let lastMessage: String
    let lastMessageTime: Date
    let createdAt: Date
    
    init(id: String = UUID().uuidString, projectId: String, projectName: String, lastMessage: String, lastMessageTime: Date = Date(), createdAt: Date = Date()) {
        self.id = id
        self.projectId = projectId
        self.projectName = projectName
        self.lastMessage = lastMessage
        self.lastMessageTime = lastMessageTime
        self.createdAt = createdAt
    }
}

struct MediaAttachment: Identifiable {
    let id = UUID()
    let type: MediaType
    let url: String
    let thumbnailUrl: String?
    let width: Int?
    let height: Int?
    let duration: Double?
    let mimeType: String?
    let storageRef: String
    
    enum MediaType: String, CaseIterable {
        case image = "image"
        case video = "video"
        case audio = "audio"
        case document = "document"
        
        var displayName: String {
            rawValue.capitalized
        }
        
        var systemImage: String {
            switch self {
            case .image: return "photo"
            case .video: return "video"
            case .audio: return "music.note"
            case .document: return "doc"
            }
        }
    }
}

enum FirestoreError: LocalizedError {
    case notAuthenticated
    case saveFailed(String)
    case loadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .saveFailed(let message):
            return "Save failed: \(message)"
        case .loadFailed(let message):
            return "Load failed: \(message)"
        }
    }
}