//
//  SmartGlassesEndpointDiscoveryView.swift
//  lannaapp
//
//  Debug view for discovering smart glasses HTTP endpoints
//

import SwiftUI

struct SmartGlassesEndpointDiscoveryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var discovery = SmartGlassesEndpointDiscovery()
    @StateObject private var service = SmartGlassesService.shared
    @StateObject private var transferService = SmartGlassesTransferService.shared

    @State private var showExportSheet = false
    @State private var exportText = ""
    @State private var isPreparingWiFi = false
    @State private var wifiError: String?

    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient

                VStack(spacing: 0) {
                    if !service.isConnected {
                        disconnectedState
                    } else if transferService.phase == .idle {
                        idleState
                    } else if transferService.phase == .connected {
                        discoveryContent
                    } else {
                        preparingState
                    }
                }
            }
            .navigationTitle("Endpoint Discovery")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        if transferService.phase != .idle {
                            transferService.reset()
                        }
                        dismiss()
                    }
                    .foregroundColor(.white)
                }

                if transferService.phase == .connected && !discovery.results.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Export") {
                            exportText = discovery.exportResults()
                            showExportSheet = true
                        }
                        .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showExportSheet) {
                exportSheet
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

    private var disconnectedState: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.6))

            Text("Glasses Not Connected")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Connect your smart glasses first to discover endpoints.")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var idleState: some View {
        VStack(spacing: 24) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 60))
                .foregroundColor(.white)

            Text("HTTP Endpoint Discovery")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 12) {
                Text("This tool will:")
                    .font(.headline)
                    .foregroundColor(.white)

                HStack(alignment: .top, spacing: 12) {
                    Text("1.")
                        .foregroundColor(.white)
                    Text("Enable WiFi hotspot on your glasses")
                        .foregroundColor(.white.opacity(0.9))
                }

                HStack(alignment: .top, spacing: 12) {
                    Text("2.")
                        .foregroundColor(.white)
                    Text("Test all possible HTTP endpoints")
                        .foregroundColor(.white.opacity(0.9))
                }

                HStack(alignment: .top, spacing: 12) {
                    Text("3.")
                        .foregroundColor(.white)
                    Text("Discover file listing patterns")
                        .foregroundColor(.white.opacity(0.9))
                }

                HStack(alignment: .top, spacing: 12) {
                    Text("4.")
                        .foregroundColor(.white)
                    Text("Find working download URLs")
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)

            if let error = wifiError {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.red.opacity(0.2))
                .cornerRadius(8)
            }

            Button(action: prepareWiFi) {
                HStack {
                    if isPreparingWiFi {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "play.fill")
                    }
                    Text(isPreparingWiFi ? "Preparing..." : "Start Discovery")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isPreparingWiFi ? Color.gray : Color.green)
                .cornerRadius(12)
            }
            .disabled(isPreparingWiFi)
            .padding(.horizontal)
        }
        .padding()
    }

    private var preparingState: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(2)

            Text(transferService.phase.description)
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("Please wait while we prepare the connection...")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private var discoveryContent: some View {
        VStack(spacing: 16) {
            // Status header
            VStack(spacing: 8) {
                if discovery.isDiscovering {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)

                    Text(discovery.discoveryProgress)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                } else if discovery.results.isEmpty {
                    Button("Start Scanning Endpoints") {
                        Task {
                            await discovery.discoverEndpoints()
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.green)
                    .cornerRadius(25)
                } else {
                    Text("✅ Discovery Complete")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("\(discovery.workingEndpoints.count) working endpoints found")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding()

            // Results list
            if !discovery.results.isEmpty {
                ScrollView {
                    VStack(spacing: 8) {
                        // Working endpoints first
                        if !discovery.workingEndpoints.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("✅ Working Endpoints")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal)

                                ForEach(discovery.results.filter { $0.success }) { result in
                                    EndpointResultRow(result: result, showDetails: true)
                                }
                            }
                        }

                        // Failed endpoints
                        VStack(alignment: .leading, spacing: 8) {
                            Text("❌ Failed Endpoints (\(discovery.results.filter { !$0.success }.count))")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal)

                            ForEach(discovery.results.filter { !$0.success }.prefix(10)) { result in
                                EndpointResultRow(result: result, showDetails: false)
                            }

                            if discovery.results.filter({ !$0.success }).count > 10 {
                                Text("... and \(discovery.results.filter { !$0.success }.count - 10) more failed")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
    }

    private var exportSheet: some View {
        NavigationView {
            ScrollView {
                Text(exportText)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
            .navigationTitle("Discovery Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        showExportSheet = false
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Copy") {
                        #if os(iOS)
                        UIPasteboard.general.string = exportText
                        #endif
                    }
                }
            }
        }
    }

    private func prepareWiFi() {
        isPreparingWiFi = true
        wifiError = nil

        Task {
            do {
                try await transferService.prepareSession()
                isPreparingWiFi = false
            } catch {
                await MainActor.run {
                    wifiError = error.localizedDescription
                    isPreparingWiFi = false
                }
            }
        }
    }
}

struct EndpointResultRow: View {
    let result: SmartGlassesEndpointDiscovery.EndpointTestResult
    let showDetails: Bool

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main row
            HStack {
                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.success ? .green : .red.opacity(0.6))

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.url)
                        .font(.caption)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if let statusCode = result.statusCode {
                        Text("HTTP \(statusCode)")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    } else if let error = result.error {
                        Text(error)
                            .font(.caption2)
                            .foregroundColor(.red.opacity(0.8))
                            .lineLimit(1)
                    }
                }

                Spacer()

                if result.success && showDetails {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
            }

            // Expanded details
            if isExpanded && showDetails {
                VStack(alignment: .leading, spacing: 4) {
                    if let contentType = result.contentType {
                        Text("Content-Type: \(contentType)")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    if let size = result.responseSize {
                        Text("Size: \(formatBytes(size))")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    if let preview = result.responsePreview {
                        Text("Response:")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))

                        Text(preview)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(8)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(4)
                    }
                }
                .padding(.leading, 28)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.white.opacity(result.success ? 0.15 : 0.05))
        .cornerRadius(8)
        .padding(.horizontal, 8)
    }

    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

extension SmartGlassesTransferPhase {
    var description: String {
        switch self {
        case .idle:
            return "Ready"
        case .enablingWiFi:
            return "Enabling WiFi hotspot..."
        case .disconnectingWiFi:
            return "Disconnecting from current WiFi..."
        case .connectingHotspot:
            return "Connecting to hotspot..."
        case .connected:
            return "Connected"
        case .listing:
            return "Listing files..."
        case .downloading(let current, let total):
            return "Downloading \(current)/\(total)..."
        case .completed:
            return "Completed"
        case .failed(let message):
            return "Failed: \(message)"
        }
    }
}

#Preview {
    SmartGlassesEndpointDiscoveryView()
}
