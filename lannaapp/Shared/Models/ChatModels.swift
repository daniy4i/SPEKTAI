import Foundation

// MARK: - Chat Message
struct ChatMessage: Codable, Identifiable {
    let id: String
    let content: String
    let role: MessageRole
    let timestamp: Date
    let mediaItems: [ChatMediaItem]?
    let streamingState: StreamingState
    let generationRequest: GenerationRequest?
    let retryCount: Int
    let error: ChatError?
    
    init(
        id: String = UUID().uuidString,
        content: String,
        role: MessageRole,
        timestamp: Date = Date(),
        mediaItems: [ChatMediaItem]? = nil,
        streamingState: StreamingState = .completed,
        generationRequest: GenerationRequest? = nil,
        retryCount: Int = 0,
        error: ChatError? = nil
    ) {
        self.id = id
        self.content = content
        self.role = role
        self.timestamp = timestamp
        self.mediaItems = mediaItems
        self.streamingState = streamingState
        self.generationRequest = generationRequest
        self.retryCount = retryCount
        self.error = error
    }
}

// MARK: - Message Role
enum MessageRole: String, Codable, CaseIterable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .user: return "You"
        case .assistant: return "Lanna"
        case .system: return "System"
        }
    }
}

// MARK: - Streaming State
enum StreamingState: String, Codable {
    case pending = "pending"
    case streaming = "streaming"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
}

// MARK: - Chat Media Item (for chat messages)
struct ChatMediaItem: Codable, Identifiable {
    let id: String
    let type: ChatMediaType
    let url: String?
    let thumbnailURL: String?
    let generationState: GenerationState
    let metadata: MediaMetadata?
    
    init(
        id: String = UUID().uuidString,
        type: ChatMediaType,
        url: String?,
        thumbnailURL: String? = nil,
        generationState: GenerationState = .completed,
        metadata: MediaMetadata? = nil
    ) {
        self.id = id
        self.type = type
        self.url = url
        self.thumbnailURL = thumbnailURL
        self.generationState = generationState
        self.metadata = metadata
    }
}

// MARK: - Chat Media Type
enum ChatMediaType: String, Codable, CaseIterable {
    case image = "image"
    case video = "video"
    case audio = "audio"
    case document = "document"
    
    var displayName: String {
        switch self {
        case .image: return "Image"
        case .video: return "Video"
        case .audio: return "Audio"
        case .document: return "Document"
        }
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

// MARK: - Generation State
enum GenerationState: String, Codable {
    case pending = "pending"
    case generating = "generating"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
}

// MARK: - Media Metadata
struct MediaMetadata: Codable {
    let fileName: String?
    let fileSize: Int?
    let mimeType: String?
    let duration: Double?
    let dimensions: ChatMediaDimensions?
}

struct ChatMediaDimensions: Codable {
    let width: Int
    let height: Int
}

// MARK: - Type Adapters
extension GenerationType {
    func toMediaType() -> MediaType {
        switch self {
        case .text:  return .document
        case .image: return .image
        case .video: return .video
        case .music: return .audio
        }
    }
    func toChatMediaType() -> ChatMediaType {
        switch self {
        case .text:  return .document
        case .image: return .image
        case .video: return .video
        case .music: return .audio
        }
    }
}

extension ChatMediaType {
    func toMediaType() -> MediaType {
        switch self {
        case .document: return .document
        case .image:    return .image
        case .video:    return .video
        case .audio:    return .audio
        }
    }
}

extension ChatMediaItem {
    func toMediaItem() -> MediaItem {
        MediaItem(
            conversationId: "",
            messageId: "",
            type: self.type.toMediaType(),
            url: self.url ?? "",
            thumbnailUrl: self.thumbnailURL,
            title: nil,
            description: nil,
            createdAt: Date(),
            fileSize: nil,
            duration: nil,
            dimensions: nil
        )
    }
}

// MARK: - Generation Request
struct GenerationRequest: Codable {
    let id: String
    let type: GenerationType
    let prompt: String
    let parameters: GenerationParameters
    let timestamp: Date
    
    init(
        id: String = UUID().uuidString,
        type: GenerationType,
        prompt: String,
        parameters: GenerationParameters = .default,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.prompt = prompt
        self.parameters = parameters
        self.timestamp = timestamp
    }
}

// MARK: - Generation Type
enum GenerationType: String, Codable, CaseIterable {
    case text = "text"
    case image = "image"
    case video = "video"
    case music = "music"
    
    var displayName: String {
        switch self {
        case .text: return "Text"
        case .image: return "Image"
        case .video: return "Video"
        case .music: return "Music"
        }
    }
    
    var systemImage: String {
        switch self {
        case .text: return "text.bubble"
        case .image: return "photo"
        case .video: return "video"
        case .music: return "music.note"
        }
    }
}

// MARK: - Generation Parameters
struct GenerationParameters: Codable {
    let model: String?
    let temperature: Double?
    let maxTokens: Int?
    let topP: Double?
    let frequencyPenalty: Double?
    let presencePenalty: Double?
    let seed: Int?
    let responseFormat: String?
    
    // Image/Video specific
    let width: Int?
    let height: Int?
    let steps: Int?
    let guidanceScale: Double?
    let negativePrompt: String?
    
    // Audio specific
    let duration: Double?
    let format: String?
    
    static let `default` = GenerationParameters(
        model: nil,
        temperature: 0.7,
        maxTokens: 4000,
        topP: 1.0,
        frequencyPenalty: 0.0,
        presencePenalty: 0.0,
        seed: nil,
        responseFormat: nil,
        width: nil,
        height: nil,
        steps: nil,
        guidanceScale: nil,
        negativePrompt: nil,
        duration: nil,
        format: nil
    )
}

// MARK: - Chat Error
struct ChatError: Error, Codable, Identifiable {
    let id: String
    let code: ChatErrorCode
    let message: String
    let retryable: Bool
    let timestamp: Date
    
    init(
        id: String = UUID().uuidString,
        code: ChatErrorCode,
        message: String,
        retryable: Bool = true,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.code = code
        self.message = message
        self.retryable = retryable
        self.timestamp = timestamp
    }
}

// MARK: - Chat Error Code
enum ChatErrorCode: String, Codable {
    case networkError = "network_error"
    case authenticationError = "authentication_error"
    case serverError = "server_error"
    case validationError = "validation_error"
    case rateLimitError = "rate_limit_error"
    case unknownError = "unknown_error"
    
    var displayName: String {
        switch self {
        case .networkError: return "Network Error"
        case .authenticationError: return "Authentication Error"
        case .serverError: return "Server Error"
        case .validationError: return "Validation Error"
        case .rateLimitError: return "Rate Limit Error"
        case .unknownError: return "Unknown Error"
        }
    }
    
    var systemImage: String {
        switch self {
        case .networkError: return "wifi.exclamationmark"
        case .authenticationError: return "person.crop.circle.badge.exclamationmark"
        case .serverError: return "server.rack"
        case .validationError: return "exclamationmark.triangle"
        case .rateLimitError: return "clock.badge.exclamationmark"
        case .unknownError: return "questionmark.circle"
        }
    }
}