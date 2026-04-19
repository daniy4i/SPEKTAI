//
//  SmartGlassesTransferService.swift
//  lannaapp
//
//  Created by Codex on 02/15/2026.
//

import Foundation
import os.log

#if os(iOS)
import NetworkExtension
#endif

/// High-level phases for orchestrating a Wi-Fi media transfer session with the headset.
enum SmartGlassesTransferPhase: Equatable {
    case idle
    case enablingWiFi
    case disconnectingWiFi
    case connectingHotspot
    case connected
    case listing
    case downloading(current: Int, total: Int)
    case completed
    case failed(String)
}

/// Minimal description of a media file that lives on the headset.
struct DeviceMediaFile: Identifiable, Equatable {
    enum Kind: CustomStringConvertible {
        case image
        case video
        case audio
        case unknown

        var description: String {
            switch self {
            case .image: return "image"
            case .video: return "video"
            case .audio: return "audio"
            case .unknown: return "unknown"
            }
        }
    }

    let id: String
    let name: String
    let kind: Kind
    let sizeBytes: Int
    let duration: TimeInterval?
    let createdAt: Date?
}

/// Result for a download request, representing where the file was placed on device storage.
struct DeviceMediaDownloadResult {
    let original: DeviceMediaFile
    let localURL: URL
}

/// Errors specific to the Wi-Fi transfer pipeline.
enum SmartGlassesTransferError: LocalizedError {
    case wifiCredentialsUnavailable
    case hotspotConfigurationUnsupported
    case hotspotConnectionFailed(String)
    case mediaListUnavailable
    case downloadFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .wifiCredentialsUnavailable:
            return "Unable to retrieve Wi-Fi credentials from the headset."
        case .hotspotConfigurationUnsupported:
            return "Wi-Fi hotspot configuration is not available on this platform."
        case .hotspotConnectionFailed(let message):
            return "Failed to join headset hotspot: \(message)."
        case .mediaListUnavailable:
            return "Unable to query media list from the headset."
        case .downloadFailed(let message):
            return "Failed to download media: \(message)."
        case .cancelled:
            return "Transfer cancelled."
        }
    }
}

/// Orchestrates the Wi-Fi workflow to pull media off the headset onto the device.
@MainActor
final class SmartGlassesTransferService: ObservableObject {
    static let shared = SmartGlassesTransferService()

    @Published private(set) var phase: SmartGlassesTransferPhase = .idle
    @Published private(set) var deviceFiles: [DeviceMediaFile] = []

    private let service = SmartGlassesService.shared
    private let logger = Logger(subsystem: "com.lannaapp", category: "SmartGlassesTransfer")

    private init() {}

    /// Convenience flag to determine whether a transfer can start.
    var canStartTransfer: Bool { service.isConnected && phase == .idle }

    /// Force restore audio functionality if headset is stuck in silent mode
    func forceRestoreAudio() async {
        await restoreNormalMode()
    }

    /// Resets state back to idle and ensures audio is restored.
    func reset() {
        phase = .idle
        deviceFiles.removeAll()

        // Always restore headset to normal operation mode
        Task {
            await restoreNormalMode()
        }
    }

