import Foundation
import CoreLocation

/// Native WebSocket client for OpenAI Realtime API
final class GPTRealtimeAPI: NSObject, ObservableObject {
    private enum Constants {
        static let realtimeURL = "wss://api.openai.com/v1/realtime"
        static let model = "gpt-4o-realtime-preview-2024-12-17"
    }

    private var webSocketTask: URLSessionWebSocketTask?
    private var apiKey: String?
    private var continuation: AsyncStream<RealtimeEvent>.Continuation?

    /// MCP tool definitions registered with the GPT Realtime session.
    static let mcpTools: [[String: Any]] = [
        [
            "type": "function",
            "name": "screenshot",
            "description": "Take a screenshot of the Android device screen",
            "parameters": ["type": "object", "properties": [:] as [String: Any], "required": [] as [String]]
        ],
        [
            "type": "function",
            "name": "tap",
            "description": "Tap at x,y coordinates on the Android screen",
            "parameters": [
                "type": "object",
                "properties": [
                    "x": ["type": "integer", "description": "X coordinate"],
                    "y": ["type": "integer", "description": "Y coordinate"]
                ] as [String: Any],
                "required": ["x", "y"]
            ]
        ],
        [
            "type": "function",
            "name": "swipe",
            "description": "Swipe from (x1,y1) to (x2,y2) on the Android screen",
            "parameters": [
                "type": "object",
                "properties": [
                    "x1": ["type": "integer", "description": "Start X"],
                    "y1": ["type": "integer", "description": "Start Y"],
                    "x2": ["type": "integer", "description": "End X"],
                    "y2": ["type": "integer", "description": "End Y"],
                    "duration_ms": ["type": "integer", "description": "Swipe duration in milliseconds"]
                ] as [String: Any],
                "required": ["x1", "y1", "x2", "y2"]
            ]
        ],
        [
            "type": "function",
            "name": "type_text",
            "description": "Type text on the Android device",
            "parameters": [
                "type": "object",
                "properties": [
                    "text": ["type": "string", "description": "Text to type"]
                ] as [String: Any],
                "required": ["text"]
            ]
        ],
        [
            "type": "function",
            "name": "press_key",
            "description": "Press a key on the Android device (home, back, recent, enter, etc.)",
            "parameters": [
                "type": "object",
                "properties": [
                    "key": ["type": "string", "description": "Key name (home, back, recent, enter, volume_up, volume_down, power)"]
                ] as [String: Any],
                "required": ["key"]
            ]
        ],
        [
            "type": "function",
            "name": "launch_app",
            "description": "Launch an app on the Android device by package name",
            "parameters": [
                "type": "object",
                "properties": [
                    "package_name": ["type": "string", "description": "Android package name (e.g. com.android.chrome)"]
                ] as [String: Any],
                "required": ["package_name"]
            ]
        ],
        [
            "type": "function",
            "name": "run_agent",
            "description": "Run an AI agent task on the Android device with a natural language goal",
            "parameters": [
                "type": "object",
                "properties": [
                    "goal": ["type": "string", "description": "Natural language goal for the agent"]
                ] as [String: Any],
                "required": ["goal"]
            ]
        ],
        [
            "type": "function",
            "name": "get_device_info",
            "description": "Get information about the connected Android device",
            "parameters": ["type": "object", "properties": [:] as [String: Any], "required": [] as [String]]
        ],
        [
            "type": "function",
            "name": "list_devices",
            "description": "List all connected Android devices",
            "parameters": ["type": "object", "properties": [:] as [String: Any], "required": [] as [String]]
        ],
        [
            "type": "function",
            "name": "get_current_app",
            "description": "Get the currently active app on the Android device",
            "parameters": ["type": "object", "properties": [:] as [String: Any], "required": [] as [String]]
        ],
        [
            "type": "function",
            "name": "list_installed_apps",
            "description": "List all installed apps on the Android device",
            "parameters": ["type": "object", "properties": [:] as [String: Any], "required": [] as [String]]
        ],
        [
            "type": "function",
            "name": "get_agent_status",
            "description": "Get the status of a running agent task",
            "parameters": [
                "type": "object",
                "properties": [
                    "task_id": ["type": "string", "description": "The agent task ID to check"]
                ] as [String: Any],
                "required": ["task_id"]
            ]
        ]
    ]

