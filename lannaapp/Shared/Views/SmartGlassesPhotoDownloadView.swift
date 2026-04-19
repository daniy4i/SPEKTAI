//
//  SmartGlassesPhotoDownloadView.swift
//  lannaapp
//
//  Created by Codex on 02/15/2026.
//

import SwiftUI
import Photos

struct SmartGlassesPhotoDownloadView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = SmartGlassesService.shared
    @State private var mediaCount: (photos: Int, videos: Int, audio: Int, totalSize: Int)?
    @State private var isLoading = false
    @State private var statusMessage: String = ""

    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient

                VStack(spacing: 0) {
                    if service.isConnected {
                        mainContent
                    } else {
                        disconnectedState
                    }
                }
            }
            .navigationTitle("Device Media")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            Task {
                await loadMediaCount()
            }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.1, green: 0.3, blue: 0.6),
                Color(red: 0.2, green: 0.5, blue: 0.8)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var mainContent: some View {
        VStack(spacing: 20) {
            mediaInfoCard

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal)
            }

            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                    .padding()
            }

            Spacer()
        }
        .padding()
    }

    private var mediaInfoCard: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.title)
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Photos on Glasses")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    if let count = mediaCount {
                        Text("\(count.photos) photos • \(count.videos) videos • \(count.audio) audio")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    } else {
                        Text("Loading...")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }

                Spacer()
            }

            Divider()
                .background(Color.white.opacity(0.3))

            // Important notice
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.yellow)

                Text("Bluetooth Download Not Available")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("The SDK's getThumbnail function returns empty image data over Bluetooth.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)

            // Instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("To Download Photos:")
                    .font(.headline)
                    .foregroundColor(.white)

                HStack(alignment: .top, spacing: 12) {
                    Text("1.")
                        .foregroundColor(.white)
                    Text("Close this view and use \"Sync Files to Device\" button")
                        .foregroundColor(.white.opacity(0.9))
                }

                HStack(alignment: .top, spacing: 12) {
                    Text("2.")
                        .foregroundColor(.white)
                    Text("Wait for WiFi hotspot connection")
                        .foregroundColor(.white.opacity(0.9))
                }

                HStack(alignment: .top, spacing: 12) {
                    Text("3.")
                        .foregroundColor(.white)
                    Text("Select and download full resolution photos")
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)

            // Action button
            Button("Use WiFi Transfer Instead") {
                dismiss()
            }
            .font(.headline)
            .foregroundColor(Color(red: 0.1, green: 0.3, blue: 0.6))
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color.white)
            .cornerRadius(25)
        }
        .padding()
        .background(Color.white.opacity(0.15))
        .cornerRadius(16)
    }

    private var disconnectedState: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.6))

            Text("Glasses Not Connected")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Connect your smart glasses first to check media.")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private func loadMediaCount() async {
        await MainActor.run {
            statusMessage = "Checking device media..."
            isLoading = true
        }

        defer {
            Task { @MainActor in
                isLoading = false
            }
        }

        #if canImport(QCSDK) && os(iOS)
        mediaCount = await service.getDeviceMediaCount()
        #else
        mediaCount = nil
        #endif

        if let count = mediaCount {
            await MainActor.run {
                statusMessage = "Found \(count.photos) photos on your glasses"
            }
        } else {
            await MainActor.run {
                statusMessage = "Could not fetch media count"
            }
        }
    }
}

#Preview {
    SmartGlassesPhotoDownloadView()
}