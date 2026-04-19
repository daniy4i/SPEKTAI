//
//  BackgroundRealtimeManager.swift
//  lannaapp
//
//  Manages realtime sessions that can run in background
//

import Foundation
import AVFoundation
import Combine
import CoreLocation

@MainActor
class BackgroundRealtimeManager: NSObject, ObservableObject {
    static let shared = BackgroundRealtimeManager()

    @Published private(set) var isSessionActive = false
    @Published private(set) var lastTranscript = ""

    private var realtimeAPI: GPTRealtimeAPI?
    private var keyService = OpenAIKeyService()
    private var eventStreamTask: Task<Void, Never>?
    private var audioTask: Task<Void, Never>?
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var audioChunksBuffer: [Data] = []
    private var locationManager: CLLocationManager?

    private override init() {
        locationManager = CLLocationManager()
        super.init()
    }

    // Start a background realtime session
    func startBackgroundSession() async {
        guard !isSessionActive else {
            print("⚠️ Background session already active")
            return
        }

        print("🎙️ Starting background realtime session...")

        do {
            // Get API key
            guard let userId = AuthService.shared.user?.uid else {
                print("❌ No user logged in")
                return
            }

            let apiKey = try await keyService.getAPIKey(forUserId: userId)

            // Initialize realtime API
            let api = GPTRealtimeAPI()
            api.setAPIKey(apiKey)
            self.realtimeAPI = api

            // Configure audio session like a phone call - persistent and keeps microphone active
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers, .duckOthers]
            )
            try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
            print("✅ Audio session configured (call-like mode)")

            // Get context information
            let contextInfo = await getContextInfo()

            // Connect to OpenAI with context
            let instructions = """
            You are a helpful AI assistant. Respond naturally and conversationally. Keep responses concise.

            Current context:
            \(contextInfo)

            Use this context to provide relevant and timely responses. For example, if the user asks about the weather or time, you already know their location and current time.
            """

            let stream = try await api.connect(instructions: instructions)

            isSessionActive = true

            // Handle events
            eventStreamTask = Task {
                await handleEventStream(stream)
            }

            // Start continuous audio streaming
            audioTask = Task {
                await streamAudio()
            }

            // Send initial greeting
            try await api.sendText("Say a brief friendly greeting to let me know you're ready.")

