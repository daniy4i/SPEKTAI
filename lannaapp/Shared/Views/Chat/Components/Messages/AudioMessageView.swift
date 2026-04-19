//
//  AudioMessageView.swift
//  lannaapp
//
//  Extracted from ChatComponents.swift
//

import SwiftUI
import AVFoundation

struct AudioMessageView: View {
    let audioURL: URL
    let duration: TimeInterval
    let isFromUser: Bool

    var body: some View {
        let textColor = isFromUser ? Color.white.opacity(0.9) : DS.textSecondary
        let accentColor = isFromUser ? .white.opacity(0.9) : DS.primary

        AudioPlayerView(
            audioURL: audioURL,
            duration: duration,
            accentColor: accentColor,
            textColor: textColor
        )
    }
}