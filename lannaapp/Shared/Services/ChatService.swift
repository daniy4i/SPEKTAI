import Foundation
import Combine
import FirebaseAuth

@MainActor
class ChatService: ObservableObject {
    static let shared = ChatService()
    
    // MARK: - Configuration
    private struct Config {
        // Creative Agent API endpoints
        static let baseURL = "https://arthurai-alqqs7uqwa-uw.a.run.app"
        static let chatEndpoint = "\(baseURL)/chat"
        static let streamEndpoint = "\(baseURL)/chat/stream"
        static let jobsEndpoint = "\(baseURL)/jobs"
        static let healthEndpoint = "\(baseURL)/health"
        
        // Legacy endpoints (kept for backward compatibility)
        static let imageEndpoint = "\(baseURL)/generate/image"
        static let videoEndpoint = "\(baseURL)/generate/video"
        static let musicEndpoint = "\(baseURL)/generate/music"
        static let uploadEndpoint = "\(baseURL)/upload"
        
        static let maxRetryAttempts = 3
        static let retryDelay: TimeInterval = 1.0
        static let streamingTimeout: TimeInterval = 60.0
        
        // Media generation timeouts (in seconds)
        static let imageGenerationTimeout: TimeInterval = 120.0  // 2 minutes
        static let videoGenerationTimeout: TimeInterval = 600.0  // 10 minutes
        static let musicGenerationTimeout: TimeInterval = 300.0  // 5 minutes
        
        // Polling intervals (in seconds)
        static let imagePollingInterval: TimeInterval = 2.0
        static let videoPollingInterval: TimeInterval = 5.0
        static let musicPollingInterval: TimeInterval = 3.0
    }
    
    // MARK: - Properties
    private let urlSession: URLSession
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    private var streamingTasks: [String: Task<Void, Error>] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var connectionError: ChatError?
    @Published var apiHealth: APIHealth = .unknown
    
    // MARK: - Initialization
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Config.streamingTimeout
        config.timeoutIntervalForResource = Config.streamingTimeout * 2
        self.urlSession = URLSession(configuration: config)
        
