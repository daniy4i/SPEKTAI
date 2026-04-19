//
//  ProjectMediaService.swift
//  lannaapp
//
//  Created by Claude on 01/23/2025.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

enum ProjectMediaType: String, CaseIterable {
    case audio = "audio"
    case video = "video"
    case image = "image"

    var icon: String {
        switch self {
        case .audio:
            return "waveform"
        case .video:
            return "video.fill"
        case .image:
            return "photo.fill"
        }
    }

    var displayName: String {
        switch self {
        case .audio:
            return "Audio"
        case .video:
            return "Video"
        case .image:
            return "Images"
        }
    }
}

struct ProjectMediaItem: Identifiable {
    let id: String
    let type: ProjectMediaType
    let url: String
    let thumbnailURL: String?
    let duration: TimeInterval?
    let fileName: String
    let fileSize: Int?
    let createdAt: Date
    let conversationId: String
    let conversationName: String?
    let messageContent: String?

    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        let totalSeconds = Int(duration.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedFileSize: String? {
        guard let fileSize = fileSize else { return nil }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSize))
    }
}

struct ProjectMediaSummary {
    let totalCount: Int
    let audioCount: Int
    let videoCount: Int
    let imageCount: Int
    let totalSize: Int64

    var formattedTotalSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
}

@MainActor
class ProjectMediaService: ObservableObject {
    @Published var mediaItems: [ProjectMediaItem] = []
    @Published var isLoading = false
    @Published var summary = ProjectMediaSummary(
        totalCount: 0,
        audioCount: 0,
        videoCount: 0,
        imageCount: 0,
        totalSize: 0
    )

    private let db = Firestore.firestore()

    func loadProjectMedia(projectId: String) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ ProjectMediaService: User not authenticated")
            return
        }

        isLoading = true
        print("🎬 ProjectMediaService: Loading media for project: \(projectId)")

        do {
            // Step 1: Get all conversations for this project
            let conversationsSnapshot = try await db.collection("users")
                .document(userId)
                .collection("conversations")
                .whereField("projectId", isEqualTo: projectId)
                .getDocuments()

            print("🎬 Found \(conversationsSnapshot.documents.count) conversations for project")

            var allMediaItems: [ProjectMediaItem] = []

            // Step 2: For each conversation, get all messages and extract media
            for conversationDoc in conversationsSnapshot.documents {
                let conversationId = conversationDoc.documentID
                let conversationData = conversationDoc.data()
                let conversationName = conversationData["projectName"] as? String

                let messagesSnapshot = try await db.collection("users")
                    .document(userId)
                    .collection("conversations")
                    .document(conversationId)
                    .collection("messages")
                    .order(by: "createdAt", descending: false)
                    .getDocuments()

                // Step 3: Extract media from messages
                for messageDoc in messagesSnapshot.documents {
                    let messageData = messageDoc.data()
                    let messageContent = messageData["content"] as? String
                    let createdAt = (messageData["createdAt"] as? Timestamp)?.dateValue() ?? Date()

                    // Check for metadata
                    if let metadataDict = messageData["metadata"] as? [String: Any] {
                        // Extract audio
                        if let audioURL = metadataDict["audioURL"] as? String {
                            let duration = metadataDict["audioDuration"] as? TimeInterval
                            let mediaItem = ProjectMediaItem(
                                id: UUID().uuidString,
                                type: ProjectMediaType.audio,
                                url: audioURL,
                                thumbnailURL: nil,
                                duration: duration,
                                fileName: "Voice Memo",
                                fileSize: nil,
                                createdAt: createdAt,
                                conversationId: conversationId,
                                conversationName: conversationName,
                                messageContent: messageContent
                            )
                            allMediaItems.append(mediaItem)
                        }

                        // Extract video
                        if let videoURL = metadataDict["videoURL"] as? String {
                            let duration = metadataDict["videoDuration"] as? TimeInterval
                            let thumbnailURL = metadataDict["videoThumbnailURL"] as? String
                            let mediaItem = ProjectMediaItem(
                                id: UUID().uuidString,
                                type: ProjectMediaType.video,
                                url: videoURL,
                                thumbnailURL: thumbnailURL,
                                duration: duration,
                                fileName: "Watch Note",
                                fileSize: nil,
                                createdAt: createdAt,
                                conversationId: conversationId,
                                conversationName: conversationName,
                                messageContent: messageContent
                            )
                            allMediaItems.append(mediaItem)
                        }

                        // Extract attachments (images)
                        if let attachments = metadataDict["attachments"] as? [[String: Any]] {
                            for attachment in attachments {
                                if let url = attachment["url"] as? String,
                                   let type = attachment["type"] as? String,
                                   type.lowercased().contains("image") {
                                    let fileName = attachment["name"] as? String ?? "Image"
                                    let fileSize = attachment["size"] as? Int
                                    let mediaItem = ProjectMediaItem(
                                        id: UUID().uuidString,
                                        type: ProjectMediaType.image,
                                        url: url,
                                        thumbnailURL: url, // Use same URL for thumbnail
                                        duration: nil,
                                        fileName: fileName,
                                        fileSize: fileSize,
                                        createdAt: createdAt,
                                        conversationId: conversationId,
                                        conversationName: conversationName,
                                        messageContent: messageContent
                                    )
                                    allMediaItems.append(mediaItem)
                                }
                            }
                        }
                    }
                }
            }

            // Sort by creation date (newest first)
            allMediaItems.sort { $0.createdAt > $1.createdAt }

            // Update summary
            let audioCount = allMediaItems.filter { $0.type == ProjectMediaType.audio }.count
            let videoCount = allMediaItems.filter { $0.type == ProjectMediaType.video }.count
            let imageCount = allMediaItems.filter { $0.type == ProjectMediaType.image }.count
            let totalSize = allMediaItems.compactMap { $0.fileSize }.reduce(0, +)

            let newSummary = ProjectMediaSummary(
                totalCount: allMediaItems.count,
                audioCount: audioCount,
                videoCount: videoCount,
                imageCount: imageCount,
                totalSize: Int64(totalSize)
            )

            // Update UI
            mediaItems = allMediaItems
            summary = newSummary
            isLoading = false

            print("✅ ProjectMediaService: Loaded \(allMediaItems.count) media items")
            print("📊 Summary: \(audioCount) audio, \(videoCount) video, \(imageCount) images")

        } catch {
            print("❌ ProjectMediaService: Error loading media: \(error)")
            isLoading = false
        }
    }

    func filterMedia(by type: ProjectMediaType?) -> [ProjectMediaItem] {
        guard let type = type else { return mediaItems }
        return mediaItems.filter { $0.type == type }
    }

    func searchMedia(query: String) -> [ProjectMediaItem] {
        guard !query.isEmpty else { return mediaItems }
        return mediaItems.filter { item in
            item.fileName.localizedCaseInsensitiveContains(query) ||
            item.conversationName?.localizedCaseInsensitiveContains(query) == true ||
            item.messageContent?.localizedCaseInsensitiveContains(query) == true
        }
    }
}