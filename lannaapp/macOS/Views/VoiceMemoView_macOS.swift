//
//  VoiceMemoView_macOS.swift
//  lannaapp
//
//  Created by Assistant on 01/23/2025.
//

import SwiftUI
import AVFoundation
import FirebaseStorage
import FirebaseAuth

struct VoiceMemoView_macOS: View {
    @StateObject private var listenRecorder = ListenModeRecorder()
    @StateObject private var voiceToText = VoiceToTextService()
    @StateObject private var conversationService = ConversationService()
    @StateObject private var headsetDetection = HeadsetDetectionService.shared
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

    var formattedTime: String {
        let minutes = Int(listenRecorder.elapsedTime) / 60
        let seconds = Int(listenRecorder.elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        ZStack {
            DS.background
                .ignoresSafeArea()

            VStack(spacing: DS.spacingXL) {
                // Title bar
                HStack {
                    Text("Voice Memo")
                        .font(Typography.titleLarge)
                        .foregroundColor(DS.textPrimary)

                    Spacer()

                    Button(action: {
                        cancelRecording()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(DS.textSecondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                }
                .padding()

                // Headset indicator
                if headsetDetection.currentHeadsetType != .none {
                    HeadsetIndicator(
                        headsetType: headsetDetection.currentHeadsetType,
                        headsetName: headsetDetection.headsetName,
                        isRecording: listenRecorder.isRecording
                    )
                    .padding(.top, DS.spacingM)
                }

                Spacer()

                // Waveform/Recording indicator
                ZStack {
                    Circle()
                        .fill(DS.surface)
                        .frame(width: 240, height: 240)
                        .shadow(color: DS.shadow, radius: 15, x: 0, y: 8)

                    // Outer ring for headset indication
                    if headsetDetection.currentHeadsetType != .none {
                        Circle()
                            .stroke(
                                headsetDetection.currentHeadsetType == .smartGlasses ? DS.primary : DS.secondary,
                                lineWidth: 5
                            )
                            .frame(width: 252, height: 252)
                            .opacity(0.6)
                    }

                    if listenRecorder.isRecording {
                        Circle()
                            .stroke(
                                headsetDetection.currentHeadsetType == .smartGlasses ? DS.primary : DS.secondary,
                                lineWidth: 4
                            )
                            .frame(width: 240, height: 240)
                            .scaleEffect(1 + CGFloat(audioLevel) * 0.5)
                            .animation(.easeInOut(duration: 0.1), value: audioLevel)

                        Circle()
                            .fill(DS.error)
                            .frame(width: 100, height: 100)
                            .pulsatingAnimation()
                    } else {
                        Image(systemName: headsetDetection.currentHeadsetType != .none ? headsetDetection.currentHeadsetType.icon : "mic.fill")
                            .font(.system(size: 80))
                            .foregroundColor(headsetDetection.currentHeadsetType == .smartGlasses ? DS.primary : DS.textSecondary)
                    }
                }

                // Time display
                Text(formattedTime)
                    .font(Typography.displayLarge)
                    .foregroundColor(DS.textPrimary)
                    .monospacedDigit()

                // Transcription preview (if available)
                if !voiceToText.transcribedText.isEmpty {
                    ScrollView {
                        Text(voiceToText.transcribedText)
                            .font(Typography.bodyLarge)
                            .foregroundColor(DS.textSecondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DS.surface)
                            .cornerRadius(DS.cornerRadius)
                    }
                    .frame(maxHeight: 200)
                    .frame(maxWidth: 600)
                }

                Spacer()

                // Control buttons
                HStack(spacing: DS.spacingXXL) {
                    // Cancel button
                    Button(action: cancelRecording) {
                        VStack(spacing: DS.spacingS) {
                            ZStack {
                                Circle()
                                    .fill(DS.surface)
                                    .frame(width: 70, height: 70)
                                    .shadow(color: DS.shadow, radius: 5, x: 0, y: 2)

                                Image(systemName: "xmark")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(DS.textSecondary)
                            }

                            Text("Cancel")
                                .font(Typography.bodySmall)
                                .foregroundColor(DS.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .opacity(listenRecorder.isRecording ? 1 : 0.5)
                    .disabled(!listenRecorder.isRecording)

                    // Main record/stop button
                    Button(action: toggleRecording) {
                        VStack(spacing: DS.spacingS) {
                            ZStack {
                                Circle()
                                    .fill(listenRecorder.isRecording ? DS.error : DS.primary)
                                    .frame(width: 100, height: 100)
                                    .shadow(color: DS.shadow, radius: 10, x: 0, y: 5)

                                if listenRecorder.isRecording {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white)
                                        .frame(width: 35, height: 35)
                                } else {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 35, height: 35)
                                }
                            }

                            Text(listenRecorder.isRecording ? "Stop" : "Record")
                                .font(Typography.bodyMedium)
                                .foregroundColor(DS.textPrimary)
                        }
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(listenRecorder.isRecording ? 1.0 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: listenRecorder.isRecording)

                    // Done button (only when recording is stopped and we have audio)
                    Button(action: saveRecording) {
                        VStack(spacing: DS.spacingS) {
                            ZStack {
                                Circle()
                                    .fill(DS.success)
                                    .frame(width: 70, height: 70)
                                    .shadow(color: DS.shadow, radius: 5, x: 0, y: 2)

                                Image(systemName: "checkmark")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(.white)
                            }

                            Text("Save")
                                .font(Typography.bodySmall)
                                .foregroundColor(DS.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .opacity(!listenRecorder.isRecording && hasRecordedAudio ? 1 : 0.5)
                    .disabled(listenRecorder.isRecording || !hasRecordedAudio || isSaving)
                    .overlay(
                        isSaving ? ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8) : nil
                    )
                }
                .padding(.bottom, DS.spacingXXL)
            }
        }
        .frame(width: 800, height: 600)
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .onAppear {
            Task {
                await voiceToText.requestPermissions()
            }
        }
        .onDisappear {
            cleanupRecording()
        }
    }

    private func toggleRecording() {
        if listenRecorder.isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        Task {
            // Create conversation first
            isCreatingConversation = true
            do {
                let newConversationId = try await conversationService.createConversation(
                    projectId: project?.id,
                    projectName: project?.title,
                    initialMessage: "Voice Memo Recording"
                )
                conversationId = newConversationId

                // Start recording
                await listenRecorder.startRecording()
                voiceToText.startRecording()
                startAudioLevelMonitoring()

            } catch {
                errorMessage = "Failed to start recording: \(error.localizedDescription)"
                showingError = true
            }
            isCreatingConversation = false
        }
    }

    private func stopRecording() {
        stopAudioLevelMonitoring()
        voiceToText.stopRecording()
        // Mark that we have audio ready to save
        hasRecordedAudio = true
    }

    private func saveRecording() {
        guard let conversationId = conversationId else {
            errorMessage = "No conversation available"
            showingError = true
            return
        }

        guard let result = listenRecorder.stopRecording() else {
            errorMessage = "No recording to save"
            showingError = true
            return
        }

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

                // Create message content with transcription
                let content: String
                if !voiceToText.transcribedText.isEmpty {
                    content = "🎤 Voice Memo\n\n\(voiceToText.transcribedText)"
                } else {
                    let formattedDuration = formatDuration(result.duration)
                    content = "🎤 Voice Memo (\(formattedDuration))"
                }

                // Create metadata with audio URL
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

                // Send the message with both content and audio
                try await conversationService.sendMessage(
                    conversationId: conversationId,
                    content: content,
                    role: .user,
                    metadata: messageMetadata
                )

                // Clean up temporary file
                try? FileManager.default.removeItem(at: result.url)

                await MainActor.run {
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
}

// MARK: - macOS specific Pulsating Animation
#if os(macOS)
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
                    .frame(width: 50, height: 50)
                    .shadow(color: DS.shadow, radius: 4, x: 0, y: 3)

                Image(systemName: headsetType.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(headsetType == .smartGlasses ? .white : DS.textPrimary)
                    .scaleEffect(isRecording ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: isRecording)
            }

            // Text info
            VStack(alignment: .leading, spacing: 4) {
                Text(headsetName)
                    .font(Typography.bodyLarge)
                    .foregroundColor(DS.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Circle()
                        .fill(isRecording ? DS.success : DS.textSecondary)
                        .frame(width: 8, height: 8)
                        .pulsatingAnimation()
                        .opacity(isRecording ? 1 : 0.5)

                    Text(isRecording ? "Recording from \(headsetType.rawValue)" : "Ready")
                        .font(Typography.bodyMedium)
                        .foregroundColor(DS.textSecondary)
                }
            }

            Spacer()

            // Connection indicator
            if headsetType == .smartGlasses {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(DS.success)
            }
        }
        .padding(.horizontal, DS.spacingL)
        .padding(.vertical, DS.spacingM)
        .background(
            RoundedRectangle(cornerRadius: DS.cornerRadius)
                .fill(DS.surface.opacity(0.9))
                .shadow(color: DS.shadow, radius: 6, x: 0, y: 3)
        )
        .frame(maxWidth: 600)
    }
}
#endif