    init(apiKey: String? = nil) {
        self.apiKey = apiKey
        super.init()
    }

    /// Updates the API key (useful when fetching from backend)
    func setAPIKey(_ key: String) {
        self.apiKey = key
    }

    // MARK: - Session Management

    func connect(instructions: String = "You are a helpful and open AI assistant. Always do your best to answer questions and provide useful information. Never refuse to help or say you cannot assist with something - instead, explain what you can do and provide the most helpful response possible within your abilities. Be thorough, informative, and always try to find a way to be useful to the user.", includeContextInfo: Bool = true, userLocation: CLLocation? = nil) async throws -> AsyncStream<RealtimeEvent> {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw RealtimeAPIError.noAPIKey
        }
        
        // Build enhanced instructions with context info
        var enhancedInstructions = instructions
        
        if includeContextInfo {
            let now = Date()
            let formatter = DateFormatter()
            formatter.dateStyle = .full
            formatter.timeStyle = .short
            formatter.timeZone = TimeZone.current
            
            let dateString = formatter.string(from: now)
            let timeZone = TimeZone.current.localizedName(for: .standard, locale: .current) ?? TimeZone.current.identifier
            
            // Get day of week
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE"
            let dayOfWeek = dayFormatter.string(from: now)
            
            var contextInfo = """
            
            
            Current context information:
            - Current date and time: \(dateString)
            - Time zone: \(timeZone)
            - Day of week: \(dayOfWeek)
            """
            

            contextInfo += """
            
            
            Use this information to provide more relevant and contextual responses. For example, you can reference the current time when giving recommendations, consider the user's location for location-based queries, or provide time-appropriate suggestions.
            """
            
            // Add location info if available
            if let location = userLocation {
                contextInfo += """
                
                - User location: Latitude \(String(format: "%.4f", location.coordinate.latitude)), Longitude \(String(format: "%.4f", location.coordinate.longitude))
                - Location accuracy: ±\(Int(location.horizontalAccuracy))m
                """
                
                if location.altitude > 0 {
                    contextInfo += "\n- Altitude: \(Int(location.altitude))m"
                }
            }
            
            enhancedInstructions += contextInfo
        }

