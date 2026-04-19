//
//  VideoMessageView.swift
//  lannaapp
//
//  Extracted from ChatComponents.swift
//

import SwiftUI
import AVFoundation
#if os(iOS)
import AVKit
#endif

struct VideoMessageView: View {
    let videoURL: URL
    let thumbnailURL: URL

    @State private var showingPlayer = false
    @State private var player: AVPlayer?

    var body: some View {
        Button(action: {
            showingPlayer = true
            setupPlayer()
        }) {
            AsyncImage(url: thumbnailURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(DS.surface)
                    .overlay(
                        Image(systemName: "video.fill")
                            .font(.system(size: 24))
                            .foregroundColor(DS.textSecondary)
                    )
            }
            .frame(width: 200, height: 150)
            .clipped()
            .cornerRadius(DS.cornerRadius)
            .overlay(
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            )
        }
        .buttonStyle(PlainButtonStyle())
        #if os(iOS)
        .fullScreenCover(isPresented: $showingPlayer) {
            if let player = player {
                VideoPlayer(player: player)
                    .onDisappear {
                        player.pause()
                    }
            }
        }
        #else
        .sheet(isPresented: $showingPlayer) {
            if let player = player {
                VideoPlayerView(player: player)
                    .onDisappear {
                        player.pause()
                    }
            }
        }
        #endif
    }

    private func setupPlayer() {
        player = AVPlayer(url: videoURL)
    }
}

#if os(macOS)
struct VideoPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.player = player
        playerView.controlsStyle = .default
        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}
#endif