        setupDateFormatters()
        monitorNetworkConnection()
        checkAPIHealth()
    }
    
    deinit {
        streamingTasks.values.forEach { $0.cancel() }
    }
    
    // MARK: - Public API
    
    /// Test the Creative Agent API connection
    func testAPIConnection() async -> Bool {
        do {
            let health = try await getAPIHealth()
            return health == .healthy
        } catch {
            return false
        }
    }
    
    /// Check API health status
    func checkAPIHealth() {
        Task {
            do {
                let health = try await getAPIHealth()
                await MainActor.run {
                    self.apiHealth = health
                    self.isConnected = health == .healthy
                    self.connectionError = nil
                }
            } catch {
                await MainActor.run {
                    self.apiHealth = .unhealthy
                    self.isConnected = false
                    self.connectionError = mapError(error)
                }
            }
        }
    }
    
    /// Send a chat message with streaming response
    func sendMessage(
        _ message: ChatMessage,
        sessionId: String,
        onTokenReceived: @escaping (String, String) -> Void,
        onComplete: @escaping (ChatMessage) -> Void,
        onError: @escaping (ChatError) -> Void
    ) {
        let taskId = message.id
        
        streamingTasks[taskId] = Task {
            do {
                // Try streaming first
                try await streamChatCompletion(
                    message: message,
                    sessionId: sessionId,
                    onTokenReceived: onTokenReceived,
                    onComplete: onComplete,
                    onError: onError
                )
            } catch {
                print("ChatService: Streaming failed, trying regular chat endpoint")
                // Fallback to regular chat endpoint
                do {
                    let response = try await regularChatCompletion(
                        message: message,
                        sessionId: sessionId
                    )
                    await MainActor.run {
                        onComplete(response)
                    }
                } catch {
                    let chatError = mapError(error)
                    await MainActor.run {
                        onError(chatError)
                    }
                }
            }
        }
    }
    
    /// Generate media content
    func generateMedia(
        request: GenerationRequest,
        sessionId: String,
        onProgress: @escaping (Double) -> Void,
        onComplete: @escaping (MediaItem) -> Void,
        onError: @escaping (ChatError) -> Void
    ) -> String {
        let taskId = UUID().uuidString
        
        streamingTasks[taskId] = Task {
            do {
                let mediaItem = try await generateMediaContent(
                    request: request,
                    sessionId: sessionId,
                    onProgress: onProgress
                )
                await MainActor.run {
                    onComplete(mediaItem)
                }
            } catch {
                let chatError = mapError(error)
                await MainActor.run {
                    onError(chatError)
                }
            }
        }
        
        return taskId
    }
    
    /// Upload media file
    func uploadMedia(
        data: Data,
        fileName: String,
        mimeType: String,
        onProgress: @escaping (Double) -> Void,
        onComplete: @escaping (String) -> Void,
        onError: @escaping (ChatError) -> Void
    ) -> String {
        let taskId = UUID().uuidString
        
        streamingTasks[taskId] = Task {
            do {
                let url = try await uploadMediaData(
                    data: data,
                    fileName: fileName,
                    mimeType: mimeType,
                    onProgress: onProgress
                )
                await MainActor.run {
                    onComplete(url)
                }
            } catch {
                let chatError = mapError(error)
                await MainActor.run {
                    onError(chatError)
                }
            }
        }
        
        return taskId
    }
    
    /// Cancel a streaming operation
    func cancelOperation(_ taskId: String) {
        streamingTasks[taskId]?.cancel()
        streamingTasks.removeValue(forKey: taskId)
    }
    
    /// Retry a failed operation
    func retryMessage(
        _ message: ChatMessage,
        sessionId: String,
        onTokenReceived: @escaping (String, String) -> Void,
        onComplete: @escaping (ChatMessage) -> Void,
        onError: @escaping (ChatError) -> Void
    ) {
        var retryMessage = message
        retryMessage = ChatMessage(
            id: message.id,
            content: message.content,
            role: message.role,
            timestamp: message.timestamp,
            mediaItems: message.mediaItems,
            streamingState: .pending,
            generationRequest: message.generationRequest,
            retryCount: message.retryCount + 1,
            error: nil
        )
        
        sendMessage(
            retryMessage,
            sessionId: sessionId,
            onTokenReceived: onTokenReceived,
            onComplete: onComplete,
            onError: onError
        )
    }
}

// MARK: - Private Methods
private extension ChatService {
    
