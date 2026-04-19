//
//  MediaItemView.swift
//  lannaapp
//
//  Created by Claude on 01/23/2025.
//

import SwiftUI
import AVFoundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct MediaItemView: View {
    let mediaItem: ProjectMediaItem
    @State private var showingFullscreen = false
    @State private var showingAudioPlayer = false
    @State private var isSharing = false
    @State private var isDownloading = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.spacingS) {
            // Media Preview
            mediaPreview
                .aspectRatio(1, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: DS.cornerRadius))
                .onTapGesture {
                    handleTap()
                }

            // Media Info
            VStack(alignment: .leading, spacing: DS.spacingXS) {
                HStack {
                    Image(systemName: mediaItem.type.icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(iconColor)

                    Text(mediaItem.fileName)
                        .font(Typography.caption)
                        .foregroundColor(DS.textPrimary)
                        .lineLimit(1)

                    Spacer()
                }

                if let duration = mediaItem.formattedDuration {
                    Text(duration)
                        .font(Typography.caption)
                        .foregroundColor(DS.textSecondary)
                }

                Text(formatDate(mediaItem.createdAt))
                    .font(Typography.caption)
                    .foregroundColor(DS.textSecondary)

                if let conversationName = mediaItem.conversationName {
                    Text(conversationName)
                        .font(Typography.caption)
                        .foregroundColor(DS.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .contextMenu {
            contextMenuItems
        }
        .fullScreenCover(isPresented: $showingFullscreen) {
            MediaFullscreenView(mediaItem: mediaItem)
        }
        .sheet(isPresented: $showingAudioPlayer) {
            AudioPlayerSheet(mediaItem: mediaItem)
        }
        .overlay(
            Group {
                if isSharing || isDownloading {
                    ZStack {
                        Color.black.opacity(0.4)

                        VStack(spacing: DS.spacingM) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)

                            Text(isSharing ? "Preparing to share..." : "Downloading...")
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

    @ViewBuilder
    private var mediaPreview: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: DS.cornerRadius)
                .fill(DS.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.cornerRadius)
                        .stroke(DS.textSecondary.opacity(0.1), lineWidth: 1)
                )

            switch mediaItem.type {
            case ProjectMediaType.audio:
                audioPreview
            case ProjectMediaType.video:
                videoPreview
            case ProjectMediaType.image:
                imagePreview
            }

            // Play overlay for audio/video
            if mediaItem.type != ProjectMediaType.image {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 40, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(radius: 4)
            }
        }
    }

    private var audioPreview: some View {
        ZStack {
            // Waveform-like background
            LinearGradient(
                colors: [DS.primary.opacity(0.2), DS.primary.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: DS.spacingS) {
                Image(systemName: "waveform")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(DS.primary)

                if let duration = mediaItem.formattedDuration {
                    Text(duration)
                        .font(Typography.caption)
                        .foregroundColor(DS.textPrimary)
                }
            }
        }
    }

    private var videoPreview: some View {
        ZStack {
            if let thumbnailURL = mediaItem.thumbnailURL {
                AsyncImage(url: URL(string: thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    videoPlaceholder
                }
            } else {
                videoPlaceholder
            }
        }
    }

    private var videoPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [DS.secondary.opacity(0.2), DS.secondary.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: DS.spacingS) {
                Image(systemName: "video.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(DS.secondary)

                if let duration = mediaItem.formattedDuration {
                    Text(duration)
                        .font(Typography.caption)
                        .foregroundColor(DS.textPrimary)
                }
            }
        }
    }

    private var imagePreview: some View {
        AsyncImage(url: URL(string: mediaItem.url)) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            ZStack {
                LinearGradient(
                    colors: [DS.textSecondary.opacity(0.2), DS.textSecondary.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: "photo.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(DS.textSecondary)
            }
        }
    }


    private var iconColor: Color {
        switch mediaItem.type {
        case ProjectMediaType.audio:
            return DS.primary
        case ProjectMediaType.video:
            return DS.secondary
        case ProjectMediaType.image:
            return DS.textSecondary
        }
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button(action: {
            handleTap()
        }) {
            let label = mediaItem.type == ProjectMediaType.image ? "View Image" :
                       mediaItem.type == ProjectMediaType.audio ? "Play Audio" : "Play Video"
            let icon = mediaItem.type == ProjectMediaType.image ? "eye" : "play"
            Label(label, systemImage: icon)
        }

        Button(action: {
            copyURL()
        }) {
            Label("Copy URL", systemImage: "doc.on.doc")
        }

        Button(action: {
            shareMedia()
        }) {
            Label("Share", systemImage: "square.and.arrow.up")
        }

        Divider()

        Button(action: {
            downloadMedia()
        }) {
            Label("Download", systemImage: "arrow.down.circle")
        }
    }

    private func handleTap() {
        switch mediaItem.type {
        case ProjectMediaType.audio:
            showingAudioPlayer = true
        case ProjectMediaType.video:
            showingFullscreen = true
        case ProjectMediaType.image:
            showingFullscreen = true
        }
    }

    private func copyURL() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(mediaItem.url, forType: .string)
        #else
        UIPasteboard.general.string = mediaItem.url
        #endif
    }

    private func shareMedia() {
        guard let url = URL(string: mediaItem.url) else { return }

        Task {
            await MainActor.run {
                isSharing = true
            }

            do {
                // Download the file first to share the actual file, not just the URL
                print("📥 Downloading media for sharing...")
                let (data, _) = try await URLSession.shared.data(from: url)
                print("✅ Media downloaded (\(data.count) bytes)")

                // Ensure filename has proper extension
                var fileName = mediaItem.fileName
                if !fileName.contains(".") {
                    // Add extension based on media type
                    switch mediaItem.type {
                    case ProjectMediaType.audio:
                        fileName += ".m4a"
                    case ProjectMediaType.video:
                        fileName += ".mp4"
                    case ProjectMediaType.image:
                        fileName += ".jpg"
                    }
                }

                // Create a temporary file
                let tempDir = FileManager.default.temporaryDirectory
                let tempFileURL = tempDir.appendingPathComponent(fileName)
                try data.write(to: tempFileURL)

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
                                    self.isSharing = false
                                }
                            }
                        }
                    }
                }
                #else
                let sharingService = NSSharingService(named: .sendViaAirDrop)
                sharingService?.perform(withItems: [tempFileURL])
                await MainActor.run {
                    isSharing = false
                }
                #endif
            } catch {
                print("❌ Failed to prepare media for sharing: \(error)")
                await MainActor.run {
                    isSharing = false
                }
            }
        }
    }

    private func downloadMedia() {
        guard let url = URL(string: mediaItem.url) else { return }

        Task {
            await MainActor.run {
                isDownloading = true
            }

            do {
                print("📥 Downloading media...")
                let (data, _) = try await URLSession.shared.data(from: url)
                print("✅ Media downloaded (\(data.count) bytes)")

                // Ensure filename has proper extension
                var fileName = mediaItem.fileName
                if !fileName.contains(".") {
                    // Add extension based on media type
                    switch mediaItem.type {
                    case ProjectMediaType.audio:
                        fileName += ".m4a"
                    case ProjectMediaType.video:
                        fileName += ".mp4"
                    case ProjectMediaType.image:
                        fileName += ".jpg"
                    }
                }

                #if os(iOS)
                // Save to Files app
                let tempDir = FileManager.default.temporaryDirectory
                let tempFileURL = tempDir.appendingPathComponent(fileName)
                try data.write(to: tempFileURL)

                await MainActor.run {
                    // For images, also offer to save to Photos
                    if mediaItem.type == ProjectMediaType.image {
                        if let image = UIImage(data: data) {
                            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        }
                    }

                    // Present document picker to save file
                    let documentPicker = UIDocumentPickerViewController(forExporting: [tempFileURL])

                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first,
                       let rootVC = window.rootViewController {
                        rootVC.present(documentPicker, animated: true) {
                            Task {
                                await MainActor.run {
                                    self.isDownloading = false
                                }
                            }
                        }
                    }
                }
                #else
                // Save to Downloads on macOS
                await MainActor.run {
                    let savePanel = NSSavePanel()
                    savePanel.nameFieldStringValue = fileName

                    if savePanel.runModal() == .OK, let saveURL = savePanel.url {
                        do {
                            try data.write(to: saveURL)
                            print("✅ File saved to: \(saveURL.path)")
                        } catch {
                            print("❌ Failed to write file: \(error)")
                        }
                    }
                    isDownloading = false
                }
                #endif
            } catch {
                print("❌ Failed to download media: \(error)")
                await MainActor.run {
                    isDownloading = false
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Fullscreen Media View

struct MediaFullscreenView: View {
    let mediaItem: ProjectMediaItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if mediaItem.type == ProjectMediaType.image {
                AsyncImage(url: URL(string: mediaItem.url)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            } else if mediaItem.type == ProjectMediaType.video {
                VideoPlayer(player: AVPlayer(url: URL(string: mediaItem.url)!))
                    .edgesIgnoringSafeArea(.all)
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
}

// MARK: - Audio Player Sheet

struct AudioPlayerSheet: View {
    let mediaItem: ProjectMediaItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: DS.spacingL) {
                Spacer()

                // Waveform visualization
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [DS.primary.opacity(0.2), DS.primary.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 200, height: 200)

                    Image(systemName: "waveform")
                        .font(.system(size: 60, weight: .medium))
                        .foregroundColor(DS.primary)
                }

                // File info
                VStack(spacing: DS.spacingXS) {
                    Text(mediaItem.fileName)
                        .font(Typography.titleSmall)
                        .foregroundColor(DS.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    if let conversationName = mediaItem.conversationName {
                        Text(conversationName)
                            .font(Typography.bodyMedium)
                            .foregroundColor(DS.textSecondary)
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Audio player
                if let url = URL(string: mediaItem.url),
                   let duration = mediaItem.duration {
                    AudioPlayerView(
                        audioURL: url,
                        duration: duration,
                        accentColor: DS.primary,
                        textColor: DS.textPrimary,
                        showShareButton: true,
                        fileName: mediaItem.fileName
                    )
                    .padding(.horizontal, DS.spacingL)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Audio Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#if canImport(AVKit)
import AVKit

#if os(iOS)
struct VideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}
#elseif os(macOS)
struct VideoPlayer: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.player = player
        playerView.controlsStyle = .default
        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {}
}
#endif
#endif