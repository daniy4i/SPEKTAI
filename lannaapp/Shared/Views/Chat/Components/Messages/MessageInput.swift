//
//  MessageInput.swift
//  lannaapp
//
//  Enhanced chat input with voice dictation and action buttons
//

import SwiftUI
import Speech

struct MessageInput: View {
    @Binding var text: String
    let onSend: () -> Void
    let isLoading: Bool

    // Voice dictation properties
    @StateObject private var voiceToText = VoiceToTextService()
    @State private var isVoiceDictationActive = false

    // Action menu properties
    @State private var showingActionMenu = false
    @State private var showingVoiceMemo = false

    // Available actions
    let availableActions = [
        ChatAction(id: "voice_memo", title: "Voice Memo", icon: "mic.circle", description: "Record a voice memo"),
        ChatAction(id: "camera", title: "Camera", icon: "camera.circle", description: "Take a photo"),
        ChatAction(id: "photo_library", title: "Photo Library", icon: "photo.circle", description: "Choose from photos"),
        ChatAction(id: "files", title: "Files", icon: "doc.circle", description: "Attach a file")
    ]

    var body: some View {
        VStack(spacing: DS.spacingXS) {
            // Voice dictation status bar (when active)
            if isVoiceDictationActive {
                voiceDictationStatusBar
            }

            // Main input row
            HStack(spacing: DS.spacingS) {
                // Action menu button
                Button(action: {
                    showingActionMenu = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(DS.primary)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isLoading)

                // Text input field
                HStack(spacing: DS.spacingXS) {
                    TextField("Type a message...", text: $text, axis: .vertical)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(Typography.bodyMedium)
                        .lineLimit(1...6)

                    // Voice dictation button
                    Button(action: toggleVoiceDictation) {
                        Image(systemName: isVoiceDictationActive ? "mic.fill" : "mic")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isVoiceDictationActive ? .red : DS.textSecondary)
                            .scaleEffect(isVoiceDictationActive ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: isVoiceDictationActive)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isLoading)
                }
                .padding(.horizontal, DS.spacingM)
                .padding(.vertical, DS.spacingS)
                .background(DS.surface)
                .cornerRadius(20)

                // Send button
                Button(action: onSend) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 32, height: 32)
                .background(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? DS.textSecondary : DS.primary)
                .clipShape(Circle())
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, DS.spacingM)
        .padding(.vertical, DS.spacingS)
        .background(DS.background)
        .actionSheet(isPresented: $showingActionMenu) {
            ActionSheet(
                title: Text("Add to Message"),
                message: Text("Choose an action"),
                buttons: availableActions.map { action in
                    .default(Text(action.title)) {
                        handleAction(action)
                    }
                } + [.cancel()]
            )
        }
        .sheet(isPresented: $showingVoiceMemo) {
            VoiceMemoView_iOS(project: nil)
        }
        .onChange(of: voiceToText.transcribedText) { newText in
            if isVoiceDictationActive && !newText.isEmpty {
                // Append dictated text to existing text
                if !text.isEmpty && !text.hasSuffix(" ") {
                    text += " "
                }
                text += newText
            }
        }
        .onAppear {
            Task {
                await voiceToText.requestPermissions()
            }
        }
    }

    private var voiceDictationStatusBar: some View {
        HStack(spacing: DS.spacingS) {
            HStack(spacing: DS.spacingXS) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                    .opacity(0.8)

                Text("Listening...")
                    .font(Typography.caption)
                    .foregroundColor(DS.textSecondary)
            }

            Spacer()

            Button("Done") {
                stopVoiceDictation()
            }
            .font(Typography.caption)
            .foregroundColor(DS.primary)
        }
        .padding(.horizontal, DS.spacingM)
        .padding(.vertical, DS.spacingXS)
        .background(DS.surface)
        .cornerRadius(8)
        .padding(.horizontal, DS.spacingM)
    }

    private func toggleVoiceDictation() {
        if isVoiceDictationActive {
            stopVoiceDictation()
        } else {
            startVoiceDictation()
        }
    }

    private func startVoiceDictation() {
        voiceToText.clearTranscription()
        voiceToText.startRecording()
        isVoiceDictationActive = true
        print("🎤 Started voice dictation")
    }

    private func stopVoiceDictation() {
        voiceToText.stopRecording()
        isVoiceDictationActive = false
        print("🛑 Stopped voice dictation")
    }

    private func handleAction(_ action: ChatAction) {
        switch action.id {
        case "voice_memo":
            showingVoiceMemo = true
        case "camera":
            // TODO: Implement camera capture
            print("📷 Camera action selected")
        case "photo_library":
            // TODO: Implement photo library
            print("📸 Photo library action selected")
        case "files":
            // TODO: Implement file picker
            print("📁 Files action selected")
        default:
            break
        }
    }
}

// MARK: - Supporting Types

struct ChatAction: Identifiable {
    let id: String
    let title: String
    let icon: String
    let description: String
}

// MARK: - Preview
#if DEBUG
struct MessageInput_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            MessageInput(
                text: .constant("Hello world"),
                onSend: { print("Send tapped") },
                isLoading: false
            )

            MessageInput(
                text: .constant(""),
                onSend: { print("Send tapped") },
                isLoading: true
            )
        }
        .padding()
        .background(DS.background)
    }
}
#endif