    /// Public entry point – prepares Wi-Fi credentials, connects to the hotspot, and lists available files.
    func prepareSession() async throws {
        guard service.isConnected else {
            throw SmartGlassesTransferError.wifiCredentialsUnavailable
        }

        logger.debug("SmartGlassesTransfer: starting session prep")
        phase = .enablingWiFi

        // Step 1: Set device to transfer mode to disable audio and prepare for hotspot
        logger.debug("SmartGlassesTransfer: setting device to transfer mode")
        await service.setDeviceMode(.transfer)

        // Step 2: Disable audio/speaking mode to ensure headset audio is muted
        logger.debug("SmartGlassesTransfer: disabling audio output")
        await service.setAISpeakMode(.stop)

        // Step 3: Enable WiFi hotspot for transfer mode
        logger.debug("SmartGlassesTransfer: opening WiFi credentials")
        guard let credentials = await service.openWiFiCredentials(for: .transfer) else {
            phase = .failed(SmartGlassesTransferError.wifiCredentialsUnavailable.localizedDescription)
            throw SmartGlassesTransferError.wifiCredentialsUnavailable
        }

        // Log the actual credentials received
        logger.debug("SmartGlassesTransfer: 🔑 Received WiFi credentials")
        logger.debug("SmartGlassesTransfer: 🔑 SSID: '\(credentials.ssid)' (length: \(credentials.ssid.count))")
        logger.debug("SmartGlassesTransfer: 🔑 Password: '\(credentials.password)' (length: \(credentials.password.count))")

        // Step 4: Wait longer for the headset to fully switch modes and start web server
        logger.debug("SmartGlassesTransfer: waiting 15 seconds for headset to fully enable hotspot...")
        try await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds

        // Step 5: Refresh diagnostics to get the current IP address
        await service.refreshAdvancedStatus()
        let reportedIP = service.advancedStatus.wifiIPAddress
        logger.debug("SmartGlassesTransfer: Glasses reported IP: \(reportedIP ?? "nil")")

        let ipAddress = reportedIP ?? "192.168.31.1" // Default to known IP
        logger.debug("SmartGlassesTransfer: Using IP address: \(ipAddress)")
        logger.debug("SmartGlassesTransfer: headset should now be in hotspot mode, IP: \(ipAddress)")

        #if os(iOS)
        phase = .disconnectingWiFi
        logger.debug("SmartGlassesTransfer: disconnecting from current WiFi network")
        
        phase = .connectingHotspot
        try await connectToHotspot(ssid: credentials.ssid, passphrase: credentials.password)

        // Wait additional time after WiFi connects for web server to fully initialize
        logger.debug("SmartGlassesTransfer: waiting 3 seconds for web server to initialize...")
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds

        // Verify network connectivity after hotspot connection
        logger.debug("SmartGlassesTransfer: verifying network connectivity to \(ipAddress)")
        try await verifyNetworkConnectivity(ipAddress: ipAddress)
        #else
        throw SmartGlassesTransferError.hotspotConfigurationUnsupported
        #endif

        logger.debug("SmartGlassesTransfer: hotspot joined, IP = \(ipAddress ?? "n/a")")
        phase = .listing
        deviceFiles = try await fetchDeviceMediaList(ipAddress: ipAddress)
        phase = .connected
    }

    /// Downloads the provided files sequentially into the app's temporary directory.
    func download(files: [DeviceMediaFile]) async throws -> [DeviceMediaDownloadResult] {
        guard !files.isEmpty else { return [] }

        var results: [DeviceMediaDownloadResult] = []
        for (index, file) in files.enumerated() {
            phase = .downloading(current: index + 1, total: files.count)
            let localURL = try await downloadFile(file)
            results.append(DeviceMediaDownloadResult(original: file, localURL: localURL))
        }

        phase = .completed

        // Restore normal mode after successful download
        await restoreNormalMode()

        return results
    }

    /// Cancels the current workflow and resets state.
    func cancel() {
        logger.debug("SmartGlassesTransfer: cancelling session")
        Task {
            await restoreNormalMode()
        }
        reset()
    }

    // MARK: - Private Helpers

    #if os(iOS)
    private func connectToHotspot(ssid: String, passphrase: String) async throws {
        logger.debug("SmartGlassesTransfer: 🔧 Starting WiFi connection process for SSID: \(ssid)")

        // Step 1: Check if already connected to this network (if possible)
        // Note: NEHotspotNetwork.fetchCurrent() requires "Access WiFi Information" capability
        // and may return nil or error without proper entitlements
        var currentNetworkSSID: String?
        if #available(iOS 14.0, *) {
            do {
                if let currentSSID = await NEHotspotNetwork.fetchCurrent()?.ssid {
                    currentNetworkSSID = currentSSID
                    logger.debug("SmartGlassesTransfer: Currently connected to: \(currentSSID)")
                    if currentSSID == ssid {
                        logger.debug("SmartGlassesTransfer: ✅ Already connected to target network!")
                        return
                    }
                } else {
                    logger.debug("SmartGlassesTransfer: Cannot determine current WiFi (missing entitlement or not connected)")
                }
            } catch {
                logger.debug("SmartGlassesTransfer: Cannot check current WiFi: \(error.localizedDescription)")
            }
        }

