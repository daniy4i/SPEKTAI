//
//  SmartGlassesMediaTransferView.swift
//  lannaapp
//
//  Created by Codex on 02/15/2026.
//

import SwiftUI
import Photos
#if os(iOS)
import UIKit
#endif

struct SmartGlassesMediaTransferView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = SmartGlassesService.shared
    @StateObject private var transferService = SmartGlassesTransferService.shared
    @State private var selectedFiles: Set<String> = []
    @State private var showingPermissionAlert = false
    @State private var showingSuccessAlert = false
    @State private var downloadedResults: [DeviceMediaDownloadResult] = []
    @State private var transferError: String?
    @State private var showingTransferError = false
    @State private var isExportingToPhotos = false

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
            .navigationTitle("Media Transfer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }

                if case .connected = transferService.phase, !transferService.deviceFiles.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button(selectedFiles.isEmpty ? "Select All" : "Deselect All") {
                            if selectedFiles.isEmpty {
                                selectedFiles = Set(transferService.deviceFiles.map(\.id))
                            } else {
                                selectedFiles.removeAll()
                            }
                        }
                        .foregroundColor(.white)
                    }
                }
            }
        }
        .alert("Photo Library Access", isPresented: $showingPermissionAlert) {
#if os(iOS)
            Button("Open Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
#endif
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("To save media to your photo library, please enable photo access in Settings.")
        }
        .alert("Transfer Complete", isPresented: $showingSuccessAlert) {
            Button("Save to Photos") {
                exportToPhotos()
            }
            Button("Done", role: .cancel) { }
        } message: {
            Text("Successfully downloaded \(downloadedResults.count) file(s). Would you like to save them to your photo library?")
        }
        .alert("Transfer Error", isPresented: $showingTransferError, presenting: transferError) { _ in
            Button("OK", role: .cancel) { }
        } message: { error in
            Text(error)
        }
        .onAppear {
            if transferService.phase == .idle && service.isConnected {
                startInitialTransfer()
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
            transferStatusCard

            if case .connected = transferService.phase, !transferService.deviceFiles.isEmpty {
                mediaFilesList
                downloadControls
            }

            Spacer()
        }
        .padding()
    }

    private var transferStatusCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Transfer Status")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(statusDescription)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer()
            }

            if case .downloading(let current, let total) = transferService.phase {
                VStack(spacing: 8) {
                    ProgressView(value: Double(current), total: Double(total))
                        .progressViewStyle(LinearProgressViewStyle(tint: .white))
                        .background(Color.white.opacity(0.3))

                    Text("\(current) of \(total) files")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            // Action buttons based on state
            HStack(spacing: 12) {
                if transferService.phase == .idle {
                    Button("Start Transfer") {
                        startInitialTransfer()
                    }
                    .buttonStyle(PrimaryTransferButtonStyle())
                }

                if case .failed = transferService.phase {
                    Button("Retry") {
                        startInitialTransfer()
                    }
                    .buttonStyle(PrimaryTransferButtonStyle())
                }

                if transferService.phase != .idle && transferService.phase != .completed {
                    Button("Cancel") {
                        transferService.cancel()
                    }
                    .buttonStyle(SecondaryTransferButtonStyle())
                }

                if case .completed = transferService.phase {
                    Button("Start New Transfer") {
                        transferService.reset()
                        selectedFiles.removeAll()
                        downloadedResults.removeAll()
                    }
                    .buttonStyle(SecondaryTransferButtonStyle())
                }

                // Audio restoration button - always available when connected
                if service.isConnected {
                    Button("Restore Audio") {
                        Task {
                            await transferService.forceRestoreAudio()
                        }
                    }
                    .buttonStyle(SecondaryTransferButtonStyle())
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.15))
        .cornerRadius(16)
    }

    private var mediaFilesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Media Files")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Spacer()

                Text("\(transferService.deviceFiles.count) files")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(12)
            }

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(transferService.deviceFiles) { file in
                        MediaFileRow(
                            file: file,
                            isSelected: selectedFiles.contains(file.id)
                        ) { isSelected in
                            if isSelected {
                                selectedFiles.insert(file.id)
                            } else {
                                selectedFiles.remove(file.id)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private var downloadControls: some View {
        VStack(spacing: 12) {
            if !selectedFiles.isEmpty {
                Button("Download Selected (\(selectedFiles.count))") {
                    downloadSelectedFiles()
                }
                .buttonStyle(PrimaryTransferButtonStyle())
            }

            if !downloadedResults.isEmpty {
                Button("Save \(downloadedResults.count) Files to Photos") {
                    exportToPhotos()
                }
                .buttonStyle(SecondaryTransferButtonStyle())
            }
        }
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

            Text("Connect your smart glasses first to transfer media files.")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private var statusIcon: String {
        switch transferService.phase {
        case .idle:
            return "wifi"
        case .enablingWiFi:
            return "wifi.router"
        case .disconnectingWiFi:
            return "wifi.slash"
        case .connectingHotspot:
            return "wifi.router"
        case .connected:
            return "checkmark.circle.fill"
        case .listing:
            return "list.bullet"
        case .downloading:
            return "square.and.arrow.down"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    private var statusDescription: String {
        switch transferService.phase {
        case .idle:
            return "Ready to discover media files"
        case .enablingWiFi:
            return "Enabling Wi-Fi on glasses..."
        case .disconnectingWiFi:
            return "Disconnecting from current network..."
        case .connectingHotspot:
            return "Connecting to glasses hotspot..."
        case .connected:
            return "Connected - \(transferService.deviceFiles.count) files found"
        case .listing:
            return "Discovering media files..."
        case .downloading(let current, let total):
            return "Downloading file \(current) of \(total)..."
        case .completed:
            return "Transfer completed successfully"
        case .failed(let message):
            return "Error: \(message)"
        }
    }

    private func startInitialTransfer() {
        guard service.isConnected else { return }

        Task {
            do {
                try await transferService.prepareSession()
            } catch {
                transferError = error.localizedDescription
                showingTransferError = true
            }
        }
    }

    private func downloadSelectedFiles() {
        let filesToDownload = transferService.deviceFiles.filter { selectedFiles.contains($0.id) }

        Task {
            do {
                let results = try await transferService.download(files: filesToDownload)
                await MainActor.run {
                    downloadedResults = results
                    showingSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    transferError = error.localizedDescription
                    showingTransferError = true
                }
            }
        }
    }

    private func exportToPhotos() {
        guard !downloadedResults.isEmpty else { return }

        // Check photo library authorization
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)

        switch status {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized {
                        performPhotoExport()
                    } else {
                        showingPermissionAlert = true
                    }
                }
            }
        case .authorized:
            performPhotoExport()
        default:
            showingPermissionAlert = true
        }
    }

    private func performPhotoExport() {
        isExportingToPhotos = true

        Task {
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    for result in downloadedResults {
                        switch result.original.kind {
                        case .image:
                            PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: result.localURL)
                        case .video:
                            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: result.localURL)
                        case .audio, .unknown:
                            // Photos app doesn't support audio files directly
                            continue
                        }
                    }
                }

                await MainActor.run {
                    isExportingToPhotos = false
                    // Optionally show success message
                }
            } catch {
                await MainActor.run {
                    isExportingToPhotos = false
                    transferError = "Failed to save to Photos: \(error.localizedDescription)"
                    showingTransferError = true
                }
            }
        }
    }
}

