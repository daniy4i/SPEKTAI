import SwiftUI

#if os(iOS)
import AVFoundation

// MARK: - Voice Chat View

struct RealtimeChatView: View {
    @StateObject private var realtimeAPI = GPTRealtimeAPI()
    @StateObject private var keyService = OpenAIKeyService()
    @State private var messageText = ""
    @State private var messages: [RealtimeChatMessage] = []
    @State private var isRecording = false
    @State private var isSessionActive = false
    @State private var currentResponse = ""
    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var eventStream: AsyncStream<RealtimeEvent>?
    @State private var streamTask: Task<Void, Never>?
    @State private var isLoadingKey = false
    @State private var continuousAudioTask: Task<Void, Never>?
    @State private var audioChunksBuffer: [Data] = []
    @State private var isPlayingAudio = false

    var body: some View {
        VStack {
            header

            messagesScrollView

            inputControls
        }
        .onAppear {
            // Auto-start session with VAD mode if not active
            if !isSessionActive && !isLoadingKey {
                print("🟢 RealtimeChatView appeared - starting session")
                Task {
                    await startSession()
                    // Auto-enable continuous mode after session starts
                    if isSessionActive {
                        print("✅ Session active, starting continuous mode")
                        startContinuousMode()
                    } else {
                        print("❌ Session failed to start")
                    }
                }
            } else {
                print("ℹ️ RealtimeChatView appeared but session already active or loading")
            }
        }
        .onDisappear {
            print("🔴 RealtimeChatView disappeared - ending session")
            endSession()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Spekt AI")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button(isSessionActive ? "End Session" : (isLoadingKey ? "Connecting..." : "Start Session")) {
                    if isSessionActive {
                        endSession()
                    } else {
                        Task {
                            await startSession()
                            if isSessionActive {
                                startContinuousMode()
                            }
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoadingKey)
            }

            if isSessionActive {
                HStack {
                    Image(systemName: "waveform.circle.fill")
                        .foregroundColor(.green)

                    Text("Continuous Mode (VAD) Active")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }

    // MARK: - Messages List

    private var messagesScrollView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(messages) { message in
                    RealtimeMessageBubble(message: message)
                }

                if !currentResponse.isEmpty {
                    RealtimeMessageBubble(
                        message: .init(
                            id: UUID().uuidString,
                            text: currentResponse,
                            isUser: false,
                            timestamp: Date()
                        )
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Input Controls

    private var inputControls: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Type a message...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(!isSessionActive)

                Button("Send") {
                    Task { await sendTextMessage() }
                }
                .disabled(messageText.isEmpty || !isSessionActive)
            }

            if isSessionActive {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundColor(.green)

                    Text("Voice Active Detection enabled - just speak naturally")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }

    // MARK: - Session Management

    @MainActor
    private func startSession() async {
        guard !isSessionActive, !isLoadingKey else { return }

        isLoadingKey = true
        defer { isLoadingKey = false }

        do {
            // Fetch API key from backend
            guard let userId = AuthService.shared.user?.uid else {
                print("❌ No user logged in")
                return
            }

            print("🔑 Fetching API key from backend...")
            let apiKey = try await keyService.getAPIKey(forUserId: userId)
            realtimeAPI.setAPIKey(apiKey)

            // Connect to OpenAI
            let stream = try await realtimeAPI.connect(
                instructions: "You are a helpful AI assistant. Respond naturally and conversationally. Keep responses concise."
            )
            eventStream = stream
            isSessionActive = true

            // Start listening to events
            streamTask = Task {
                await handleEventStream(stream)
            }

            // Send initial greeting
            try await realtimeAPI.sendText("Say a brief friendly greeting to let me know you're ready.")

            print("✅ Session started")
        } catch {
            print("❌ Failed to start session: \(error.localizedDescription)")
            currentResponse = "Failed to connect: \(error.localizedDescription)"
        }
    }

    private func endSession() {
        stopContinuousMode()
        streamTask?.cancel()
        streamTask = nil
        realtimeAPI.disconnect()
        isSessionActive = false
        eventStream = nil
        print("ℹ️ Session ended")
    }

    private func handleEventStream(_ stream: AsyncStream<RealtimeEvent>) async {
        for await event in stream {
            await MainActor.run {
                handleEvent(event)
            }
        }
    }

    @MainActor
    private func handleEvent(_ event: RealtimeEvent) {
        switch event.type {
        case .textDelta:
            if let content = event.content {
                currentResponse += content
            }

        case .transcriptDelta:
            if let content = event.content {
                currentResponse += content
            }

        case .audioDelta:
            if let audioBase64 = event.content,
               let audioData = Data(base64Encoded: audioBase64) {
                audioChunksBuffer.append(audioData)
            }

        case .outputCompleted:
            if !audioChunksBuffer.isEmpty {
                Task { await playBufferedAudio() }
            }
            finalizeAssistantMessage()

        case .inputCompleted:
            break

        case .functionCallDone:
            if let callId = event.callId,
               let name = event.functionName {
                let arguments = event.arguments
                let api = realtimeAPI
                Task {
                    await handleFunctionCall(callId: callId, name: name, arguments: arguments, api: api)
                }
            }

        case .speechStarted:
            print("🎤 Speech started")

        case .speechStopped:
            print("🎤 Speech stopped")

        case .error:
            currentResponse = "Error: \(event.content ?? "Unknown error")"
            finalizeAssistantMessage()

        case .sessionUpdated:
            print("✅ Session configured")

        default:
            break
        }
    }

    // MARK: - MCP Function Call Handling

    private func handleFunctionCall(callId: String, name: String, arguments: String?, api: GPTRealtimeAPI) async {
        print("🔧 MCP tool call: \(name)(\(arguments ?? "{}"))")

        do {
            var args: [String: Any] = [:]
            if let argsString = arguments,
               let argsData = argsString.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] {
                args = parsed
            }

            let result = try await MCPService.shared.callTool(name: name, arguments: args)
            let output = String(data: try JSONSerialization.data(withJSONObject: result), encoding: .utf8) ?? "{}"

            print("✅ MCP result for \(name): \(output.prefix(200))")

            try await api.sendFunctionResult(callId: callId, output: output)
        } catch {
            print("❌ MCP tool call failed: \(error)")
            let errorOutput = "{\"error\": \"\(error.localizedDescription)\"}"
            try? await api.sendFunctionResult(callId: callId, output: errorOutput)
        }
    }

    // MARK: - Text Messaging

    @MainActor
    private func sendTextMessage() async {
        let outgoing = messageText
        guard !outgoing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        messageText = ""

        appendUserMessage(text: outgoing)

        do {
            try await realtimeAPI.sendText(outgoing)
        } catch {
            currentResponse = "Error: \(error.localizedDescription)"
            finalizeAssistantMessage()
        }
    }

    // MARK: - Audio Messaging (Disabled in VAD-only mode)

    @MainActor
    private func sendAudioMessage(audioData: Data) async {
        // This function is no longer used in VAD-only mode
        // Audio is continuously streamed via VAD instead
    }

    private func appendUserMessage(text: String) {
        let userMessage = RealtimeChatMessage(
            id: UUID().uuidString,
            text: text,
            isUser: true,
            timestamp: Date()
        )
        messages.append(userMessage)
    }

    @MainActor
    private func finalizeAssistantMessage() {
        guard !currentResponse.isEmpty else { return }
        let assistantMessage = RealtimeChatMessage(
            id: UUID().uuidString,
            text: currentResponse,
            isUser: false,
            timestamp: Date()
        )
        messages.append(assistantMessage)
        currentResponse = ""
    }

    // MARK: - Recording Helpers (Disabled in VAD-only mode)
    // Manual recording is not used - VAD handles all audio streaming

    // MARK: - Continuous Mode (VAD)

    private func startContinuousMode() {
        guard isSessionActive else { return }

        print("🎙️ Starting continuous mode with server-side VAD")

        // Start continuous audio capture
        continuousAudioTask = Task {
            await streamContinuousAudio()
        }
    }

    private func stopContinuousMode() {
        print("🛑 Stopping continuous mode")
        continuousAudioTask?.cancel()
        continuousAudioTask = nil
        audioRecorder?.stop()
        audioRecorder = nil
    }

    private func streamContinuousAudio() async {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)

            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let audioFilename = documentsPath.appendingPathComponent("continuous_stream.wav")

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 24000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false
            ]

            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            var audioBuffer = Data()
            var lastSentSize = 0
            let minBufferSize = 24000 * 2 * 100 / 1000 // 100ms at 24kHz, 16-bit = 4800 bytes

            // Stream audio in chunks continuously - server VAD will detect speech
            while !Task.isCancelled {
                try await Task.sleep(nanoseconds: 100_000_000) // Check every 100ms

                if let recorder = audioRecorder, recorder.isRecording {
                    do {
                        // Read all recorded audio
                        let allAudioData = try Data(contentsOf: recorder.url)
                        let pcmData = try convertToPCM16(allAudioData)

                        // Only send new data since last send
                        if pcmData.count > lastSentSize {
                            let newData = pcmData.subdata(in: lastSentSize..<pcmData.count)
                            audioBuffer.append(newData)

                            // Send when we have at least 100ms of audio
                            if audioBuffer.count >= minBufferSize {
                                try await realtimeAPI.appendAudio(audioBuffer)
                                lastSentSize = pcmData.count
                                audioBuffer = Data() // Clear buffer after sending
                            }
                        }
                    } catch {
                        print("⚠️ Error sending audio chunk: \(error)")
                    }
                }
            }

            // Send any remaining buffer
            if !audioBuffer.isEmpty {
                try? await realtimeAPI.appendAudio(audioBuffer)
            }

            audioRecorder?.stop()
        } catch {
            print("❌ Failed to start continuous audio: \(error)")
        }
    }

