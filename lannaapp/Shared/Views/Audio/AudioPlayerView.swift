//
//  AudioPlayerView.swift
//  lannaapp
//
//  Shared audio player component with scrubbing and skip controls
//

import SwiftUI
import AVFoundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct AudioPlayerView: View {
    let audioURL: URL
    let duration: TimeInterval
    let accentColor: Color
    let textColor: Color
    var showShareButton: Bool = false
    var fileName: String? = nil

    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var timeObserver: Any?
    @State private var playbackObserver: NSObjectProtocol?
    @State private var failureObserver: NSObjectProtocol?
    @State private var isDragging = false
    @State private var isSharing = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.spacingXS) {
            HStack(spacing: DS.spacingS) {
                // Play/Pause button
                Button(action: togglePlayback) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(accentColor)
                }
                .buttonStyle(PlainButtonStyle())

                // Skip backward 10s
                Button(action: { skip(by: -10) }) {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(accentColor)
                }
                .buttonStyle(PlainButtonStyle())

                // Progress and time
                VStack(alignment: .leading, spacing: DS.spacingXS) {
                    // Scrubbing progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 2)
                                .fill(textColor.opacity(0.2))
                                .frame(height: 4)

                            // Progress track
                            RoundedRectangle(cornerRadius: 2)
                                .fill(accentColor)
                                .frame(width: geometry.size.width * progress, height: 4)

                            // Draggable thumb
                            Circle()
                                .fill(accentColor)
                                .frame(width: 12, height: 12)
                                .offset(x: geometry.size.width * progress - 6)
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isDragging = true
                                    let newProgress = min(max(0, value.location.x / geometry.size.width), 1)
                                    let newTime = newProgress * duration
                                    currentTime = newTime
                                }
                                .onEnded { value in
                                    let newProgress = min(max(0, value.location.x / geometry.size.width), 1)
                                    let newTime = newProgress * duration
                                    seek(to: newTime)
                                    isDragging = false
                                }
                        )
                    }
                    .frame(height: 12)

                    // Time labels
                    HStack {
                        Text(formatTime(currentTime))
                            .foregroundColor(textColor)
                        Text("/")
                            .foregroundColor(textColor)
                        Text(formatTime(duration))
                            .foregroundColor(textColor)
                    }
                    .font(Typography.caption)
                }

                // Skip forward 10s
                Button(action: { skip(by: 10) }) {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(accentColor)
                }
                .buttonStyle(PlainButtonStyle())

                // Share button (optional)
                if showShareButton {
                    Button(action: shareAudio) {
                        if isSharing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .frame(width: 20, height: 20)
                                .tint(accentColor)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(accentColor)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isSharing)
                }
            }
        }
        .onAppear {
            print("🎧 AudioPlayerView appeared - URL: \(audioURL), Duration: \(duration)")
            validateAudioURL()
        }
        .onDisappear(perform: cleanup)
    }

    private var progress: Double {
        guard duration > 0 else { return 0 }
        return min(currentTime / duration, 1)
    }

    private func togglePlayback() {
        if player == nil {
            print("🎧 Creating new AVPlayer with URL: \(audioURL)")

            // Configure audio session for playback
            #if os(iOS)
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .default, options: [])
                try audioSession.setActive(true)
                print("✅ Audio session configured for playback")
            } catch {
                print("❌ Failed to configure audio session: \(error)")
            }
            #endif

            let newPlayer = AVPlayer(url: audioURL)
            player = newPlayer
            addObservers(to: newPlayer)

            // Add a small delay to ensure the player is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("▶️ Starting playback")
                newPlayer.play()
                self.isPlaying = true
            }
        } else if isPlaying {
            print("⏸️ Pausing playback")
            player?.pause()
            isPlaying = false
        } else {
            print("▶️ Resuming playback")
            player?.play()
            isPlaying = true
        }
    }

    private func skip(by seconds: Double) {
        guard let player = player else {
            print("⚠️ Cannot skip - player not initialized")
            return
        }

        let newTime = max(0, min(currentTime + seconds, duration))
        print("⏩ Skipping \(seconds)s - from \(currentTime)s to \(newTime)s")
        seek(to: newTime)
    }

    private func seek(to time: TimeInterval) {
        guard let player = player else { return }

        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
            if finished {
                print("✅ Seek completed to \(time)s")
                self.currentTime = time
            }
        }
    }

    private func addObservers(to player: AVPlayer) {
        print("🔍 Adding observers to player")

        let interval = CMTime(seconds: 0.2, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            if time.isValid && !time.isIndefinite && !isDragging {
                let newTime = time.seconds
                if abs(newTime - self.currentTime) > 0.1 {
                    self.currentTime = newTime
                }
            }
        }

        playbackObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            print("🏁 Playback finished")
            self.isPlaying = false
            self.currentTime = 0
            player.seek(to: .zero)
        }

        failureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { notification in
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                print("❌ Player failed to play: \(error)")
            }
        }

        // Monitor player item status
        if let playerItem = player.currentItem {
            print("📊 Player item status: \(playerItem.status.rawValue)")
            print("📊 Player item duration: \(playerItem.duration.seconds)")
        }
    }

    private func cleanup() {
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
            self.timeObserver = nil
        }
        if let observer = playbackObserver {
            NotificationCenter.default.removeObserver(observer)
            self.playbackObserver = nil
        }
        if let observer = failureObserver {
            NotificationCenter.default.removeObserver(observer)
            self.failureObserver = nil
        }
        player?.pause()
        player = nil
    }

    private func validateAudioURL() {
        print("🔍 Validating audio URL: \(audioURL)")

        // Check if URL is valid
        if audioURL.absoluteString.isEmpty {
            print("❌ Audio URL is empty")
            return
        }

        // For local file URLs, check if file exists
        if audioURL.isFileURL {
            let fileExists = FileManager.default.fileExists(atPath: audioURL.path)
            print("📁 Local file exists: \(fileExists) at path: \(audioURL.path)")

            if fileExists {
                // Get file size
                if let attributes = try? FileManager.default.attributesOfItem(atPath: audioURL.path),
                   let fileSize = attributes[.size] as? Int {
                    print("📊 File size: \(fileSize) bytes")
                }
            }
        } else {
            print("🌐 Remote URL: \(audioURL.absoluteString)")
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite && !time.isNaN else { return "0:00" }
        let totalSeconds = max(0, Int(time.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func shareAudio() {
        Task {
            await MainActor.run {
                isSharing = true
            }

            do {
                let data: Data
                let tempFileURL: URL

                // Ensure filename has proper extension
                var displayFileName = fileName ?? "audio.m4a"
                if !displayFileName.contains(".") {
                    // If no extension, try to detect from URL or default to .m4a
                    let urlExtension = audioURL.pathExtension
                    if !urlExtension.isEmpty {
                        displayFileName += ".\(urlExtension)"
                    } else {
                        displayFileName += ".m4a"
                    }
                }

                // If it's a local file, check if we need to copy it with proper extension
                if audioURL.isFileURL {
                    // If local file already has extension, use it directly
                    if !audioURL.pathExtension.isEmpty {
                        tempFileURL = audioURL
                    } else {
                        // Copy to temp with proper extension
                        let fileData = try Data(contentsOf: audioURL)
                        let tempDir = FileManager.default.temporaryDirectory
                        tempFileURL = tempDir.appendingPathComponent(displayFileName)
                        try fileData.write(to: tempFileURL)
                    }
                } else {
                    // Download remote file to temp directory
                    print("📥 Downloading audio file...")
                    (data, _) = try await URLSession.shared.data(from: audioURL)
                    print("✅ Audio file downloaded (\(data.count) bytes)")
                    let tempDir = FileManager.default.temporaryDirectory
                    tempFileURL = tempDir.appendingPathComponent(displayFileName)
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
                print("❌ Failed to share audio: \(error)")
                await MainActor.run {
                    isSharing = false
                }
            }
        }
    }
}