    func setupDateFormatters() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        jsonEncoder.dateEncodingStrategy = .formatted(formatter)
        jsonDecoder.dateDecodingStrategy = .formatted(formatter)
    }
    
    func monitorNetworkConnection() {
        // Simple network monitoring - you can enhance this with proper network reachability
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkConnection()
            }
            .store(in: &cancellables)
    }
    
    func checkConnection() {
        Task {
            do {
                var request = URLRequest(url: URL(string: Config.healthEndpoint)!)
                request.httpMethod = "GET"
                request.timeoutInterval = 5.0
                
                let _ = try await urlSession.data(for: request)
                await MainActor.run {
                    self.isConnected = true
                    self.connectionError = nil
                }
            } catch {
                await MainActor.run {
                    self.isConnected = false
                    self.connectionError = mapError(error)
                }
            }
        }
    }
    
    /// Regular chat completion (non-streaming fallback)
    func regularChatCompletion(
        message: ChatMessage,
        sessionId: String
    ) async throws -> ChatMessage {
        guard let authToken = await getAuthToken() else {
            throw ChatError(code: .authenticationError, message: "Authentication failed")
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            throw ChatError(code: .authenticationError, message: "User not authenticated")
        }
        
        let requestBody = [
            "message": message.content,
            "session_id": sessionId,
            "project_id": NSNull()
        ] as [String : Any]
        
        var request = URLRequest(url: URL(string: Config.chatEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue(userId, forHTTPHeaderField: "x-user-uid")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatError(code: .serverError, message: "Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorBody = String(data: data, encoding: .utf8) {
                print("ChatService regular endpoint error: \(httpResponse.statusCode) - \(errorBody)")
            }
            throw ChatError(code: .serverError, message: "Server error: \(httpResponse.statusCode)")
        }
        
        let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let output = jsonResponse?["output"] as? String ?? "No response"
        
        return ChatMessage(
            id: message.id,
            content: output,
            role: .assistant,
            timestamp: Date(),
            streamingState: .completed
        )
    }
    
    /// Get API health status
    func getAPIHealth() async throws -> APIHealth {
        var request = URLRequest(url: URL(string: Config.healthEndpoint)!)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatError(code: .serverError, message: "Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ChatError(code: .serverError, message: "Server error: \(httpResponse.statusCode)")
        }
        
        // Try to parse health response
        if let healthString = String(data: data, encoding: .utf8) {
            if healthString.contains("healthy") || healthString.contains("ok") {
                return .healthy
            } else if healthString.contains("unhealthy") || healthString.contains("error") {
                return .unhealthy
            }
        }
        
        // Default to healthy if we can't parse the response
        return .healthy
    }
    
    /// Stream chat completion from Cloud Run endpoint
    func streamChatCompletion(
        message: ChatMessage,
        sessionId: String,
        onTokenReceived: @escaping (String, String) -> Void,
        onComplete: @escaping (ChatMessage) -> Void,
        onError: @escaping (ChatError) -> Void
    ) async throws {
        
        guard let authToken = await getAuthToken() else {
            print("ChatService: Authentication failed - no auth token")
            throw ChatError(code: .authenticationError, message: "Authentication failed")
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("ChatService: No current user")
            throw ChatError(code: .authenticationError, message: "User not authenticated")
        }
        
        print("ChatService: Making request to \(Config.streamEndpoint)")
        print("ChatService: Message content: \(message.content)")
        print("ChatService: User ID: \(userId)")
        
        let requestBody = [
            "message": message.content,
            "session_id": sessionId,
            "project_id": NSNull()
        ] as [String : Any]
        
        // Debug: Print the actual JSON being sent
        if let jsonData = try? JSONSerialization.data(withJSONObject: requestBody),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("📤 ChatService: Sending JSON: \(jsonString)")
        }
        
        var request = URLRequest(url: URL(string: Config.streamEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue(userId, forHTTPHeaderField: "x-user-uid")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (asyncBytes, response) = try await urlSession.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("ChatService: Invalid HTTP response")
            throw ChatError(code: .serverError, message: "Invalid response")
        }
        
        print("ChatService: HTTP Status Code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = "Server error: \(httpResponse.statusCode)"
            print("ChatService: \(errorMessage)")
            
            // Try to read error response body
            var errorData = Data()
            do {
                for try await chunk in asyncBytes {
                    errorData.append(chunk)
                }
                if let errorBody = String(data: errorData, encoding: .utf8) {
                    print("ChatService: Error response body: \(errorBody)")
                }
            } catch {
                print("ChatService: Could not read error body")
            }
            
            throw ChatError(code: .serverError, message: errorMessage)
        }
        
        print("✅ ChatService: Starting to read stream data...")
        var accumulatedContent = ""
        let messageId = message.id
        
        for try await line in asyncBytes.lines {
            guard !Task.isCancelled else { break }
            
            print("📡 ChatService: Received line: '\(line)'")
            
            // Parse SSE format
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))
                print("📡 ChatService: SSE data: '\(jsonString)'")
                
                if jsonString == "[DONE]" {
                    print("✅ ChatService: Stream completed with content: '\(accumulatedContent)'")
                    // Stream completed
                    let completedMessage = ChatMessage(
                        id: messageId,
                        content: accumulatedContent,
                        role: .assistant,
                        timestamp: Date(),
                        streamingState: .completed
                    )
                    
                    await MainActor.run {
                        onComplete(completedMessage)
                    }
                    break
                }
                
                guard let data = jsonString.data(using: .utf8) else { 
                    print("⚠️ ChatService: Could not convert JSON string to data")
                    continue 
                }
                
                do {
                    // Try parsing as simple response first
                    if let simpleResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("📡 ChatService: Parsed simple response: \(simpleResponse)")
                        
                        let responseType = simpleResponse["type"] as? String
                        
                        if responseType == "token", let content = simpleResponse["content"] as? String {
                            // Check if this is a final channel token (user-facing content)
                            let channel = simpleResponse["channel"] as? String
                            if channel == "final" || channel == nil {
                                accumulatedContent += content
                                await MainActor.run {
                                    onTokenReceived(messageId, content)
                                }
                            }
                            // Skip analysis channel tokens (internal reasoning)
                        } else if responseType == "complete", let finalOutput = simpleResponse["final_output"] as? String {
                            // Final complete response
                            print("✅ ChatService: Received final output: '\(finalOutput)'")
                            let completedMessage = ChatMessage(
                                id: messageId,
                                content: finalOutput,
                                role: .assistant,
                                timestamp: Date(),
                                streamingState: .completed
                            )
                            
                            await MainActor.run {
                                onComplete(completedMessage)
                            }
                            break
                        } else if responseType == "tool_call" {
                            // Handle Syncnoy tool calls
                            if let toolCall = simpleResponse["tool_call"] as? [String: Any],
                               let toolName = toolCall["name"] as? String,
                               let arguments = toolCall["arguments"] as? [String: Any] {
                                print("📡 ChatService: Received tool call: \(toolName)")
                                await handleSyncnoyToolCall(toolName: toolName, arguments: arguments, sessionId: sessionId, onTokenReceived: onTokenReceived, messageId: messageId)
                            }
                        } else if responseType == "media" {
                            // Handle media content if needed
                            print("📡 ChatService: Received media content")
                        }
                    } else {
                        // Try original parsing
                        let response = try jsonDecoder.decode(ChatCompletionResponse.self, from: data)
                        if let content = response.choices.first?.delta?.content {
                            accumulatedContent += content
                            await MainActor.run {
                                onTokenReceived(messageId, content)
                            }
                        }
                    }
                } catch {
                    print("⚠️ ChatService: Failed to parse JSON: \(error)")
                    continue
                }
            } else if !line.isEmpty {
                print("📡 ChatService: Non-SSE line: '\(line)'")
            }
        }
        
        // Clean up
        streamingTasks.removeValue(forKey: messageId)
    }
    
    /// Generate media content
    func generateMediaContent(
        request: GenerationRequest,
        sessionId: String,
        onProgress: @escaping (Double) -> Void
    ) async throws -> MediaItem {
        
        guard let authToken = await getAuthToken() else {
            throw ChatError(code: .authenticationError, message: "Authentication failed")
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            throw ChatError(code: .authenticationError, message: "User not authenticated")
        }
        
        let endpoint: String
        switch request.type {
        case .image:
            endpoint = Config.imageEndpoint
        case .video:
            endpoint = Config.videoEndpoint
        case .music:
            endpoint = Config.musicEndpoint
        case .text:
            throw ChatError(code: .validationError, message: "Use chat completion for text generation")
        }
        
        let requestBody = MediaGenerationRequest(
            prompt: request.prompt,
            parameters: request.parameters,
            sessionId: sessionId
        )
        
        var urlRequest = URLRequest(url: URL(string: endpoint)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(userId, forHTTPHeaderField: "x-user-uid")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try jsonEncoder.encode(requestBody)
        
        let (data, response) = try await urlSession.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatError(code: .serverError, message: "Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ChatError(code: .serverError, message: "Server error: \(httpResponse.statusCode)")
        }
        
        let generationResponse = try jsonDecoder.decode(MediaGenerationResponse.self, from: data)
        
        // Poll for completion if needed
        if generationResponse.status == "processing" {
            return try await pollForMediaCompletion(
                generationId: generationResponse.id,
                authToken: authToken,
                mediaType: request.type.toMediaType(),
                onProgress: onProgress
            )
        }
        
        return ChatMediaItem(
            type: request.type.toChatMediaType(),
            url: generationResponse.mediaUrl,
            thumbnailURL: generationResponse.thumbnailUrl,
            generationState: GenerationState.completed
        ).toMediaItem()
    }
    
    /// Upload media data
    func uploadMediaData(
        data: Data,
        fileName: String,
        mimeType: String,
        onProgress: @escaping (Double) -> Void
    ) async throws -> String {
        
        guard let authToken = await getAuthToken() else {
            throw ChatError(code: .authenticationError, message: "Authentication failed")
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            throw ChatError(code: .authenticationError, message: "User not authenticated")
        }
        
        var request = URLRequest(url: URL(string: Config.uploadEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue(userId, forHTTPHeaderField: "x-user-uid")
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let httpBody = createMultipartBody(
            data: data,
            fileName: fileName,
            mimeType: mimeType,
            boundary: boundary
        )
        
        let (responseData, response) = try await urlSession.upload(for: request, from: httpBody)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatError(code: .serverError, message: "Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ChatError(code: .serverError, message: "Upload failed: \(httpResponse.statusCode)")
        }
        
        let uploadResponse = try jsonDecoder.decode(UploadResponse.self, from: responseData)
        return uploadResponse.url
    }
    
    /// Poll for media generation completion
    func pollForMediaCompletion(
        generationId: String,
        authToken: String,
        mediaType: MediaType,
        onProgress: @escaping (Double) -> Void
    ) async throws -> MediaItem {
        
        // Calculate timeout and polling interval based on media type
        let (timeout, pollingInterval) = getTimeoutConfig(for: mediaType)
        let maxAttempts = Int(timeout / pollingInterval)
        
        let pollEndpoint = "\(Config.imageEndpoint)/status/\(generationId)"
        
        for attempt in 0..<maxAttempts {
            guard !Task.isCancelled else {
                throw CancellationError()
            }
            
            var request = URLRequest(url: URL(string: pollEndpoint)!)
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw ChatError(code: .serverError, message: "Failed to check generation status")
            }
            
            let statusResponse = try jsonDecoder.decode(MediaGenerationResponse.self, from: data)
            
            switch statusResponse.status {
            case "completed":
                return ChatMediaItem(
                    type: mediaType.toChatMediaType(),
                    url: statusResponse.mediaUrl,
                    thumbnailURL: statusResponse.thumbnailUrl,
                    generationState: GenerationState.completed
                ).toMediaItem()
            case "failed":
                throw ChatError(code: .serverError, message: "Media generation failed")
            case "processing":
                let progress = Double(attempt) / Double(maxAttempts)
                await MainActor.run {
                    onProgress(progress)
                }
                try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000)) // Dynamic polling interval
            default:
                break
            }
        }
        
        throw ChatError(code: .serverError, message: "\(mediaType.displayName) generation timed out after \(Int(timeout)) seconds")
    }
    
    func getAuthToken() async -> String? {
        guard let currentUser = Auth.auth().currentUser else { return nil }
        
        do {
            let result = try await currentUser.getIDToken()
            return result
        } catch {
            return nil
        }
    }
    
    /// Get timeout configuration based on media type
    private func getTimeoutConfig(for mediaType: MediaType) -> (timeout: TimeInterval, pollingInterval: TimeInterval) {
        switch mediaType {
        case .image:
            return (Config.imageGenerationTimeout, Config.imagePollingInterval)
        case .video:
            return (Config.videoGenerationTimeout, Config.videoPollingInterval)
        case .audio:
            return (Config.musicGenerationTimeout, Config.musicPollingInterval)
        case .document, .gif:
            return (Config.imageGenerationTimeout, Config.imagePollingInterval) // Default to image settings
        }
    }
    
    func buildHarmonyPrompt(userMessage: String, sessionId: String) -> String {
        let currentDate = DateFormatter().string(from: Date())
        
        return """
<|start|>system<|message|>You are Spekt AI, a creative writing assistant.
Knowledge cutoff: 2024-06
Current date: \(currentDate)
Reasoning: medium
# Valid channels: analysis, commentary, final. Channel must be included for every message.

# Tools Available
You have access to these synchronous tools for media generation:
- sync_image: Generate images from text descriptions (waits until complete)
- sync_video: Generate videos from text descriptions (waits until complete)
- sync_audio: Generate audio/music from text descriptions (waits until complete)

When users request media generation, use the appropriate tool with detailed prompts. These tools will block until generation is complete.<|end|><|start|>developer<|message|># Instructions
You are Spekt AI, a sophisticated creative writing assistant designed to help users with all aspects of creative writing including storytelling, character development, world-building, plot structure, dialogue, and creative brainstorming. You should be helpful, encouraging, and provide actionable advice while maintaining a supportive and inspiring tone.

When users ask for images, videos, or audio generation, use the sync tools to create the requested media. Always provide detailed, creative prompts to the generation tools.<|end|><|start|>user<|message|>\(userMessage)<|end|><|start|>assistant
"""
    }
    
    func createMultipartBody(data: Data, fileName: String, mimeType: String, boundary: String) -> Data {
        var body = Data()
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
    
    func mapError(_ error: Error) -> ChatError {
        if error is CancellationError {
            return ChatError(code: .unknownError, message: "Operation cancelled", retryable: false)
        }
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return ChatError(code: .networkError, message: "No internet connection")
            case .timedOut:
                return ChatError(code: .networkError, message: "Request timed out")
            default:
                return ChatError(code: .networkError, message: urlError.localizedDescription)
            }
        }
        
        return ChatError(code: .unknownError, message: error.localizedDescription)
    }
    
    /// Handle synchronous tool calls for media generation - polls until complete
    func handleSyncnoyToolCall(
        toolName: String,
        arguments: [String: Any],
        sessionId: String,
        onTokenReceived: @escaping (String, String) -> Void,
        messageId: String
    ) async {
        print("🔧 ChatService: Handling synchronous tool call: \(toolName)")
        
        guard let prompt = arguments["prompt"] as? String else {
            print("⚠️ ChatService: Missing prompt in tool call arguments")
            return
        }
        
        let generationType: GenerationType
        switch toolName {
        case "sync_image":
            generationType = .image
        case "sync_video":
            generationType = .video
        case "sync_audio":
            generationType = .music
        default:
            print("⚠️ ChatService: Unknown tool name: \(toolName)")
            return
        }
        
        // Show generation start message
        await MainActor.run {
            onTokenReceived(messageId, "\n\n🎨 Starting \(generationType.rawValue) generation...")
        }
        
        do {
            let request = GenerationRequest(
                type: generationType,
                prompt: prompt,
                parameters: .default
            )
            
            // Generate synchronously - this will poll until complete
            let mediaItem = try await generateMediaContentSynchronously(
                request: request,
                sessionId: sessionId,
                onProgress: { progress in
                    Task { @MainActor in
                        let percentage = Int(progress * 100)
                        onTokenReceived(messageId, "\n📊 Progress: \(percentage)%")
                    }
                }
            )
            
            // Send final result
            let mediaText = "\n\n✅ \(generationType.rawValue.capitalized) generation complete!"
            if !mediaItem.url.isEmpty {
                await MainActor.run {
                    onTokenReceived(messageId, "\(mediaText)\n🔗 URL: \(mediaItem.url)")
                }
            } else {
                await MainActor.run {
                    onTokenReceived(messageId, mediaText)
                }
            }
            
        } catch {
            print("❌ ChatService: Synchronous tool call failed: \(error)")
            await MainActor.run {
                onTokenReceived(messageId, "\n\n❌ Failed to generate \(generationType.rawValue): \(error.localizedDescription)")
            }
        }
    }
    
    /// Generate media content synchronously - polls until completion
    func generateMediaContentSynchronously(
        request: GenerationRequest,
        sessionId: String,
        onProgress: @escaping (Double) -> Void
    ) async throws -> MediaItem {
        
        guard let authToken = await getAuthToken() else {
            throw ChatError(code: .authenticationError, message: "Authentication failed")
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            throw ChatError(code: .authenticationError, message: "User not authenticated")
        }
        
        let endpoint: String
        switch request.type {
        case .image:
            endpoint = Config.imageEndpoint
        case .video:
            endpoint = Config.videoEndpoint
        case .music:
            endpoint = Config.musicEndpoint
        case .text:
            throw ChatError(code: .validationError, message: "Use chat completion for text generation")
        }
        
        let requestBody = MediaGenerationRequest(
            prompt: request.prompt,
            parameters: request.parameters,
            sessionId: sessionId
        )
        
        var urlRequest = URLRequest(url: URL(string: endpoint)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(userId, forHTTPHeaderField: "x-user-uid")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try jsonEncoder.encode(requestBody)
        
        print("🚀 ChatService: Starting synchronous \(request.type.rawValue) generation...")
        
        let (data, response) = try await urlSession.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatError(code: .serverError, message: "Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ChatError(code: .serverError, message: "Server error: \(httpResponse.statusCode)")
        }
        
        let generationResponse = try jsonDecoder.decode(MediaGenerationResponse.self, from: data)
        print("📦 ChatService: Initial response - ID: \(generationResponse.id), Status: \(generationResponse.status)")
        
        // If already completed, return immediately
        if generationResponse.status == "completed" {
            return ChatMediaItem(
                type: request.type.toChatMediaType(),
                url: generationResponse.mediaUrl,
                thumbnailURL: generationResponse.thumbnailUrl,
                generationState: GenerationState.completed
            ).toMediaItem()
        }
        
        // Poll synchronously until completion
        return try await pollUntilComplete(
            generationId: generationResponse.id,
            authToken: authToken,
            mediaType: request.type.toMediaType(),
            onProgress: onProgress
        )
    }
    
    /// Poll synchronously until media generation is complete
    func pollUntilComplete(
        generationId: String,
        authToken: String,
        mediaType: MediaType,
        onProgress: @escaping (Double) -> Void
    ) async throws -> MediaItem {
        
        // Calculate timeout and polling interval based on media type
        let (timeout, pollingInterval) = getTimeoutConfig(for: mediaType)
        let maxAttempts = Int(timeout / pollingInterval)
        
        let pollEndpoint = "\(Config.baseURL)/jobs/\(generationId)/status"
        print("🔄 ChatService: Starting synchronous polling for \(generationId)")
        
        for attempt in 0..<maxAttempts {
            guard !Task.isCancelled else {
                throw CancellationError()
            }
            
            var request = URLRequest(url: URL(string: pollEndpoint)!)
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ChatError(code: .serverError, message: "Invalid polling response")
            }
            
            guard httpResponse.statusCode == 200 else {
                print("⚠️ ChatService: Polling error \(httpResponse.statusCode) on attempt \(attempt + 1)")
                if attempt < 3 {  // Retry first few attempts
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                    continue
                }
                throw ChatError(code: .serverError, message: "Failed to check generation status: \(httpResponse.statusCode)")
            }
            
            let statusResponse = try jsonDecoder.decode(MediaGenerationResponse.self, from: data)
            print("📊 ChatService: Poll attempt \(attempt + 1) - Status: \(statusResponse.status)")
            
            switch statusResponse.status {
            case "completed":
                print("✅ ChatService: Generation completed after \(attempt + 1) attempts")
                return ChatMediaItem(
                    type: mediaType.toChatMediaType(),
                    url: statusResponse.mediaUrl,
                    thumbnailURL: statusResponse.thumbnailUrl,
                    generationState: GenerationState.completed
                ).toMediaItem()
            case "failed", "error":
                throw ChatError(code: .serverError, message: "Media generation failed")
            case "processing", "pending":
                let progress = min(0.9, Double(attempt) / Double(maxAttempts - 10))  // Cap at 90% until complete
                await MainActor.run {
                    onProgress(progress)
                }
                print("⏳ ChatService: Still processing... (\(Int(progress * 100))%)")
                try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000)) // Dynamic polling interval
            default:
                print("❓ ChatService: Unknown status: \(statusResponse.status)")
                try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
            }
        }
        
        throw ChatError(code: .serverError, message: "\(mediaType.displayName) generation timed out after \(Int(timeout)) seconds")
    }
}