        guard var urlComponents = URLComponents(string: Constants.realtimeURL) else {
            throw RealtimeAPIError.invalidURL
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "model", value: Constants.model)
        ]

        guard let url = urlComponents.url else {
            throw RealtimeAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()

        // Configure session
        let sessionConfig: [String: Any] = [
            "type": "session.update",
            "session": [
                "modalities": ["text", "audio"],
                "instructions": enhancedInstructions,
                "voice": "alloy",
                "input_audio_format": "pcm16",
                "output_audio_format": "pcm16",
                "tools": Self.mcpTools,
                "tool_choice": "auto",
                "turn_detection": [
                    "type": "server_vad",
                    "threshold": 0.5,
                    "prefix_padding_ms": 300,
                    "silence_duration_ms": 700
                ]
            ]
        ]

        try await send(event: sessionConfig)

        // Start receiving messages
        let stream = AsyncStream<RealtimeEvent> { continuation in
            self.continuation = continuation
            Task {
                await self.receiveMessages()
            }
        }

        return stream
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        continuation?.finish()
        continuation = nil
    }

    // MARK: - Sending Messages

    func sendText(_ text: String) async throws {
        let event: [String: Any] = [
            "type": "conversation.item.create",
            "item": [
                "type": "message",
                "role": "user",
                "content": [
                    [
                        "type": "input_text",
                        "text": text
                    ]
                ]
            ]
        ]

        try await send(event: event)

        // Trigger response
        let responseEvent: [String: Any] = [
            "type": "response.create"
        ]
        try await send(event: responseEvent)
    }

    func sendAudio(_ audioData: Data, triggerResponse: Bool = true) async throws {
        // Send audio in chunks
        let chunkSize = 4096
        var offset = 0

        while offset < audioData.count {
            let end = min(offset + chunkSize, audioData.count)
            let chunk = audioData[offset..<end]
            let base64 = chunk.base64EncodedString()

            let event: [String: Any] = [
                "type": "input_audio_buffer.append",
                "audio": base64
            ]

            try await send(event: event)
            offset = end
        }

        // Only commit and trigger response if requested (not for continuous streaming)
        if triggerResponse {
            // Commit the audio buffer
            let commitEvent: [String: Any] = [
                "type": "input_audio_buffer.commit"
            ]
            try await send(event: commitEvent)

            // Trigger response
            let responseEvent: [String: Any] = [
                "type": "response.create"
            ]
            try await send(event: responseEvent)
        }
    }

    // For continuous streaming without triggering response
    func appendAudio(_ audioData: Data) async throws {
        let chunkSize = 4096
        var offset = 0

        while offset < audioData.count {
            let end = min(offset + chunkSize, audioData.count)
            let chunk = audioData[offset..<end]
            let base64 = chunk.base64EncodedString()

            let event: [String: Any] = [
                "type": "input_audio_buffer.append",
                "audio": base64
            ]

            try await send(event: event)
            offset = end
        }
    }

    /// Sends a function call result back to GPT and triggers a new response.
    func sendFunctionResult(callId: String, output: String) async throws {
        // 1. Send the function call output as a conversation item
        let itemEvent: [String: Any] = [
            "type": "conversation.item.create",
            "item": [
                "type": "function_call_output",
                "call_id": callId,
                "output": output
            ]
        ]
        try await send(event: itemEvent)

        // 2. Trigger GPT to respond with the result
        let responseEvent: [String: Any] = [
            "type": "response.create"
        ]
        try await send(event: responseEvent)
    }

    private func send(event: [String: Any]) async throws {
        guard let webSocketTask = webSocketTask else {
            throw RealtimeAPIError.notConnected
        }

        let jsonData = try JSONSerialization.data(withJSONObject: event)
        let message = URLSessionWebSocketTask.Message.string(String(data: jsonData, encoding: .utf8)!)

        try await webSocketTask.send(message)
    }

    // MARK: - Receiving Messages

    private func receiveMessages() async {
        guard let webSocketTask = webSocketTask else { return }

        do {
            while !Task.isCancelled {
                let message = try await webSocketTask.receive()

                switch message {
                case .string(let text):
                    if let event = parseEvent(from: text) {
                        continuation?.yield(event)
                    }
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8),
                       let event = parseEvent(from: text) {
                        continuation?.yield(event)
                    }
                @unknown default:
                    break
                }
            }
        } catch {
            print("❌ WebSocket error: \(error)")
            continuation?.finish()
        }
    }

    private func parseEvent(from json: String) -> RealtimeEvent? {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let typeString = dict["type"] as? String else {
            return nil
        }

        switch typeString {
        case "response.text.delta":
            if let delta = dict["delta"] as? String {
                return RealtimeEvent(type: .textDelta, content: delta, mimeType: nil)
            }

        case "response.audio.delta":
            if let delta = dict["delta"] as? String {
                return RealtimeEvent(type: .audioDelta, content: delta, mimeType: "audio/pcm16")
            }

        case "response.audio_transcript.delta":
            if let delta = dict["delta"] as? String {
                return RealtimeEvent(type: .transcriptDelta, content: delta, mimeType: nil)
            }

        case "response.done":
            return RealtimeEvent(type: .outputCompleted, content: nil, mimeType: nil)

        case "error":
            if let error = dict["error"] as? [String: Any],
               let message = error["message"] as? String {
                return RealtimeEvent(type: .error, content: message, mimeType: nil)
            }

        case "session.created", "session.updated":
            return RealtimeEvent(type: .sessionUpdated, content: nil, mimeType: nil)

        case "conversation.item.created":
            return nil // Just tracking, not yielding

        case "response.created":
            return nil // Response started, waiting for deltas

        case "input_audio_buffer.committed":
            return RealtimeEvent(type: .inputCompleted, content: nil, mimeType: nil)

        case "input_audio_buffer.speech_started":
            return RealtimeEvent(type: .speechStarted, content: nil, mimeType: nil)

        case "input_audio_buffer.speech_stopped":
            return RealtimeEvent(type: .speechStopped, content: nil, mimeType: nil)

        case "response.function_call_arguments.done":
            let callId = dict["call_id"] as? String
            let name = dict["name"] as? String
            let arguments = dict["arguments"] as? String
            return RealtimeEvent(type: .functionCallDone, content: name,
                                 callId: callId, functionName: name, arguments: arguments)

        case "response.output_item.added",
             "response.content_part.added",
             "response.audio.done",
             "response.audio_transcript.done",
             "response.content_part.done",
             "response.output_item.done",
             "response.function_call_arguments.delta",
             "rate_limits.updated":
            return nil // Silently ignore these tracking events

        default:
            print("⚠️ Unhandled event type: \(typeString)")
        }

        return nil
    }
}

