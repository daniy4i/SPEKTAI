import Foundation
import SwiftUI

// MARK: - Media Item Model

struct MediaItem: Identifiable, Codable {
    let id: String
    let conversationId: String
    let messageId: String
    let type: MediaType
    let url: String
    let thumbnailUrl: String?
    let title: String?
    let description: String?
    let createdAt: Date
    let fileSize: Int64?
    let duration: TimeInterval? // For video/audio
    let dimensions: MediaDimensions?
    
    init(
        id: String = UUID().uuidString,
        conversationId: String,
        messageId: String,
        type: MediaType,
        url: String,
        thumbnailUrl: String? = nil,
        title: String? = nil,
        description: String? = nil,
        createdAt: Date = Date(),
        fileSize: Int64? = nil,
        duration: TimeInterval? = nil,
        dimensions: MediaDimensions? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.messageId = messageId
        self.type = type
        self.url = url
        self.thumbnailUrl = thumbnailUrl
        self.title = title
        self.description = description
        self.createdAt = createdAt
        self.fileSize = fileSize
        self.duration = duration
        self.dimensions = dimensions
    }
}

// MARK: - Media Type

enum MediaType: String, CaseIterable, Codable {
    case image = "image"
    case video = "video"
    case audio = "audio"
    case document = "document"
    case gif = "gif"
    
    var displayName: String {
        switch self {
        case .image:
            return "Image"
        case .video:
            return "Video"
        case .audio:
            return "Audio"
        case .document:
            return "Document"
        case .gif:
            return "GIF"
        }
    }
    
    var systemIcon: String {
        switch self {
        case .image:
            return "photo"
        case .video:
            return "video"
        case .audio:
            return "waveform"
        case .document:
            return "doc.text"
        case .gif:
            return "photo.stack"
        }
    }
    
    var color: Color {
        switch self {
        case .image:
            return .blue
        case .video:
            return .red
        case .audio:
            return .orange
        case .document:
            return .gray
        case .gif:
            return .purple
        }
    }
}

// MARK: - Media Dimensions

struct MediaDimensions: Codable {
    let width: Int
    let height: Int
    
    var aspectRatio: Double {
        return Double(width) / Double(height)
    }
    
    var displayString: String {
        return "\(width) × \(height)"
    }
}

// MARK: - Type Adapters
extension MediaType {
    func toChatMediaType() -> ChatMediaType {
        switch self {
        case .document: return .document
        case .image:    return .image
        case .video:    return .video
        case .audio:    return .audio
        case .gif:      return .image // Map GIF to image for chat
        }
    }
}

// MARK: - Mock Data

extension MediaItem {
    static let mockMediaItems: [MediaItem] = [
        MediaItem(
            conversationId: "conv1",
            messageId: "msg1",
            type: .image,
            url: "https://example.com/image1.jpg",
            thumbnailUrl: "https://example.com/thumb1.jpg",
            title: "Generated Artwork",
            description: "AI-generated landscape painting",
            fileSize: 1024000,
            dimensions: MediaDimensions(width: 1024, height: 768)
        ),
        MediaItem(
            conversationId: "conv1",
            messageId: "msg2",
            type: .video,
            url: "https://example.com/video1.mp4",
            thumbnailUrl: "https://example.com/video1_thumb.jpg",
            title: "Animation Sequence",
            description: "Short animation of a character walking",
            fileSize: 5120000,
            duration: 15.5,
            dimensions: MediaDimensions(width: 1920, height: 1080)
        ),
        MediaItem(
            conversationId: "conv1",
            messageId: "msg3",
            type: .audio,
            url: "https://example.com/audio1.mp3",
            title: "Voice Narration",
            description: "AI-generated voice reading the story",
            fileSize: 2048000,
            duration: 45.2
        ),
        MediaItem(
            conversationId: "conv1",
            messageId: "msg4",
            type: .gif,
            url: "https://example.com/animation.gif",
            thumbnailUrl: "https://example.com/animation_thumb.jpg",
            title: "Loading Animation",
            description: "Custom loading animation for the app",
            fileSize: 1536000,
            dimensions: MediaDimensions(width: 512, height: 512)
        )
    ]
}
