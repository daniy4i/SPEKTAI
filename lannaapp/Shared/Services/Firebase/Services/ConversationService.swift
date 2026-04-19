//
//  ConversationService.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 8/31/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

class ConversationService: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var isSendingMessage = false
    
    private let db = Firestore.firestore()
    private var conversationsListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?
    private var currentConversationId: String?
    
    deinit {
        stopListening()
    }
    
    // MARK: - Conversations
    
    func startListeningToConversations(projectId: String? = nil) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        var query = db.collection("users")
            .document(userId)
            .collection("conversations")
            .order(by: "updatedAt", descending: true)
        
        // Filter by project ID if provided
        if let projectId = projectId {
            query = query.whereField("projectId", isEqualTo: projectId)
        }
        
        conversationsListener = query.addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching conversations: \(error)")
                    Task { @MainActor in
                        self.isLoading = false
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    Task { @MainActor in
                        self.isLoading = false
                    }
                    return
                }
                
                Task { @MainActor in
                    self.conversations = documents.compactMap { document in
                        try? document.data(as: Conversation.self)
                    }
                    self.isLoading = false
                }
            }
    }
    
    func startListeningToMessages(conversationId: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Stop previous messages listener
        messagesListener?.remove()
        currentConversationId = conversationId
        
        messagesListener = db.collection("users")
            .document(userId)
            .collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching messages: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    let loadedMessages = documents.compactMap { document in
                        try? document.data(as: Message.self)
                    }
                    print("🔍 ConversationService: Loaded \(loadedMessages.count) messages for conversation \(conversationId)")
                    self.messages = loadedMessages
                }
            }
    }
    
    func stopListening() {
        conversationsListener?.remove()
        messagesListener?.remove()
        conversationsListener = nil
        messagesListener = nil
        currentConversationId = nil
    }
    
    // MARK: - Create Operations
    
    func createConversation(projectId: String?, projectName: String?, initialMessage: String) async throws -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let conversationId = UUID().uuidString
        let now = Date()
        
        let conversation = Conversation(
            userId: userId,
            projectId: projectId,
            projectName: projectName,
            lastMessage: initialMessage,
            lastMessageAt: now,
            lastMessageTime: now,
            messagesCount: initialMessage.isEmpty ? 0 : 1,
            updatedAt: now,
            createdAt: now
        )
        
        // Create conversation
        try await db.collection("users")
            .document(userId)
            .collection("conversations")
            .document(conversationId)
            .setData(from: conversation)
        
        // Add initial message only if not empty
        if !initialMessage.isEmpty {
            try await sendMessage(conversationId: conversationId, content: initialMessage, role: .user)
        }
        
        return conversationId
    }
    
    func sendMessage(
        conversationId: String,
        content: String,
        role: Message.MessageRole,
        metadata: MessageMetadata? = nil
    ) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        await MainActor.run {
            isSendingMessage = true
        }

        let message = Message(
            content: content,
            role: role,
            createdAt: Date(),
            userId: userId,
            conversationId: conversationId,
            metadata: metadata
        )
        
        // Add message to conversation
        try await db.collection("users")
            .document(userId)
            .collection("conversations")
            .document(conversationId)
            .collection("messages")
            .addDocument(from: message)
        
        // Update conversation's last message info
        let now = Date()
        try await db.collection("users")
            .document(userId)
            .collection("conversations")
            .document(conversationId)
            .updateData([
                "lastMessage": content,
                "lastMessageAt": now,
                "lastMessageTime": now,
                "updatedAt": now,
                "messagesCount": FieldValue.increment(Int64(1))
            ])

        await MainActor.run {
            self.isSendingMessage = false
        }
    }

    func sendAudioMessage(conversationId: String, fileURL: URL, duration: TimeInterval) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let sanitizedDuration = max(duration, 0)
        let formattedDuration = Self.formatDuration(sanitizedDuration)
        let storageRef = Storage.storage().reference()
            .child("users")
            .child(userId)
            .child("conversations")
            .child(conversationId)
            .child("audio")
            .child("listen-mode-\(UUID().uuidString).m4a")

        let metadata = StorageMetadata()
        metadata.contentType = "audio/m4a"

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                storageRef.putFile(from: fileURL, metadata: metadata) { _, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
        } catch {
            await MainActor.run { self.isSendingMessage = false }
            throw error
        }

        let downloadURL: URL
        do {
            downloadURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                storageRef.downloadURL { url, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let url = url {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(throwing: NSError(
                            domain: "AudioUpload",
                            code: 0,
                            userInfo: [NSLocalizedDescriptionKey: "Missing download URL"]
                        ))
                    }
                }
            }
        } catch {
            await MainActor.run { self.isSendingMessage = false }
            throw error
        }

        let messageMetadata = MessageMetadata(
            tokenCount: nil,
            processingTime: nil,
            model: nil,
            temperature: nil,
            attachments: nil,
            audioURL: downloadURL.absoluteString,
            audioDuration: sanitizedDuration,
            audioStoragePath: storageRef.fullPath
        )

        try await sendMessage(
            conversationId: conversationId,
            content: "🎧 Voice note (\(formattedDuration))",
            role: .user,
            metadata: messageMetadata
        )

        await MainActor.run {
            self.isSendingMessage = false
        }
    }

    func sendVideoMessage(
        conversationId: String,
        videoFileURL: URL,
        duration: TimeInterval,
        thumbnailFileURL: URL?
    ) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let sanitizedDuration = max(duration, 0)
        let formattedDuration = Self.formatDuration(sanitizedDuration)

        let baseRef = Storage.storage().reference()
            .child("users")
            .child(userId)
            .child("conversations")
            .child(conversationId)
            .child("video")

        let videoRef = baseRef
            .child("watch-mode-\(UUID().uuidString).mp4")

        let videoMetadata = StorageMetadata()
        videoMetadata.contentType = "video/mp4"

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                videoRef.putFile(from: videoFileURL, metadata: videoMetadata) { _, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
        } catch {
            await MainActor.run { self.isSendingMessage = false }
            throw error
        }

        let videoDownloadURL: URL
        do {
            videoDownloadURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                videoRef.downloadURL { url, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let url = url {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(throwing: NSError(
                            domain: "VideoUpload",
                            code: 0,
                            userInfo: [NSLocalizedDescriptionKey: "Missing video download URL"]
                        ))
                    }
                }
            }
        } catch {
            await MainActor.run { self.isSendingMessage = false }
            throw error
        }

        var thumbnailDownloadURL: URL?
        var thumbnailStoragePath: String?

        if let thumbnailFileURL {
            let thumbnailRef = baseRef
                .child("thumbnails")
                .child("watch-mode-thumb-\(UUID().uuidString).jpg")

            let thumbnailMetadata = StorageMetadata()
            thumbnailMetadata.contentType = "image/jpeg"

            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    thumbnailRef.putFile(from: thumbnailFileURL, metadata: thumbnailMetadata) { _, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: ())
                        }
                    }
                }
            } catch {
                await MainActor.run { self.isSendingMessage = false }
                throw error
            }

            do {
                thumbnailDownloadURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                    thumbnailRef.downloadURL { url, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let url = url {
                            continuation.resume(returning: url)
                        } else {
                            continuation.resume(throwing: NSError(
                                domain: "VideoUpload",
                                code: 1,
                                userInfo: [NSLocalizedDescriptionKey: "Missing thumbnail download URL"]
                            ))
                        }
                    }
                }
            } catch {
                await MainActor.run { self.isSendingMessage = false }
                throw error
            }

            thumbnailStoragePath = thumbnailRef.fullPath
        }

        let messageMetadata = MessageMetadata(
            tokenCount: nil,
            processingTime: nil,
            model: nil,
            temperature: nil,
            attachments: nil,
            audioURL: nil,
            audioDuration: nil,
            audioStoragePath: nil,
            videoURL: videoDownloadURL.absoluteString,
            videoDuration: sanitizedDuration,
            videoStoragePath: videoRef.fullPath,
            videoThumbnailURL: thumbnailDownloadURL?.absoluteString,
            videoThumbnailStoragePath: thumbnailStoragePath
        )

        try await sendMessage(
            conversationId: conversationId,
            content: "🎥 Watch note (\(formattedDuration))",
            role: .user,
            metadata: messageMetadata
        )

        await MainActor.run {
            self.isSendingMessage = false
        }
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - AI Response Integration
    
    func sendAIResponse(conversationId: String, userMessage: String) async throws {
        let chatService = ChatService.shared
        
        // Set loading state for typing indicator
        await MainActor.run {
            isSendingMessage = true
        }
        
        // Create a chat message for the API
        let chatMessage = ChatMessage(
            content: userMessage,
            role: MessageRole.user
        )
        
        var accumulatedResponse = ""
        
        // Send to Lanna AI API with streaming
        await chatService.sendMessage(
            chatMessage,
            sessionId: conversationId,
            onTokenReceived: { messageId, token in
                Task { @MainActor in
                    accumulatedResponse += token
                    // Optionally update UI with streaming text
                }
            },
            onComplete: { completedMessage in
                Task {
                    // Save the complete AI response to Firestore
                    try await self.sendMessage(
                        conversationId: conversationId,
                        content: completedMessage.content,
                        role: .assistant
                    )
                    
                    // Clear loading state
                    await MainActor.run {
                        self.isSendingMessage = false
                    }
                }
            },
            onError: { error in
                print("ChatService error: \(error.message)")
                Task {
                    // Fallback to a generic error message
                    try await self.sendMessage(
                        conversationId: conversationId,
                        content: "I'm having trouble connecting right now. Please try again.",
                        role: .assistant
                    )
                    
                    // Clear loading state
                    await MainActor.run {
                        self.isSendingMessage = false
                    }
                }
            }
        )
    }
    
    // MARK: - Shared Context Operations
    
    func updateSharedContext(conversationId: String, projectId: String, sharedContext: String?, sharedDocuments: [SharedDocument]?) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { 
            print("❌ ConversationService: User not authenticated")
            return 
        }
        
        print("🔧 ConversationService: Updating shared context for conversation: \(conversationId)")
        
        let conversationRef = db.collection("users")
            .document(userId)
            .collection("conversations")
            .document(conversationId)
        
        var updateData: [String: Any] = [
            "updatedAt": Timestamp(date: Date()),
            "projectId": projectId
        ]
        
        if let sharedContext = sharedContext {
            updateData["sharedContext"] = sharedContext
        }
        
        if let sharedDocuments = sharedDocuments {
            updateData["sharedDocuments"] = sharedDocuments.map { document in
                [
                    "id": document.id,
                    "name": document.name,
                    "url": document.url,
                    "type": document.type,
                    "uploadedAt": Timestamp(date: document.uploadedAt)
                ]
            }
        }
        
        try await conversationRef.updateData(updateData)
        print("✅ ConversationService: Shared context updated successfully")
    }
    
    // MARK: - Delete Operations

    func deleteConversation(_ conversation: Conversation) async throws {
        guard let userId = Auth.auth().currentUser?.uid,
              let conversationId = conversation.id else {
            print("❌ Cannot delete conversation: missing user ID or conversation ID")
            return
        }

        print("🗑️ Starting deletion of conversation: \(conversationId)")

        // Step 1: Get all messages to collect media URLs for deletion
        let messagesSnapshot = try await db.collection("users")
            .document(userId)
            .collection("conversations")
            .document(conversationId)
            .collection("messages")
            .getDocuments()

        let messages = messagesSnapshot.documents.compactMap { document in
            try? document.data(as: Message.self)
        }

        print("🗑️ Found \(messages.count) messages to process")

        // Step 2: Delete media files from Firebase Storage
        await deleteMediaFiles(for: messages, userId: userId, conversationId: conversationId)

        // Step 3: Delete all messages (batch delete for efficiency)
        try await deleteMessagesInBatches(messagesSnapshot.documents)

        // Step 4: Delete the conversation document
        try await db.collection("users")
            .document(userId)
            .collection("conversations")
            .document(conversationId)
            .delete()

        print("✅ Successfully deleted conversation: \(conversationId)")
    }

    private func deleteMediaFiles(for messages: [Message], userId: String, conversationId: String) async {
        let storage = Storage.storage()
        var mediaFiles: [String] = []

        // Collect all media storage paths
        for message in messages {
            if let audioPath = message.metadata?.audioStoragePath {
                mediaFiles.append(audioPath)
            }
            if let videoPath = message.metadata?.videoStoragePath {
                mediaFiles.append(videoPath)
            }
            if let thumbnailPath = message.metadata?.videoThumbnailStoragePath {
                mediaFiles.append(thumbnailPath)
            }
        }

        print("🗑️ Found \(mediaFiles.count) media files to delete")

        // Delete each media file
        for filePath in mediaFiles {
            do {
                let fileRef = storage.reference(withPath: filePath)
                try await fileRef.delete()
                print("✅ Deleted media file: \(filePath)")
            } catch {
                print("⚠️ Failed to delete media file \(filePath): \(error)")
                // Continue with deletion even if some files fail
            }
        }

        // Also try to delete the entire conversation folder in storage
        let conversationStoragePath = "users/\(userId)/conversations/\(conversationId)"
        do {
            let folderRef = storage.reference(withPath: conversationStoragePath)
            try await deleteStorageFolder(folderRef)
            print("✅ Deleted conversation storage folder: \(conversationStoragePath)")
        } catch {
            print("⚠️ Failed to delete conversation storage folder: \(error)")
        }
    }

    private func deleteStorageFolder(_ folderRef: StorageReference) async throws {
        // List all items in the folder
        let listResult = try await folderRef.listAll()

        // Delete all files
        for item in listResult.items {
            try await item.delete()
        }

        // Recursively delete subfolders
        for prefix in listResult.prefixes {
            try await deleteStorageFolder(prefix)
        }
    }

    private func deleteMessagesInBatches(_ messageDocuments: [QueryDocumentSnapshot]) async throws {
        let batchSize = 500 // Firestore batch limit
        let batches = messageDocuments.chunked(into: batchSize)

        for batch in batches {
            let writeBatch = db.batch()

            for document in batch {
                writeBatch.deleteDocument(document.reference)
            }

            try await writeBatch.commit()
            print("✅ Deleted batch of \(batch.count) messages")
        }
    }
}

// MARK: - Array Extension for Batch Processing

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
