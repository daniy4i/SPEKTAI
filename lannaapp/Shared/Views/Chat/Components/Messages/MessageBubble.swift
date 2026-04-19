//
//  MessageBubble.swift
//  lannaapp
//
//  Extracted from ChatComponents.swift
//

import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct MessageBubble: View {
    let message: Message
    @State private var showingShareProgress = false

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
                userMessageBubble
            } else {
                assistantMessageBubble
                Spacer()
            }
        }
        .padding(.horizontal, DS.spacingM)
        .overlay(
            Group {
                if showingShareProgress {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()

                        VStack(spacing: DS.spacingM) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)

                            Text("Preparing audio...")
                                .font(Typography.bodyMedium)
                                .foregroundColor(.white)
                        }
                        .padding(DS.spacingL)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(DS.cornerRadius)
                    }
                }
            }
        )
    }

    private var userMessageBubble: some View {
        VStack(alignment: .trailing, spacing: DS.spacingXS) {
            VStack(alignment: .leading, spacing: DS.spacingS) {
                if hasAudioContent {
                    audioContent
                }

                if hasVideoContent {
                    videoContent
                }

                if !message.content.isEmpty {
                    MarkdownText(text: message.content)
                        .foregroundColor(.white)
                        .font(Typography.bodyMedium)
                }
            }
            .padding(DS.spacingM)
            .background(DS.primary)
            .foregroundColor(.white)
            .cornerRadius(DS.cornerRadius, corners: [.topLeft, .topRight, .bottomLeft])
            .frame(maxWidth: 280, alignment: .trailing)

            messageTimestamp
        }
    }

    private var assistantMessageBubble: some View {
        VStack(alignment: .leading, spacing: DS.spacingXS) {
            VStack(alignment: .leading, spacing: DS.spacingS) {
                if hasAudioContent {
                    audioContent
                }

                if hasVideoContent {
                    videoContent
                }

                if !message.content.isEmpty {
                    MarkdownText(text: message.content)
                        .foregroundColor(DS.textPrimary)
                        .font(Typography.bodyMedium)
                }
            }
            .padding(DS.spacingM)
            .background(DS.surface)
            .cornerRadius(DS.cornerRadius, corners: [.topLeft, .topRight, .bottomRight])
            .frame(maxWidth: 280, alignment: .leading)

            messageTimestamp
        }
    }

    private var messageTimestamp: some View {
        Text(formatTimestamp(message.createdAt))
            .font(Typography.caption)
            .foregroundColor(DS.textSecondary)
    }

    private var hasAudioContent: Bool {
        message.metadata?.audioURL != nil
    }

    private var hasVideoContent: Bool {
        message.metadata?.videoURL != nil
    }

    @ViewBuilder
    private var audioContent: some View {
        if let audioURL = message.metadata?.audioURL,
           let duration = message.metadata?.audioDuration,
           let url = URL(string: audioURL) {
            AudioMessageView(
                audioURL: url,
                duration: duration,
                isFromUser: message.role == .user
            )
            .contextMenu {
                Button(action: {
                    shareAudioFromMessage(url: url)
                }) {
                    Label("Share Audio", systemImage: "square.and.arrow.up")
                }

                Button(action: {
                    copyAudioURL(audioURL)
                }) {
                    Label("Copy URL", systemImage: "doc.on.doc")
                }
            }
        }
    }

    @ViewBuilder
    private var videoContent: some View {
        if let videoURL = message.metadata?.videoURL,
           let thumbnailURL = message.metadata?.videoThumbnailURL,
           let url = URL(string: videoURL),
           let thumbURL = URL(string: thumbnailURL) {
            VideoMessageView(
                videoURL: url,
                thumbnailURL: thumbURL
            )
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func shareAudioFromMessage(url: URL) {
        Task {
            await MainActor.run {
                showingShareProgress = true
            }

            do {
                let data: Data
                let tempFileURL: URL

                // Ensure filename has proper extension
                var fileName = url.lastPathComponent.isEmpty ? "audio" : url.lastPathComponent
                if !fileName.contains(".") {
                    // If no extension, try to detect from URL or default to .m4a
                    let urlExtension = url.pathExtension
                    if !urlExtension.isEmpty {
                        fileName += ".\(urlExtension)"
                    } else {
                        fileName += ".m4a"
                    }
                }

                // If it's a local file, check if we need to copy it with proper extension
                if url.isFileURL {
                    // If local file already has extension, use it directly
                    if !url.pathExtension.isEmpty {
                        tempFileURL = url
                    } else {
                        // Copy to temp with proper extension
                        let fileData = try Data(contentsOf: url)
                        let tempDir = FileManager.default.temporaryDirectory
                        tempFileURL = tempDir.appendingPathComponent(fileName)
                        try fileData.write(to: tempFileURL)
                    }
                } else {
                    // Download remote file to temp directory
                    print("📥 Downloading audio file...")
                    (data, _) = try await URLSession.shared.data(from: url)
                    print("✅ Audio file downloaded (\(data.count) bytes)")
                    let tempDir = FileManager.default.temporaryDirectory
                    tempFileURL = tempDir.appendingPathComponent(fileName)
                    try data.write(to: tempFileURL)
                }

                #if os(iOS)
                await MainActor.run {
                    let activityVC = UIActivityViewController(
                        activityItems: [tempFileURL],
                        applicationActivities: nil
                    )

                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        // Find the topmost view controller
                        var topVC = window.rootViewController
                        while let presentedVC = topVC?.presentedViewController {
                            topVC = presentedVC
                        }

                        // For iPad popover presentation
                        if let popover = activityVC.popoverPresentationController {
                            popover.sourceView = window
                            popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                            popover.permittedArrowDirections = []
                        }

                        topVC?.present(activityVC, animated: true) {
                            Task {
                                await MainActor.run {
                                    self.showingShareProgress = false
                                }
                            }
                        }
                    }
                }
                #else
                let sharingService = NSSharingService(named: .sendViaAirDrop)
                sharingService?.perform(withItems: [tempFileURL])
                await MainActor.run {
                    showingShareProgress = false
                }
                #endif
            } catch {
                print("❌ Failed to share audio: \(error)")
                await MainActor.run {
                    showingShareProgress = false
                }
            }
        }
    }

    private func copyAudioURL(_ urlString: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(urlString, forType: .string)
        #else
        UIPasteboard.general.string = urlString
        #endif
    }
}

// MARK: - RoundedCorner Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}