        // Step 2: Properly disconnect from current network first
        logger.debug("SmartGlassesTransfer: 📱 Ensuring clean disconnection from current network")
        try await ensureWiFiDisconnection(currentSSID: currentNetworkSSID, targetSSID: ssid)

        // Step 3: Create new configuration
        let configuration = NEHotspotConfiguration(ssid: ssid, passphrase: passphrase, isWEP: false)
        configuration.joinOnce = false  // Persist the connection during transfer

        logger.debug("SmartGlassesTransfer: 📡 Attempting to connect to hotspot SSID: \(ssid)")

        // Step 4: Retry mechanism with proper error code handling
        var lastError: Error?

        for attempt in 1...5 { // Increased to 5 attempts
            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    NEHotspotConfigurationManager.shared.apply(configuration) { error in
                        if let error = error {
                            let nsError = error as NSError
                            let errorCode = nsError.code

                            self.logger.debug("SmartGlassesTransfer: Attempt \(attempt) error code: \(errorCode)")

                            // Handle specific error codes
                            switch errorCode {
                            case 13: // NEHotspotConfigurationError.alreadyAssociated
                                // This can mean success OR weak association - treat as success
                                self.logger.debug("SmartGlassesTransfer: ✅ Already associated (code 13) - treating as success")
                                continuation.resume(returning: ())

                            case 7: // NEHotspotConfigurationError.userDenied
                                self.logger.debug("SmartGlassesTransfer: ❌ User denied connection request")
                                continuation.resume(throwing: SmartGlassesTransferError.hotspotConnectionFailed("User denied WiFi connection"))

                            case 8: // NEHotspotConfigurationError.internal
                                // Internal error - retry might help
                                self.logger.debug("SmartGlassesTransfer: ⚠️ Internal error (code 8) - will retry")
                                continuation.resume(throwing: SmartGlassesTransferError.hotspotConnectionFailed("Internal iOS error"))

                            case 14: // NEHotspotConfigurationError.applicationIsNotInForeground
                                self.logger.debug("SmartGlassesTransfer: ❌ App is not in foreground")
                                continuation.resume(throwing: SmartGlassesTransferError.hotspotConnectionFailed("App must be in foreground"))

                            default:
                                self.logger.debug("SmartGlassesTransfer: ❌ Error: \(error.localizedDescription)")
                                continuation.resume(throwing: SmartGlassesTransferError.hotspotConnectionFailed(error.localizedDescription))
                            }
                        } else {
                            self.logger.debug("SmartGlassesTransfer: ✅ Connection successful (attempt \(attempt))")
                            continuation.resume(returning: ())
                        }
                    }
                }

                // Connection succeeded - verify it's actually working
                logger.debug("SmartGlassesTransfer: Connection API succeeded, waiting for network to stabilize...")
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds for network to stabilize