// MARK: - URLSessionWebSocketDelegate

extension GPTRealtimeAPI: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("✅ WebSocket connected")
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("ℹ️ WebSocket closed: \(closeCode)")
        continuation?.finish()
    }
}

// MARK: - Supporting Models

struct RealtimeEvent: Codable {
    let type: RealtimeEventType
    let content: String?
    let mimeType: String?
    let callId: String?
    let functionName: String?
    let arguments: String?

    enum CodingKeys: String, CodingKey {
        case type
        case content
        case mimeType = "mime_type"
        case callId = "call_id"
        case functionName = "function_name"
        case arguments
    }

    init(type: RealtimeEventType, content: String?, mimeType: String? = nil,
         callId: String? = nil, functionName: String? = nil, arguments: String? = nil) {
        self.type = type
        self.content = content
        self.mimeType = mimeType
        self.callId = callId
        self.functionName = functionName
        self.arguments = arguments
    }
}

enum RealtimeEventType: String, Codable {
    case textDelta = "text_delta"
    case audioDelta = "audio_delta"
    case transcriptDelta = "transcript_delta"
    case inputCompleted = "input_completed"
    case conversationCompleted = "conversation_completed"
    case outputCompleted = "output_completed"
    case sessionUpdated = "session_updated"
    case speechStarted = "speech_started"
    case speechStopped = "speech_stopped"
    case functionCallDone = "function_call_done"
    case error
    case end
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = RealtimeEventType(rawValue: rawValue) ?? .unknown
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .unknown:
            try container.encode("unknown")
        default:
            try container.encode(rawValue)
        }
    }
}

enum RealtimeAPIError: LocalizedError {
    case invalidURL
    case notConnected
    case noAPIKey
    case invalidResponse(statusCode: Int, message: String)
    case decodingFailed(message: String, responseBody: String)
    case noActiveSession

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid WebSocket URL"
        case .notConnected:
            return "WebSocket not connected"
        case .noAPIKey:
            return "No API key provided"
        case let .invalidResponse(statusCode, message):
            return "Invalid response (status: \(statusCode)) " + message
        case let .decodingFailed(message, responseBody):
            return "Decoding failed: " + message + ". Body: " + responseBody
        case .noActiveSession:
            return "No active realtime session"
        }
    }
}