struct MediaFileRow: View {
    let file: DeviceMediaFile
    let isSelected: Bool
    let onSelectionChanged: (Bool) -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button {
                onSelectionChanged(!isSelected)
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .green : .white.opacity(0.6))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: file.kind.systemIcon)
                        .font(.headline)
                        .foregroundColor(file.kind.color)

                    Text(file.name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()
                }

                HStack {
                    Text(file.kind.displayName)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    if file.sizeBytes > 0 {
                        Text("•")
                            .foregroundColor(.white.opacity(0.7))
                        Text(ByteCountFormatter.string(fromByteCount: Int64(file.sizeBytes), countStyle: .file))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    if let duration = file.duration {
                        Text("•")
                            .foregroundColor(.white.opacity(0.7))
                        Text(formatDuration(duration))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.white.opacity(isSelected ? 0.2 : 0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.green : Color.white.opacity(0.2), lineWidth: isSelected ? 2 : 1)
        )
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

extension DeviceMediaFile.Kind {
    var systemIcon: String {
        switch self {
        case .image:
            return "photo"
        case .video:
            return "video"
        case .audio:
            return "waveform"
        case .unknown:
            return "doc"
        }
    }

    var color: Color {
        switch self {
        case .image:
            return .blue
        case .video:
            return .red
        case .audio:
            return .orange
        case .unknown:
            return .gray
        }
    }

    var displayName: String {
        switch self {
        case .image:
            return "Image"
        case .video:
            return "Video"
        case .audio:
            return "Audio"
        case .unknown:
            return "File"
        }
    }
}

struct PrimaryTransferButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(Color(red: 0.1, green: 0.3, blue: 0.6))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(25)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryTransferButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.25))
            .cornerRadius(25)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    SmartGlassesMediaTransferView()
}