                // Verify we can actually use the network (if entitlements allow)
                if #available(iOS 14.0, *) {
                    do {
                        if let currentSSID = await NEHotspotNetwork.fetchCurrent()?.ssid {
                            logger.debug("SmartGlassesTransfer: Verified connected to: \(currentSSID)")
                            if currentSSID == ssid {
                                logger.debug("SmartGlassesTransfer: ✅ Verified connection to target network!")
                                return
                            } else {
                                logger.debug("SmartGlassesTransfer: ⚠️ Connected to wrong network: \(currentSSID) instead of \(ssid)")
                                // Don't throw - maybe we're still connecting
                            }
                        } else {
                            logger.debug("SmartGlassesTransfer: Cannot verify connection (missing entitlement)")
                        }
                    } catch {
                        logger.debug("SmartGlassesTransfer: Cannot verify connection: \(error.localizedDescription)")
                    }
                }

                // Can't verify or verification inconclusive - assume success based on API response
                logger.debug("SmartGlassesTransfer: ✅ Connection assumed successful based on API response")
                return

            } catch {
                lastError = error
                if attempt < 5 {
                    let delay = TimeInterval(attempt) * 2.0 // Exponential backoff: 2s, 4s, 6s, 8s
                    logger.debug("SmartGlassesTransfer: Retrying in \(delay) seconds...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                    // Remove config again before retry
                    NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: ssid)
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                }
            }
        }

        // All attempts failed
        logger.debug("SmartGlassesTransfer: ❌ All connection attempts failed")
        throw lastError ?? SmartGlassesTransferError.hotspotConnectionFailed("Failed to connect after 5 attempts")
    }

    /// Ensures the device is properly disconnected from current WiFi before connecting to smart glasses
    private func ensureWiFiDisconnection(currentSSID: String?, targetSSID: String) async throws {
        logger.debug("SmartGlassesTransfer: 🔄 Starting WiFi disconnection process")
        
        // Step 1: Remove target network configuration to avoid conflicts
        logger.debug("SmartGlassesTransfer: Removing target network configuration: \(targetSSID)")
        NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: targetSSID)
        
        // Step 2: If we know the current network, remove it as well to force disconnection
        if let currentSSID = currentSSID, currentSSID != targetSSID {
            logger.debug("SmartGlassesTransfer: Removing current network configuration: \(currentSSID)")
            NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: currentSSID)
        }
        
        // Step 3: Wait for iOS to process the removal and disconnect
        logger.debug("SmartGlassesTransfer: ⏳ Waiting 3 seconds for network disconnection...")
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds for proper disconnection
        
        // Step 4: Verify disconnection by checking current network status
        if #available(iOS 14.0, *) {
            for attempt in 1...5 {
                do {
                    if let stillConnectedSSID = await NEHotspotNetwork.fetchCurrent()?.ssid {
                        if stillConnectedSSID == currentSSID {
                            logger.debug("SmartGlassesTransfer: Still connected to \(stillConnectedSSID), waiting longer (attempt \(attempt))...")
                            try await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 more seconds
                        } else {
                            logger.debug("SmartGlassesTransfer: Network changed to: \(stillConnectedSSID)")
                            break
                        }
                    } else {
                        logger.debug("SmartGlassesTransfer: ✅ Successfully disconnected from WiFi")
                        break
                    }
                } catch {
                    logger.debug("SmartGlassesTransfer: Cannot verify disconnection status: \(error.localizedDescription)")
                    break // Continue anyway if we can't verify
                }
                
                if attempt == 5 {
                    logger.debug("SmartGlassesTransfer: ⚠️ May still be connected after 5 attempts, continuing anyway")
                }
            }
        }
        
        // Step 5: Additional wait to ensure clean state before connection attempt
        logger.debug("SmartGlassesTransfer: ⏳ Final stabilization wait...")
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds final wait
        
        logger.debug("SmartGlassesTransfer: ✅ WiFi disconnection process complete")
    }
    #endif

    private func verifyNetworkConnectivity(ipAddress: String?) async throws {
        guard let ipAddress else {
            throw SmartGlassesTransferError.hotspotConnectionFailed("No IP address available for connectivity test")
        }

        logger.debug("SmartGlassesTransfer: testing connectivity to media endpoint")

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 5.0  // Increased timeout
        configuration.timeoutIntervalForResource = 10.0
        configuration.allowsCellularAccess = false
        configuration.waitsForConnectivity = false

        let session = URLSession(configuration: configuration)

        // Try multiple possible IP addresses
        let possibleIPs = [
            ipAddress,
            "192.168.31.1",  // Common hotspot IP
            "192.168.1.1",   // Another common gateway
            "192.168.43.1",  // Android hotspot default
            "172.20.10.1"    // iOS hotspot default
        ]

        for testIP in possibleIPs {
            guard let testURL = URL(string: "http://\(testIP)/files/media.config") else { continue }

            logger.debug("SmartGlassesTransfer: trying IP \(testIP)...")

            for attempt in 1...2 {
                do {
                    logger.debug("SmartGlassesTransfer: connectivity test attempt \(attempt) to \(testURL.absoluteString)")
                    let (data, response) = try await session.data(from: testURL)

                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                        logger.debug("SmartGlassesTransfer: ✅ WiFi connection verified at \(testIP)")
                        // Update the service with the working IP
                        #if canImport(QCSDK) && os(iOS)
                        await service.modifyAdvancedStatus { $0.wifiIPAddress = testIP }
                        #endif
                        return
                    }
                } catch {
                    logger.debug("SmartGlassesTransfer: IP \(testIP) attempt \(attempt) failed: \(error.localizedDescription)")
                    if attempt < 2 {
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                }
            }
        }

        throw SmartGlassesTransferError.hotspotConnectionFailed("Could not reach web server at any known IP address")
    }

    private func fetchDeviceMediaList(ipAddress: String?) async throws -> [DeviceMediaFile] {
        guard let ipAddress else {
            throw SmartGlassesTransferError.mediaListUnavailable
        }

        // First, try to get media count from Bluetooth to validate we have media to discover
        logger.debug("SmartGlassesTransfer: checking Bluetooth media count before HTTP discovery")
        #if canImport(QCSDK) && os(iOS)
        let bluetoothMediaCount = await service.getDeviceMediaCount()
        #else
        let bluetoothMediaCount: (photos: Int, videos: Int, audio: Int, totalSize: Int)? = nil
        #endif
        if let mediaCount = bluetoothMediaCount {
            logger.debug("SmartGlassesTransfer: Bluetooth reports \(mediaCount.photos) photos, \(mediaCount.videos) videos, \(mediaCount.audio) audio files")
            if mediaCount.photos == 0 && mediaCount.videos == 0 && mediaCount.audio == 0 {
                logger.debug("SmartGlassesTransfer: No media files on device according to Bluetooth")
                return []
            }
        } else {
            logger.debug("SmartGlassesTransfer: ⚠️ Could not get Bluetooth media count, proceeding with HTTP discovery anyway")
        }

        // First fetch the media config to understand the available endpoints
        guard let configURL = URL(string: "http://\(ipAddress)/files/media.config") else {
            throw SmartGlassesTransferError.mediaListUnavailable
        }

        logger.debug("SmartGlassesTransfer: fetching media config from \(configURL.absoluteString, privacy: .public)")

        // Create custom URLSession configuration for local network requests
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15.0
        configuration.timeoutIntervalForResource = 30.0
        configuration.allowsCellularAccess = false
        configuration.waitsForConnectivity = false

        let session = URLSession(configuration: configuration)

        // Retry logic for config fetch
        var lastError: Error?
        for attempt in 1...3 {
            do {
                logger.debug("SmartGlassesTransfer: config fetch attempt \(attempt)")
                let (configData, configResponse) = try await session.data(from: configURL)

                guard let http = configResponse as? HTTPURLResponse else {
                    logger.debug("SmartGlassesTransfer: Invalid response type for config request (attempt \(attempt))")
                    throw SmartGlassesTransferError.mediaListUnavailable
                }

                logger.debug("SmartGlassesTransfer: HTTP status \(http.statusCode) for config request (attempt \(attempt))")

                guard (200..<300).contains(http.statusCode) else {
                    logger.debug("SmartGlassesTransfer: HTTP error \(http.statusCode) for config request (attempt \(attempt))")
                    throw SmartGlassesTransferError.mediaListUnavailable
                }

                // Success - parse and return
                let configString = String(data: configData, encoding: .utf8) ?? ""
                logger.debug("SmartGlassesTransfer: received config: \(configString)")

                // Continue with list fetching...
                guard let listURL = URL(string: "http://\(ipAddress)/files/list") else {
                    throw SmartGlassesTransferError.mediaListUnavailable
                }

                return try await fetchMediaListWithRetry(session: session, listURL: listURL, ipAddress: ipAddress)

            } catch {
                lastError = error
                logger.debug("SmartGlassesTransfer: config fetch attempt \(attempt) failed: \(error.localizedDescription)")

                if attempt < 3 {
                    let delay = TimeInterval(attempt * 3) // 3, 6 seconds
                    logger.debug("SmartGlassesTransfer: waiting \(delay) seconds before retry...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        // All attempts failed
        logger.debug("SmartGlassesTransfer: All config fetch attempts failed")
        throw lastError ?? SmartGlassesTransferError.mediaListUnavailable
    }

    private func fetchMediaListWithRetry(session: URLSession, listURL: URL, ipAddress: String) async throws -> [DeviceMediaFile] {

        logger.debug("SmartGlassesTransfer: fetching media list from \(listURL.absoluteString, privacy: .public)")

        do {
            let (listData, listResponse) = try await session.data(from: listURL)
            guard let httpList = listResponse as? HTTPURLResponse, (200..<300).contains(httpList.statusCode) else {
                throw SmartGlassesTransferError.mediaListUnavailable
            }

            // Try to parse as JSON first
            if let json = try? JSONSerialization.jsonObject(with: listData) as? [String: Any] {
                return parseMediaListJSON(json, ipAddress: ipAddress)
            }

            // If JSON fails, try to parse as plain text file list
            if let listString = String(data: listData, encoding: .utf8) {
                return parseMediaListText(listString, ipAddress: ipAddress)
            }

        } catch {
            logger.debug("SmartGlassesTransfer: list endpoint failed, trying media discovery endpoints")
        }

        // Fallback: try common media discovery endpoints
        return try await discoverMediaFiles(ipAddress: ipAddress)
    }

    private func parseMediaListJSON(_ json: [String: Any], ipAddress: String) -> [DeviceMediaFile] {
        var files: [DeviceMediaFile] = []

        // Try different possible JSON structures
        if let fileList = json["files"] as? [[String: Any]] {
            for fileInfo in fileList {
                if let file = parseMediaFileInfo(fileInfo, ipAddress: ipAddress) {
                    files.append(file)
                }
            }
        } else if let mediaList = json["media"] as? [[String: Any]] {
            for fileInfo in mediaList {
                if let file = parseMediaFileInfo(fileInfo, ipAddress: ipAddress) {
                    files.append(file)
                }
            }
        }

        return files
    }

    private func parseMediaListText(_ text: String, ipAddress: String) -> [DeviceMediaFile] {
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var files: [DeviceMediaFile] = []

        for line in lines {
            // Parse different possible formats:
            // filename.jpg 1024 2024-01-01T12:00:00Z
            // filename.mp4,video,2048,30.5
            let components = line.components(separatedBy: CharacterSet(charactersIn: ", \t"))

            guard let fileName = components.first, !fileName.isEmpty else { continue }

            let kind = determineFileKind(from: fileName)
            let sizeBytes = components.count > 1 ? Int(components[1]) ?? 0 : 0
            let duration = kind == .video || kind == .audio ? (components.count > 3 ? TimeInterval(components[3]) : nil) : nil

            let file = DeviceMediaFile(
                id: fileName,
                name: fileName,
                kind: kind,
                sizeBytes: sizeBytes,
                duration: duration,
                createdAt: nil
            )
            files.append(file)
        }

        return files
    }

    private func parseMediaFileInfo(_ fileInfo: [String: Any], ipAddress: String) -> DeviceMediaFile? {
        guard let fileName = fileInfo["name"] as? String ?? fileInfo["filename"] as? String else {
            return nil
        }

        let kind = determineFileKind(from: fileName)
        let sizeBytes = fileInfo["size"] as? Int ?? fileInfo["fileSize"] as? Int ?? 0
        let duration = fileInfo["duration"] as? TimeInterval

        var createdAt: Date?
        if let timestamp = fileInfo["created"] as? String ?? fileInfo["createdAt"] as? String {
            createdAt = ISO8601DateFormatter().date(from: timestamp)
        }

        return DeviceMediaFile(
            id: fileName,
            name: fileName,
            kind: kind,
            sizeBytes: sizeBytes,
            duration: duration,
            createdAt: createdAt
        )
    }

    private func determineFileKind(from fileName: String) -> DeviceMediaFile.Kind {
        let lowercased = fileName.lowercased()
        let pathExtension = (fileName as NSString).pathExtension.lowercased()

        // Image formats (including common smartphone formats)
        let imageExtensions = ["jpg", "jpeg", "png", "bmp", "gif", "tiff", "tif", "webp", "heic", "heif"]
        if imageExtensions.contains(pathExtension) {
            return .image
        }
        
        // Video formats (including common smartphone formats)
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "m4v", "3gp", "webm", "flv", "wmv", "mpg", "mpeg"]
        if videoExtensions.contains(pathExtension) {
            return .video
        }
        
        // Audio formats (including voice memo formats)
        let audioExtensions = ["mp3", "wav", "aac", "m4a", "flac", "ogg", "wma", "amr", "opus"]
        if audioExtensions.contains(pathExtension) {
            return .audio
        }
        
        // Fallback: check by common filename patterns for smart glasses
        if lowercased.contains("photo") || lowercased.contains("img") || lowercased.contains("picture") {
            return .image
        } else if lowercased.contains("video") || lowercased.contains("movie") || lowercased.contains("record") {
            return .video
        } else if lowercased.contains("audio") || lowercased.contains("voice") || lowercased.contains("sound") {
            return .audio
        }
        
        return .unknown
    }

    private func discoverMediaFiles(ipAddress: String) async throws -> [DeviceMediaFile] {
        var files: [DeviceMediaFile] = []

        // Enhanced discovery endpoints with more comprehensive patterns
        let discoveryEndpoints = [
            "/files/photos",
            "/files/videos", 
            "/files/audio",
            "/files/media",
            "/files/list",
            "/files/index",
            "/media",
            "/media/list",
            "/media/photos",
            "/media/videos",
            "/media/audio", 
            "/photos",
            "/videos",
            "/audio",
            "/gallery",
            "/download/list",
            "/api/media",
            "/api/files"
        ]

        logger.debug("SmartGlassesTransfer: trying \(discoveryEndpoints.count) discovery endpoints")

        for endpoint in discoveryEndpoints {
            guard let url = URL(string: "http://\(ipAddress)\(endpoint)") else { continue }

            do {
                logger.debug("SmartGlassesTransfer: trying endpoint \(endpoint)")
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    logger.debug("SmartGlassesTransfer: endpoint \(endpoint) returned HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                    continue
                }

                logger.debug("SmartGlassesTransfer: ✅ endpoint \(endpoint) responded successfully (\(data.count) bytes)")

                // Try parsing as JSON first
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let parsedFiles = parseMediaListJSON(json, ipAddress: ipAddress)
                    logger.debug("SmartGlassesTransfer: parsed \(parsedFiles.count) files from JSON at \(endpoint)")
                    files.append(contentsOf: parsedFiles)
                } 
                // Try parsing as JSON array
                else if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    for fileInfo in jsonArray {
                        if let file = parseMediaFileInfo(fileInfo, ipAddress: ipAddress) {
                            files.append(file)
                        }
                    }
                    logger.debug("SmartGlassesTransfer: parsed \(files.count) files from JSON array at \(endpoint)")
                }
                // Try parsing as plain text
                else if let text = String(data: data, encoding: .utf8), !text.trimmingCharacters(in: .whitespaces).isEmpty {
                    let parsedFiles = parseMediaListText(text, ipAddress: ipAddress)
                    logger.debug("SmartGlassesTransfer: parsed \(parsedFiles.count) files from text at \(endpoint)")
                    files.append(contentsOf: parsedFiles)
                }
                else {
                    logger.debug("SmartGlassesTransfer: ⚠️ endpoint \(endpoint) returned unrecognized format")
                    // Log a preview of the response for debugging
                    if let preview = String(data: data.prefix(200), encoding: .utf8) {
                        logger.debug("SmartGlassesTransfer: response preview: \(preview)")
                    }
                }

                // If we found files, we can return early (unless we want to merge from multiple endpoints)
                if !files.isEmpty {
                    logger.debug("SmartGlassesTransfer: ✅ Successfully discovered \(files.count) media files")
                    break
                }
                
            } catch {
                logger.debug("SmartGlassesTransfer: discovery endpoint \(endpoint) failed: \(error)")
                continue
            }
        }

        if files.isEmpty {
            logger.debug("SmartGlassesTransfer: ⚠️ No media files discovered through any HTTP endpoint")
        }

        return files
    }

    private func downloadFile(_ file: DeviceMediaFile) async throws -> URL {
        guard let ipAddress = service.advancedStatus.wifiIPAddress else {
            throw SmartGlassesTransferError.downloadFailed("Device IP address not available")
        }

        // Try multiple possible download endpoints
        let downloadURLs = [
            "http://\(ipAddress)/files/\(file.name)",
            "http://\(ipAddress)/media/\(file.name)",
            "http://\(ipAddress)/download/\(file.name)",
            "http://\(ipAddress)/\(file.name)"
        ]

        var lastError: Error?

        for urlString in downloadURLs {
            guard let downloadURL = URL(string: urlString) else { continue }

            do {
                logger.debug("SmartGlassesTransfer: attempting download from \(downloadURL.absoluteString, privacy: .public)")

                // Create download request with timeout
                var request = URLRequest(url: downloadURL)
                request.timeoutInterval = 30.0

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    continue
                }

                guard (200..<300).contains(httpResponse.statusCode) else {
                    logger.debug("SmartGlassesTransfer: HTTP \(httpResponse.statusCode) for \(downloadURL.absoluteString)")
                    continue
                }

                // Validate content type if available
                if let contentType = httpResponse.mimeType, !isValidContentType(contentType, for: file.kind) {
                    logger.debug("SmartGlassesTransfer: Invalid content type \(contentType) for \(file.kind)")
                    continue
                }

                // Save to temporary file
                let tempDir = FileManager.default.temporaryDirectory
                let fileExtension = URL(string: file.name)?.pathExtension ?? "tmp"
                let fileName = "\(UUID().uuidString).\(fileExtension)"
                let localURL = tempDir.appendingPathComponent(fileName)

                try data.write(to: localURL)

                logger.debug("SmartGlassesTransfer: successfully downloaded \(file.name) (\(data.count) bytes) to \(localURL.path)")

                return localURL

            } catch {
                lastError = error
                logger.debug("SmartGlassesTransfer: download failed for \(downloadURL.absoluteString): \(error)")
                continue
            }
        }

        // If we get here, all download attempts failed
        let errorMessage = lastError?.localizedDescription ?? "All download endpoints failed for \(file.name)"
        throw SmartGlassesTransferError.downloadFailed(errorMessage)
    }

    private func isValidContentType(_ contentType: String, for kind: DeviceMediaFile.Kind) -> Bool {
        let lowercased = contentType.lowercased()

        switch kind {
        case .image:
            return lowercased.hasPrefix("image/")
        case .video:
            return lowercased.hasPrefix("video/")
        case .audio:
            return lowercased.hasPrefix("audio/")
        case .unknown:
            return true // Accept any content type for unknown files
        }
    }

    /// Restores the headset to normal operation mode after transfer
    private func restoreNormalMode() async {
        guard service.isConnected else { return }

        logger.debug("SmartGlassesTransfer: restoring headset to normal audio mode")

        // Step 1: Exit transfer mode - return to normal operation
        await service.setDeviceMode(.photo) // Return to photo mode for normal operation

        // Step 2: Wait for mode transition
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Step 3: Re-enable audio functionality
        await service.setAISpeakMode(.start) // Re-enable audio output

        // Step 4: Ensure Bluetooth audio is enabled
        await service.toggleBluetooth(true)

        // Step 5: Wait for audio system to reconnect
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        // Step 6: Refresh status to update UI
        await service.refreshAdvancedStatus()

        logger.debug("SmartGlassesTransfer: headset audio should now be restored")
    }
}