// MARK: - Helper Extensions
// Type adapters are now in the model files

// MARK: - API Health Enum
enum APIHealth {
    case healthy
    case unhealthy
    case unknown
    
    var displayName: String {
        switch self {
        case .healthy: return "Healthy"
        case .unhealthy: return "Unhealthy"
        case .unknown: return "Unknown"
        }
    }
    
    var color: String {
        switch self {
        case .healthy: return "green"
        case .unhealthy: return "red"
        case .unknown: return "gray"
        }
    }
}

// MARK: - Request/Response Models
private struct ChatCompletionRequest: Codable {
    let messages: [ChatCompletionMessage]
    let sessionId: String
    let stream: Bool
    let parameters: GenerationParameters
}

private struct ChatCompletionMessage: Codable {
    let role: String
    let content: String
}

private struct MediaGenerationRequest: Codable {
    let prompt: String
    let parameters: GenerationParameters
    let sessionId: String
}

private struct UploadResponse: Codable {
    let url: String
}

private struct ChatCompletionResponse: Codable {
    let choices: [ChatChoice]
}

private struct ChatChoice: Codable {
    let delta: ChatDelta?
}

private struct ChatDelta: Codable {
    let content: String?
}

private struct MediaGenerationResponse: Codable {
    let id: String
    let status: String
    let mediaUrl: String?
    let thumbnailUrl: String?
}
