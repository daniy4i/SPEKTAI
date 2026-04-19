//
//  VoiceMemoView_iOS.swift
//  lannaapp
//
//  Created by Assistant on 01/23/2025.
//

import SwiftUI
import AVFoundation
import FirebaseStorage
import FirebaseAuth

struct VoiceMemoView_iOS: View {
    @StateObject private var listenRecorder = ListenModeRecorder()
    @StateObject private var voiceToText = VoiceToTextService()
    @StateObject private var conversationService = ConversationService()
    @StateObject private var headsetDetection = HeadsetDetectionService.shared
    @StateObject private var microphoneService = MicrophoneSelectionService.shared
    @Environment(\.dismiss) private var dismiss

    let project: Project?
    @State private var conversationId: String?
    @State private var isCreatingConversation = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var audioLevel: Float = 0
    @State private var levelTimer: Timer?
    @State private var hasRecordedAudio = false
    @State private var isSaving = false
    @State private var showingMicrophoneSelection = false

    var formattedTime: String {
        let minutes = Int(listenRecorder.elapsedTime) / 60
        let seconds = Int(listenRecorder.elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        NavigationView {
            ZStack {
                DS.background
                    .ignoresSafeArea()

                VStack(spacing: DS.spacingXL) {
                    // Headset indicator
                    if headsetDetection.currentHeadsetType != .none {
                        HeadsetIndicator(
                            headsetType: headsetDetection.currentHeadsetType,
                            headsetName: headsetDetection.headsetName,
                            isRecording: listenRecorder.isRecording
                        )
                        .padding(.top, DS.spacingL)
                    }

                    Spacer()

                    // Waveform/Recording indicator
                    ZStack {
                        Circle()
                            .fill(DS.surface)
                            .frame(width: 200, height: 200)
                            .shadow(color: DS.shadow, radius: 10, x: 0, y: 5)

                        // Outer ring for headset indication
                        if headsetDetection.currentHeadsetType != .none {
                            Circle()
                                .stroke(
                                    headsetDetection.currentHeadsetType == .smartGlasses ? DS.primary : DS.secondary,
                                    lineWidth: 4
                                )
                                .frame(width: 210, height: 210)
                                .opacity(0.6)
                        }

                        if listenRecorder.isRecording {
                            Circle()
                                .stroke(
                                    headsetDetection.currentHeadsetType == .smartGlasses ? DS.primary : DS.secondary,
                                    lineWidth: 3
                                )
                                .frame(width: 200, height: 200)
                                .scaleEffect(listenRecorder.isPaused ? 1.0 : 1 + CGFloat(audioLevel) * 0.5)
                                .animation(.easeInOut(duration: 0.1), value: audioLevel)

                            if listenRecorder.isPaused {
                                Circle()
                                    .fill(DS.secondary)
                                    .frame(width: 80, height: 80)
                                    .opacity(0.8)
                            } else {
                                Circle()
                                    .fill(DS.error)
                                    .frame(width: 80, height: 80)
                                    .pulsatingAnimation()
                            }
                        } else {
                            Image(systemName: headsetDetection.currentHeadsetType != .none ? headsetDetection.currentHeadsetType.icon : "mic.fill")
                                .font(.system(size: 60))
                                .foregroundColor(headsetDetection.currentHeadsetType == .smartGlasses ? DS.primary : DS.textSecondary)
                        }
                    }

                    // Time display
                    Text(formattedTime)
                        .font(Typography.displayLarge)
                        .foregroundColor(DS.textPrimary)
                        .monospacedDigit()

                    // Transcription preview (if available)
                    transcriptionView

                    Spacer()

                    // Control buttons
                    HStack(spacing: DS.spacingXL) {
                        // Stop button (only show when recording)
                        if listenRecorder.isRecording {
                            Button(action: stopRecording) {
                                ZStack {
                                    Circle()
                                        .fill(DS.surface)
                                        .frame(width: 60, height: 60)
                                        .shadow(color: DS.shadow, radius: 5, x: 0, y: 2)

                                    Image(systemName: "stop.fill")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(DS.textSecondary)
                                }
                            }
                        } else {
                            // Cancel button (only show when not recording)
                            Button(action: cancelRecording) {
                                ZStack {
                                    Circle()
                                        .fill(DS.surface)
                                        .frame(width: 60, height: 60)
                                        .shadow(color: DS.shadow, radius: 5, x: 0, y: 2)

                                    Image(systemName: "xmark")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(DS.textSecondary)
                                }
                            }
                            .opacity(hasRecordedAudio ? 1 : 0.5)
                            .disabled(!hasRecordedAudio)
                        }

                        // Main record/pause/resume button
                        Button(action: toggleRecording) {
                            ZStack {
                                Circle()
                                    .fill(listenRecorder.isRecording ? (listenRecorder.isPaused ? DS.primary : DS.error) : DS.primary)
                                    .frame(width: 80, height: 80)
                                    .shadow(color: DS.shadow, radius: 8, x: 0, y: 4)

                                if listenRecorder.isRecording {
                                    if listenRecorder.isPaused {
                                        // Play icon for resume
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 32, weight: .semibold))
                                            .foregroundColor(.white)
                                    } else {
                                        // Pause icon
                                        Image(systemName: "pause.fill")
                                            .font(.system(size: 32, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                } else {
                                    // Record icon (microphone)
                                    Image(systemName: "mic.fill")
                                        .font(.system(size: 32, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .scaleEffect(listenRecorder.isRecording ? 1.0 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: listenRecorder.isRecording)

                        // Done button (only when recording is stopped and we have audio)
                        Button(action: {
                            Task {
                                await saveRecording()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(DS.success)
                                    .frame(width: 60, height: 60)
                                    .shadow(color: DS.shadow, radius: 5, x: 0, y: 2)

                                Image(systemName: "checkmark")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .opacity((hasRecordedAudio || (listenRecorder.isRecording && listenRecorder.elapsedTime > 0)) ? 1 : 0.5)
                        .disabled((!hasRecordedAudio && !(listenRecorder.isRecording && listenRecorder.elapsedTime > 0)) || isSaving)
                        .overlay(
                            isSaving ? ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8) : nil
                        )
                    }
                    .padding(.bottom, DS.spacingXXL)
                }
            }
            .navigationTitle("Voice Memo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        cancelRecording()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingMicrophoneSelection = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: microphoneService.currentInputDevice?.icon ?? "mic")
                                .font(.system(size: 16, weight: .medium))
                            if let device = microphoneService.currentInputDevice {
                                Text(device.type == .none ? "Built-in" : device.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                        .foregroundColor(DS.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DS.primary.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .disabled(listenRecorder.isRecording)
                }
            }
            .sheet(isPresented: $showingMicrophoneSelection) {
                MicrophoneSelectionView()
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .onAppear {
            Task {
                await voiceToText.requestPermissions()
                microphoneService.refreshAvailableDevices()
            }
        }
        .onDisappear {
            cleanupRecording()
        }
    }

    private func toggleRecording() {
        print("🎙️ Toggle recording - Current state: isRecording=\(listenRecorder.isRecording), isPaused=\(listenRecorder.isPaused)")
        if listenRecorder.isRecording {
            if listenRecorder.isPaused {
                resumeRecording()
            } else {
                pauseRecording()
            }
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        print("🎙️ Starting recording...")

        // Reset state immediately for UI responsiveness
        hasRecordedAudio = false

        Task {
            // Create conversation first
            isCreatingConversation = true
            do {
                print("📝 Creating conversation...")
                let newConversationId = try await conversationService.createConversation(
                    projectId: project?.id,
                    projectName: project?.title,
                    initialMessage: "Voice Memo Recording"
                )
                conversationId = newConversationId
                print("✅ Conversation created: \(newConversationId)")

                // Start recording
                await listenRecorder.startRecording()
                print("🎙️ ListenRecorder started, isRecording=\(listenRecorder.isRecording), elapsedTime=\(listenRecorder.elapsedTime)")

                voiceToText.startRecording()
                startAudioLevelMonitoring()

                print("📊 Recording state: hasRecordedAudio=\(hasRecordedAudio)")

            } catch {
                print("❌ Failed to start recording: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to start recording: \(error.localizedDescription)"
                    showingError = true
                }
            }
            isCreatingConversation = false
        }
    }

    private func pauseRecording() {
        print("⏸️ Pausing recording...")
        stopAudioLevelMonitoring()
        voiceToText.stopRecording()
        listenRecorder.pauseRecording()

        // Set hasRecordedAudio to true if we have some recording time
        if listenRecorder.elapsedTime > 0 {
            hasRecordedAudio = true
            print("📊 Set hasRecordedAudio=true after pause (elapsedTime=\(listenRecorder.elapsedTime))")
        }
    }

    private func resumeRecording() {
        print("▶️ Resuming recording...")
        listenRecorder.resumeRecording()
        voiceToText.startRecording()
        startAudioLevelMonitoring()
    }

    private func stopRecording() {
        print("🛑 Stopping recording...")
        print("📊 Before stop - isRecording=\(listenRecorder.isRecording), elapsedTime=\(listenRecorder.elapsedTime)")

        stopAudioLevelMonitoring()
        voiceToText.stopRecording()

        // Actually stop the recorder and get the result
        if let _ = listenRecorder.stopRecording() {
            hasRecordedAudio = true
        } else {
            hasRecordedAudio = false
        }

        print("📊 After stop - hasRecordedAudio=\(hasRecordedAudio), elapsedTime=\(listenRecorder.elapsedTime)")
        print("📝 Transcription: \(voiceToText.transcribedText)")
    }

    private func saveRecording() async {
        print("💾 Save recording called")
        print("📊 State: conversationId=\(conversationId ?? "nil"), hasRecordedAudio=\(hasRecordedAudio), isRecording=\(listenRecorder.isRecording), isPaused=\(listenRecorder.isPaused)")

        guard let conversationId = conversationId else {
            print("❌ No conversation ID available")
            errorMessage = "No conversation available"
            showingError = true
            return
        }

        // Get the recording URL and duration
        let recordingResult: (url: URL, duration: TimeInterval)?

        // If still recording, stop it first
        if listenRecorder.isRecording {
            print("🛑 Automatically stopping recording before save...")
            stopAudioLevelMonitoring()

            // Stop voice-to-text first to finalize transcript
            voiceToText.stopRecording()

            // Give a moment for final transcript to be processed
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            // Actually stop the recorder and get the result
            recordingResult = listenRecorder.stopRecording()
            if recordingResult != nil {
                hasRecordedAudio = true
                print("✅ Recording stopped successfully for save")
            } else {
                print("❌ Failed to stop recording for save")
                errorMessage = "Failed to stop recording"
                showingError = true
                return
            }
        } else {
            // Recording was already stopped, but we need the URL
            guard hasRecordedAudio, let currentFileURL = listenRecorder.currentFileURL else {
                print("❌ No recording to save - hasRecordedAudio: \(hasRecordedAudio), currentFileURL: \(listenRecorder.currentFileURL?.lastPathComponent ?? "nil")")
                errorMessage = "No recording to save"
                showingError = true
                return
            }
            recordingResult = (url: currentFileURL, duration: listenRecorder.elapsedTime)
        }

        guard let result = recordingResult else {
            print("❌ No recording result available")
            errorMessage = "No recording to save"
            showingError = true
            return
        }

        // Verify the file exists before proceeding
        guard FileManager.default.fileExists(atPath: result.url.path) else {
            print("❌ Recording file does not exist at path: \(result.url.path)")
            errorMessage = "Recording file not found"
            showingError = true
            return
        }

        print("✅ Got recording: URL=\(result.url), duration=\(result.duration)")

        isSaving = true

        Task {
            do {
                // First, upload the audio file to Firebase Storage
                guard let userId = Auth.auth().currentUser?.uid else {
                    throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }

                let storageRef = Storage.storage().reference()
                    .child("users")
                    .child(userId)
                    .child("conversations")
                    .child(conversationId)
                    .child("audio")
                    .child("voice-memo-\(UUID().uuidString).m4a")

                let metadata = StorageMetadata()
                metadata.contentType = "audio/m4a"

                _ = try await storageRef.putFileAsync(from: result.url, metadata: metadata)
                let downloadURL = try await storageRef.downloadURL()

                // Get final transcript (make sure we capture any pending text)
                let finalTranscript = voiceToText.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
                print("🎤 Final transcript: '\(finalTranscript)' (isEmpty: \(finalTranscript.isEmpty))")

                // Send transcript as separate text message if available
                if !finalTranscript.isEmpty {
                    try await conversationService.sendMessage(
                        conversationId: conversationId,
                        content: finalTranscript,
                        role: .user,
                        metadata: nil
                    )
                    print("✅ Sent transcript as text message")
                }

                // Send audio message with metadata
                let formattedDuration = formatDuration(result.duration)
                let audioMessageContent = finalTranscript.isEmpty ? "🎤 Voice Memo (\(formattedDuration))" : "🎤 Audio (\(formattedDuration))"

                let messageMetadata = MessageMetadata(
                    tokenCount: nil,
                    processingTime: nil,
                    model: nil,
                    temperature: nil,
                    attachments: nil,
                    audioURL: downloadURL.absoluteString,
                    audioDuration: result.duration,
                    audioStoragePath: storageRef.fullPath
                )

                // Send the audio message
                try await conversationService.sendMessage(
                    conversationId: conversationId,
                    content: audioMessageContent,
                    role: .user,
                    metadata: messageMetadata
                )
                print("✅ Sent audio message")

                // Save to local Documents directory
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let fileName = "voice-memo-\(Date().timeIntervalSince1970).m4a"
                let localURL = documentsPath.appendingPathComponent(fileName)

                do {
                    try FileManager.default.copyItem(at: result.url, to: localURL)
                    print("💾 Saved locally to: \(localURL)")
                } catch {
                    print("⚠️ Failed to save locally: \(error)")
                }

                // Clean up temporary file
                try? FileManager.default.removeItem(at: result.url)
                print("🗑️ Cleaned up temp file")

                await MainActor.run {
                    print("✅ Recording saved successfully, dismissing view")
                    dismiss()
                }

            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save recording: \(error.localizedDescription)"
                    showingError = true
                    isSaving = false
                }
                try? FileManager.default.removeItem(at: result.url)
            }
        }
    }

    private func cancelRecording() {
        cleanupRecording()
    }

    private func cleanupRecording() {
        stopAudioLevelMonitoring()
        voiceToText.stopRecording()
        listenRecorder.cancelRecording()
    }

    private func startAudioLevelMonitoring() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            // Simulate audio levels for visual feedback
            audioLevel = Float.random(in: 0.1...0.4)
        }
    }

    private func stopAudioLevelMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil
        audioLevel = 0
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Computed Properties

    private var transcriptionView: some View {
        Group {
            if !voiceToText.transcribedText.isEmpty {
                transcriptionContentView
            } else if voiceToText.isTranscribing {
                transcriptionPlaceholderView
            }
        }
    }

    private var transcriptionContentView: some View {
        VStack(alignment: .leading, spacing: DS.spacingXS) {
            transcriptionHeaderView
            transcriptionScrollView
        }
        .padding(.horizontal)
    }

    private var transcriptionHeaderView: some View {
        HStack {
            Image(systemName: "text.bubble")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DS.primary)
            Text("Live Transcript")
                .font(Typography.caption)
                .foregroundColor(DS.primary)
                .fontWeight(.medium)
            Spacer()
            if voiceToText.isTranscribing {
                ProgressView()
                    .scaleEffect(0.7)
                    .progressViewStyle(CircularProgressViewStyle(tint: DS.primary))
            }
        }
        .padding(.horizontal, DS.spacingM)
    }

    private var transcriptionScrollView: some View {
        ScrollView {
            ScrollViewReader { proxy in
                Text(voiceToText.transcribedText)
                    .font(Typography.bodyLarge)
                    .foregroundColor(DS.textPrimary)
                    .padding(DS.spacingM)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.surface)
                    .cornerRadius(DS.cornerRadius)
                    .id("transcript")
                    .onChange(of: voiceToText.transcribedText) { _ in
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("transcript", anchor: .bottom)
                        }
                    }
            }
        }
        .frame(maxHeight: 150)
    }

    private var transcriptionPlaceholderView: some View {
        VStack(spacing: DS.spacingS) {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                    .progressViewStyle(CircularProgressViewStyle(tint: DS.primary))
                Text("Listening...")
                    .font(Typography.bodyMedium)
                    .foregroundColor(DS.textSecondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(DS.surface)
        .cornerRadius(DS.cornerRadius)
        .padding(.horizontal)
    }
}

// MARK: - Pulsating Animation
struct PulsatingAnimation: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.2 : 1.0)
            .opacity(isAnimating ? 0.6 : 1.0)
            .animation(
                Animation.easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

extension View {
    func pulsatingAnimation() -> some View {
        modifier(PulsatingAnimation())
    }
}

// MARK: - Headset Indicator
struct HeadsetIndicator: View {
    let headsetType: HeadsetType
    let headsetName: String
    let isRecording: Bool

    var body: some View {
        HStack(spacing: DS.spacingM) {
            // Icon with animation
            ZStack {
                Circle()
                    .fill(headsetType == .smartGlasses ? DS.primary : DS.surface)
                    .frame(width: 40, height: 40)
                    .shadow(color: DS.shadow, radius: 3, x: 0, y: 2)

                Image(systemName: headsetType.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(headsetType == .smartGlasses ? .white : DS.textPrimary)
                    .scaleEffect(isRecording ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: isRecording)
            }

            // Text info
            VStack(alignment: .leading, spacing: 2) {
                Text(headsetName)
                    .font(Typography.bodyMedium)
                    .foregroundColor(DS.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Circle()
                        .fill(isRecording ? DS.success : DS.textSecondary)
                        .frame(width: 6, height: 6)
                        .pulsatingAnimation()
                        .opacity(isRecording ? 1 : 0.5)

                    Text(isRecording ? "Recording from \(headsetType.rawValue)" : "Ready")
                        .font(Typography.bodySmall)
                        .foregroundColor(DS.textSecondary)
                }
            }

            Spacer()

            // Connection indicator
            if headsetType == .smartGlasses {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(DS.success)
            }
        }
        .padding(.horizontal, DS.spacingM)
        .padding(.vertical, DS.spacingS)
        .background(
            RoundedRectangle(cornerRadius: DS.cornerRadius)
                .fill(DS.surface.opacity(0.8))
                .shadow(color: DS.shadow, radius: 5, x: 0, y: 2)
        )
        .padding(.horizontal, DS.spacingL)
    }
}