            print("✅ Background realtime session started")

        } catch {
            print("❌ Failed to start background session: \(error)")
            isSessionActive = false
        }
    }

    // Stop background session
    func stopBackgroundSession() {
        print("🛑 Stopping background realtime session")

        audioTask?.cancel()
        audioTask = nil

        eventStreamTask?.cancel()
        eventStreamTask = nil

        audioRecorder?.stop()
        audioRecorder = nil

        realtimeAPI?.disconnect()
        realtimeAPI = nil

        isSessionActive = false
    }

    // Handle realtime events
    private func handleEventStream(_ stream: AsyncStream<RealtimeEvent>) async {
        for await event in stream {
            switch event.type {
            case .transcriptDelta:
                if let content = event.content {
                    lastTranscript += content
                }

            case .audioDelta:
                // Buffer audio chunks
                if let audioBase64 = event.content,
                   let audioData = Data(base64Encoded: audioBase64) {
                    audioChunksBuffer.append(audioData)
                }

            case .outputCompleted:
                if !lastTranscript.isEmpty {
                    print("🤖 Assistant: \(lastTranscript)")
                    lastTranscript = ""
                }

                // Play buffered audio
                if !audioChunksBuffer.isEmpty {
                    await playBufferedAudio()
                }

            case .functionCallDone:
                if let callId = event.callId,
                   let name = event.functionName {
                    let arguments = event.arguments
                    let api = self.realtimeAPI
                    Task {
                        await self.handleFunctionCall(callId: callId, name: name, arguments: arguments, api: api)
                    }
                }

            case .speechStarted:
                print("🎤 User started speaking")

            case .speechStopped:
                print("🎤 User stopped speaking")

            case .error:
                print("❌ Realtime error: \(event.content ?? "Unknown")")

            default:
                break
            }
        }
    }

    // Handle MCP function calls from GPT
    private func handleFunctionCall(callId: String, name: String, arguments: String?, api: GPTRealtimeAPI?) async {
        print("🔧 MCP tool call: \(name)(\(arguments ?? "{}"))")

        do {
            // Parse arguments JSON
            var args: [String: Any] = [:]
            if let argsString = arguments,
               let argsData = argsString.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] {
                args = parsed
            }

            // Call the MCP server
            let result = try await MCPService.shared.callTool(name: name, arguments: args)
            let output = String(data: try JSONSerialization.data(withJSONObject: result), encoding: .utf8) ?? "{}"

            print("✅ MCP result for \(name): \(output.prefix(200))")

            // Send result back to GPT
            try await api?.sendFunctionResult(callId: callId, output: output)
        } catch {
            print("❌ MCP tool call failed: \(error)")
            let errorOutput = "{\"error\": \"\(error.localizedDescription)\"}"
            try? await api?.sendFunctionResult(callId: callId, output: errorOutput)
        }
    }

    // Play accumulated audio chunks WITHOUT stopping recording
    private func playBufferedAudio() async {
        guard !audioChunksBuffer.isEmpty else { return }

        print("🔊 Playing AI response...")

        // Combine all buffered chunks
        var combinedAudio = Data()
        for chunk in audioChunksBuffer {
            combinedAudio.append(chunk)
        }
        audioChunksBuffer.removeAll()

        // Create WAV file from PCM data
        let wavData = createWAVFile(from: combinedAudio)

        do {
            // Keep recording active - just play audio simultaneously (like a phone call)
            audioPlayer = try AVAudioPlayer(data: wavData)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            // Wait for playback to finish
            while audioPlayer?.isPlaying == true {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }

            print("✅ Audio playback completed, mic still active")

        } catch {
            print("❌ Failed to play audio: \(error)")
        }
    }

    // Create WAV file from PCM16 data
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
        wavFile.append(withUnsafeBytes(of: (36 + dataSize).littleEndian) { Data($0) })
        wavFile.append("WAVE".data(using: .ascii)!)

        // fmt chunk
        wavFile.append("fmt ".data(using: .ascii)!)
        wavFile.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        wavFile.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
        wavFile.append(withUnsafeBytes(of: numChannels.littleEndian) { Data($0) })
        wavFile.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        wavFile.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        wavFile.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        wavFile.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })

        // data chunk
        wavFile.append("data".data(using: .ascii)!)
        wavFile.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
        wavFile.append(pcmData)

        return wavFile
    }

    // Stream audio continuously in background
    private func streamAudio() async {
        print("🎙️ Starting audio recording...")

        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let audioFilename = documentsPath.appendingPathComponent("background_realtime.wav")

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

            guard audioRecorder?.record() == true else {
                print("❌ Failed to start recording")
                return
            }

            print("✅ Audio recording started")

            var lastSentSize = 0
            let minBufferSize = 24000 * 2 * 100 / 1000 // 100ms = 4800 bytes
            var chunkCount = 0

            while !Task.isCancelled && isSessionActive {
                try await Task.sleep(nanoseconds: 100_000_000)

                guard let recorder = audioRecorder, recorder.isRecording else {
                    print("⚠️ Recorder not recording")
                    continue
                }

                do {
                    let allAudioData = try Data(contentsOf: recorder.url)

                    // Strip WAV header (44 bytes)
                    let pcmData = allAudioData.count > 44 ? allAudioData.subdata(in: 44..<allAudioData.count) : Data()

                    if pcmData.count > lastSentSize + minBufferSize {
                        let newData = pcmData.subdata(in: lastSentSize..<pcmData.count)
                        try await realtimeAPI?.appendAudio(newData)
                        chunkCount += 1

                        if chunkCount % 10 == 0 { // Log every second
                            print("📤 Sent \(chunkCount) audio chunks (\(newData.count) bytes)")
                        }

                        lastSentSize = pcmData.count
                    }
                } catch {
                    print("⚠️ Audio streaming error: \(error)")
                }
            }

            print("🛑 Stopping audio recording (sent \(chunkCount) total chunks)")
            audioRecorder?.stop()

        } catch {
            print("❌ Failed to start audio streaming: \(error)")
        }
    }

    // Get contextual information for the session
    private func getContextInfo() async -> String {
        var context: [String] = []

        // Get current time
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm a"
        dateFormatter.timeZone = TimeZone.current
        let timeString = dateFormatter.string(from: Date())
        context.append("- Current time: \(timeString)")
        context.append("- Timezone: \(TimeZone.current.identifier)")

        // Get day period
        let hour = Calendar.current.component(.hour, from: Date())
        let dayPeriod: String
        switch hour {
        case 5..<12: dayPeriod = "morning"
        case 12..<17: dayPeriod = "afternoon"
        case 17..<21: dayPeriod = "evening"
        default: dayPeriod = "night"
        }
        context.append("- Time of day: \(dayPeriod)")

        // Get location if available
        if let location = locationManager?.location {
            let latitude = String(format: "%.4f", location.coordinate.latitude)
            let longitude = String(format: "%.4f", location.coordinate.longitude)
            context.append("- User location: \(latitude), \(longitude)")

            // Reverse geocode to get city/region
            let geocoder = CLGeocoder()
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                if let placemark = placemarks.first {
                    var locationParts: [String] = []
                    if let city = placemark.locality {
                        locationParts.append(city)
                    }
                    if let state = placemark.administrativeArea {
                        locationParts.append(state)
                    }
                    if let country = placemark.country {
                        locationParts.append(country)
                    }
                    if !locationParts.isEmpty {
                        context.append("- Location name: \(locationParts.joined(separator: ", "))")
                    }
                }
            } catch {
                print("⚠️ Could not reverse geocode location: \(error)")
            }
        } else {
            // Request location if not available
            locationManager?.requestWhenInUseAuthorization()
            locationManager?.requestLocation()
            context.append("- User location: Not available (permission may be needed)")
        }

        return context.joined(separator: "\n")
    }
}

// MARK: - CLLocationManagerDelegate
extension BackgroundRealtimeManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Location updated - will be used in next session
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("⚠️ Location error: \(error.localizedDescription)")
    }
}