    // MARK: - Audio Processing

    private func convertToPCM16(_ audioData: Data) throws -> Data {
        // If already WAV PCM16, strip the header (44 bytes typically)
        if audioData.count > 44 {
            return audioData.subdata(in: 44..<audioData.count)
        }
        return audioData
    }

    @MainActor
    private func playBufferedAudio() async {
        guard !audioChunksBuffer.isEmpty, !isPlayingAudio else { return }

        isPlayingAudio = true

        // Pause recording during playback if in continuous mode
        let wasRecording = audioRecorder?.isRecording ?? false
        if wasRecording {
            audioRecorder?.pause()
        }

        // Combine all buffered chunks
        var combinedAudio = Data()
        for chunk in audioChunksBuffer {
            combinedAudio.append(chunk)
        }
        audioChunksBuffer.removeAll()

        // PCM16 data needs to be wrapped in a WAV container to play
        let wavData = createWAVFile(from: combinedAudio)

        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Use playAndRecord to avoid session conflicts in continuous mode
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)

            audioPlayer = try AVAudioPlayer(data: wavData)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            // Wait for playback to finish
            while audioPlayer?.isPlaying == true {
                try? await Task.sleep(nanoseconds: 100_000_000) // Check every 100ms
            }

            // Small delay before resuming recording
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms delay
        } catch {
            print("❌ Failed to play audio: \(error)")
        }

        // Resume recording if it was active (continuous mode is always on)
        if wasRecording {
            audioRecorder?.record()
        }

        isPlayingAudio = false
    }

    private func createWAVFile(from pcmData: Data) -> Data {
        var wavFile = Data()

        let sampleRate: UInt32 = 24000
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = sampleRate * UInt32(numChannels * bitsPerSample / 8)
        let blockAlign = numChannels * bitsPerSample / 8
        let dataSize = UInt32(pcmData.count)

        // RIFF header
        wavFile.append("RIFF".data(using: .ascii)!)
        wavFile.append(UInt32(36 + dataSize).littleEndianData)
        wavFile.append("WAVE".data(using: .ascii)!)

        // fmt chunk
        wavFile.append("fmt ".data(using: .ascii)!)
        wavFile.append(UInt32(16).littleEndianData) // Chunk size
        wavFile.append(UInt16(1).littleEndianData) // Audio format (PCM)
        wavFile.append(numChannels.littleEndianData)
        wavFile.append(sampleRate.littleEndianData)
        wavFile.append(byteRate.littleEndianData)
        wavFile.append(blockAlign.littleEndianData)
        wavFile.append(bitsPerSample.littleEndianData)

        // data chunk
        wavFile.append("data".data(using: .ascii)!)
        wavFile.append(dataSize.littleEndianData)
        wavFile.append(pcmData)

        return wavFile
    }
}

// MARK: - Supporting Types

struct RealtimeChatMessage: Identifiable {
    let id: String
    let text: String
    let isUser: Bool
    let timestamp: Date
}

struct RealtimeMessageBubble: View {
    let message: RealtimeChatMessage

    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                Text(message.text)
                    .padding(12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            } else {
                Text(message.text)
                    .padding(12)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
                Spacer()
            }
        }
    }
}

// MARK: - Extensions

extension FixedWidthInteger {
    var littleEndianData: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<Self>.size)
    }
}

#Preview {
    NavigationView {
        RealtimeChatView()
            .navigationTitle("Spekt AI Voice")
    }
}

#else

struct RealtimeChatView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Voice chat is currently available on iOS only.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
#endif
