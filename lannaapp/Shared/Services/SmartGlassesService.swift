//
//  SmartGlassesService.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 8/31/25.
//

import Foundation
import AVFoundation
#if os(iOS)
import CoreBluetooth
#endif

// MARK: - Shared Types

struct SmartGlassesError: Identifiable, Equatable {
    let id = UUID()
    let message: String
}

enum SmartGlassesBluetoothState: Equatable {
    case unknown
    case resetting
    case unsupported
    case unauthorized
    case poweredOff
    case poweredOn

    #if canImport(QCSDK) && os(iOS)
    init(qcState: QCBluetoothState) {
        switch qcState {
        case .resetting: self = .resetting
        case .unsupported: self = .unsupported
        case .unauthorized: self = .unauthorized
        case .poweredOff: self = .poweredOff
        case .poweredOn: self = .poweredOn
        default: self = .unknown
        }
    }
    #endif
}

enum SmartGlassesConnectionState: Equatable {
    case idle
    case connecting
    case connected
    case disconnecting
    case disconnected
}

struct SmartGlassesMediaSummary: Equatable {
    var photos: Int = 0
    var videos: Int = 0
    var audio: Int = 0
    var type: Int = 0
}

struct SmartGlassesDevice: Identifiable, Equatable {
    let id: String
    let name: String
    let macAddress: String?
    let rssi: Int?
    fileprivate let underlying: AnyObject?

    #if canImport(QCSDK) && os(iOS)
    init?(qcPeripheral: QCBlePeripheral) {
        let peripheral = qcPeripheral.peripheral
        self.id = peripheral.identifier.uuidString
        self.name = peripheral.name ?? "Unknown Device"
        self.macAddress = qcPeripheral.mac
        if let rssiNumber = qcPeripheral.value(forKey: "RSSI") as? NSNumber {
            self.rssi = rssiNumber.intValue
        } else {
            self.rssi = nil
        }
        self.underlying = qcPeripheral
    }
    #endif

    #if os(iOS)
    init(peripheral: CBPeripheral, macAddress: String? = nil, rssi: Int? = nil) {
        self.id = peripheral.identifier.uuidString
        self.name = peripheral.name ?? "Unknown Device"
        self.macAddress = macAddress
        self.rssi = rssi
        self.underlying = peripheral
    }
    #else
    init(id: String, name: String, macAddress: String? = nil, rssi: Int? = nil) {
        self.id = id
        self.name = name
        self.macAddress = macAddress
        self.rssi = rssi
        self.underlying = nil
    }
    #endif

    static func == (lhs: SmartGlassesDevice, rhs: SmartGlassesDevice) -> Bool {
        lhs.id == rhs.id
    }
}

struct SmartGlassesConnectionDiagnostics: Equatable {
    var batteryLevel: Int
    var isCharging: Bool
    var macAddress: String?
}

struct SmartGlassesVolumeLevel: Equatable {
    var min: Int
    var max: Int
    var current: Int
}

enum SmartGlassesVolumeMode: Int, CaseIterable, Identifiable {
    case music = 0x01
    case call = 0x02
    case system = 0x03

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .music: return "Music"
        case .call: return "Call"
        case .system: return "System"
        }
    }
}

struct SmartGlassesVolumeInfo: Equatable {
    var mode: SmartGlassesVolumeMode
    var music: SmartGlassesVolumeLevel
    var call: SmartGlassesVolumeLevel
    var system: SmartGlassesVolumeLevel
}

struct SmartGlassesWiFiCredentials: Equatable {
    var ssid: String
    var password: String
    var lastUpdated: Date
}

enum SmartGlassesDeviceMode: Int, CaseIterable, Identifiable {
    case unknown = 0x00
    case photo = 0x01
    case video
    case videoStop
    case transfer
    case ota
    case aiPhoto
    case speechRecognition
    case audio
    case transferStop
    case factoryReset
    case speechRecognitionStop
    case audioStop
    case findDevice
    case restart
    case noPowerP2P
    case speakStart
    case speakStop
    case translateStart
    case translateStop

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .unknown: return "Unknown"
        case .photo: return "Photo"
        case .video: return "Video"
        case .videoStop: return "Video Stop"
        case .transfer: return "Data Transfer"
        case .ota: return "OTA Update"
        case .aiPhoto: return "AI Photo"
        case .speechRecognition: return "Speech Recognition"
        case .audio: return "Audio Recording"
        case .transferStop: return "Transfer Stop"
        case .factoryReset: return "Factory Reset"
        case .speechRecognitionStop: return "Speech Rec Stop"
        case .audioStop: return "Audio Stop"
        case .findDevice: return "Find Device"
        case .restart: return "Restart"
        case .noPowerP2P: return "P2P Restart"
        case .speakStart: return "Voice Play Start"
        case .speakStop: return "Voice Play Stop"
        case .translateStart: return "Translate Start"
        case .translateStop: return "Translate Stop"
        }
    }

    static var commonOptions: [SmartGlassesDeviceMode] {
        [.photo, .video, .speechRecognition, .audio, .translateStart, .findDevice]
    }
}

enum SmartGlassesAISpeakMode: Int, CaseIterable, Identifiable {
    case start = 0x01
    case hold
    case stop
    case thinkingStart
    case thinkingHold
    case thinkingStop
    case noNet = 0xF1

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .start: return "Start"
        case .hold: return "Hold"
        case .stop: return "Stop"
        case .thinkingStart: return "Thinking"
        case .thinkingHold: return "Thinking Hold"
        case .thinkingStop: return "Thinking Stop"
        case .noNet: return "No Network"
        }
    }
}

struct SmartGlassesAdvancedStatus: Equatable {
    var deviceMode: SmartGlassesDeviceMode = .unknown
    var aiSpeakMode: SmartGlassesAISpeakMode = .stop
    var wifiCredentials: SmartGlassesWiFiCredentials?
    var wifiIPAddress: String?
    var voiceWakeEnabled: Bool?
    var wearingDetectionEnabled: Bool?
    var bluetoothEnabled: Bool?
    var volumeInfo: SmartGlassesVolumeInfo?
}

extension SmartGlassesVolumeLevel {
    mutating func clampedAssign(_ value: Int) -> Int {
        let lower = min
        let upper = max
        let clamped = Swift.max(lower, Swift.min(upper, value))
        current = clamped
        return clamped
    }
}

extension SmartGlassesVolumeInfo {
    mutating func update(level: Int, for mode: SmartGlassesVolumeMode) -> Bool {
        switch mode {
        case .music:
            let previous = music.current
            _ = music.clampedAssign(level)
            return previous != music.current
        case .call:
            let previous = call.current
            _ = call.clampedAssign(level)
            return previous != call.current
        case .system:
            let previous = system.current
            _ = system.clampedAssign(level)
            return previous != system.current
        }
    }
}

#if canImport(QCSDK) && os(iOS)
extension SmartGlassesDeviceMode {
    init(qcMode: QCOperatorDeviceMode) {
        self = SmartGlassesDeviceMode(rawValue: qcMode.rawValue) ?? .unknown
    }

    var qcValue: QCOperatorDeviceMode {
        QCOperatorDeviceMode(rawValue: rawValue) ?? .unkown
    }
}

extension SmartGlassesAISpeakMode {
    init(qcMode: QGAISpeakMode) {
        self = SmartGlassesAISpeakMode(rawValue: qcMode.rawValue) ?? .stop
    }

    var qcValue: QGAISpeakMode {
        QGAISpeakMode(rawValue: rawValue) ?? .stop
    }
}

extension SmartGlassesVolumeMode {
    init(qcMode: QCVolumeMode) {
        self = SmartGlassesVolumeMode(rawValue: qcMode.rawValue) ?? .music
    }

    var qcValue: QCVolumeMode {
        QCVolumeMode(rawValue: rawValue) ?? .music
    }
}

extension SmartGlassesVolumeInfo {
    init?(model: QCVolumeInfoModel) {
        guard let mode = SmartGlassesVolumeMode(rawValue: model.mode.rawValue) else { return nil }
        self.mode = mode
        self.music = SmartGlassesVolumeLevel(min: model.musicMin, max: model.musicMax, current: model.musicCurrent)
        self.call = SmartGlassesVolumeLevel(min: model.callMin, max: model.callMax, current: model.callCurrent)
        self.system = SmartGlassesVolumeLevel(min: model.systemMin, max: model.systemMax, current: model.systemCurrent)
    }

    func toQCModel() -> QCVolumeInfoModel {
        let model = QCVolumeInfoModel()
        model.musicMin = music.min
        model.musicMax = music.max
        model.musicCurrent = music.current
        model.callMin = call.min
        model.callMax = call.max
        model.callCurrent = call.current
        model.systemMin = system.min
        model.systemMax = system.max
        model.systemCurrent = system.current
        model.mode = mode.qcValue
        return model
    }
}
#endif

#if os(iOS)
extension SmartGlassesDevice {
    var cbPeripheral: CBPeripheral? {
        if let wrapped = underlying as? QCBlePeripheral {
            return wrapped.peripheral
        }
        return underlying as? CBPeripheral
    }
}
#endif

#if os(iOS) && !(canImport(QCSDK))
extension SmartGlassesDevice {
    init(id: String, name: String, macAddress: String? = nil, rssi: Int? = nil) {
        self.id = id
        self.name = name
        self.macAddress = macAddress
        self.rssi = rssi
        self.underlying = nil
    }
}
#endif

extension SmartGlassesService {
    var selectedDevice: SmartGlassesDevice? {
        if let connectedDevice {
            return connectedDevice
        }
        return availableDevices.first
    }
}

// MARK: - Live Implementation (iOS + HeyCyan SDK)

#if canImport(QCSDK) && os(iOS)

@MainActor
final class SmartGlassesService: NSObject, ObservableObject {
    static let shared = SmartGlassesService()

    @Published private(set) var bluetoothState: SmartGlassesBluetoothState = .unknown
    @Published private(set) var connectionState: SmartGlassesConnectionState = .idle
    @Published private(set) var isScanning = false
    @Published private(set) var availableDevices: [SmartGlassesDevice] = []
    @Published private(set) var connectedDevice: SmartGlassesDevice?
    @Published private(set) var lastError: SmartGlassesError?
    @Published private(set) var batteryLevel: Int?
    @Published private(set) var isCharging = false
    @Published private(set) var mediaSummary = SmartGlassesMediaSummary()
    @Published private(set) var latestAIImage: Data?
    @Published private(set) var connectionDiagnostics: SmartGlassesConnectionDiagnostics?
    @Published private(set) var isRunningDiagnostics = false
    @Published private(set) var advancedStatus = SmartGlassesAdvancedStatus()
    @Published var photoWasTaken = false

    var isConnected: Bool { connectionState == .connected }

    private var centralManager: QCCentralManager?
    private var sdkManager: QCSDKManager?
    private var scanTimeoutTask: Task<Void, Never>?

    override init() {
        super.init()
        centralManager = QCCentralManager.shared()
        sdkManager = QCSDKManager.shareInstance()
        centralManager?.delegate = self
        sdkManager?.delegate = self
        updateBluetoothState(centralManager?.bleState ?? .unkown)
        updateConnectionState(centralManager?.deviceState ?? .unkown)
    }

    func startScanning(timeout: TimeInterval = 30) {
        guard bluetoothState == .poweredOn else {
            lastError = SmartGlassesError(message: "Turn on Bluetooth to search for HeyCyan smart glasses.")
            return
        }

        lastError = nil
        availableDevices.removeAll()
        isScanning = true
        centralManager?.scan(withTimeout: Int(timeout))

        scanTimeoutTask?.cancel()
        scanTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            await MainActor.run {
                self?.isScanning = false
            }
        }
    }

    func stopScanning() {
        scanTimeoutTask?.cancel()
        centralManager?.stopScan()
        isScanning = false
    }

    func connect(to device: SmartGlassesDevice) {
        guard let peripheral = device.cbPeripheral else {
            lastError = SmartGlassesError(message: "Unable to access the selected device. Please rescan.")
            return
        }

        lastError = nil
        connectionState = .connecting
        centralManager?.connect(peripheral, deviceType: QCDeviceType.glasses)
    }

    func disconnect() {
        connectionState = .disconnecting
        centralManager?.remove()
    }

    func requestPermissions() async -> Bool {
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)

        if cameraStatus == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }

        if microphoneStatus == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        }

        let finalCameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let finalMicrophoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let granted = finalCameraStatus == .authorized && finalMicrophoneStatus == .authorized
        if !granted {
            lastError = SmartGlassesError(message: "Camera and microphone access are required to complete setup.")
        }
        return granted
    }

    func performConnectionDiagnostics() async -> SmartGlassesConnectionDiagnostics? {
        guard isConnected else {
            lastError = SmartGlassesError(message: "Connect to your smart glasses before running diagnostics.")
            return nil
        }

        connectionDiagnostics = nil
        isRunningDiagnostics = true
        defer { isRunningDiagnostics = false }

        do {
            let (battery, charging) = try await fetchBatteryStatus()
            let mac = try await fetchMacAddress()
            let result = SmartGlassesConnectionDiagnostics(batteryLevel: battery, isCharging: charging, macAddress: mac)
            connectionDiagnostics = result
            batteryLevel = battery
            isCharging = charging
            return result
        } catch {
            lastError = SmartGlassesError(message: error.localizedDescription)
            return nil
        }
    }

    func refreshAdvancedStatus() async {
        guard isConnected else { return }
        await refreshVoiceWakeupStatus()
        await refreshWearingDetectionStatus()
        await refreshBluetoothStatus()
        await refreshVolumeStatus()
        await refreshWifiIPAddress()
    }

    func setDeviceMode(_ mode: SmartGlassesDeviceMode) async {
        guard isConnected else { return }
        do {
            try await withCheckedThrowingContinuation { continuation in
                QCSDKCmdCreator.setDeviceMode(mode.qcValue) {
                    continuation.resume(returning: ())
                } fail: { code in
                    continuation.resume(throwing: DiagnosticsError.operationFailed("Unable to set device mode (code: \(code))."))
                }
            }
            modifyAdvancedStatus { $0.deviceMode = mode }
        } catch {
            lastError = SmartGlassesError(message: error.localizedDescription)
        }
    }

    @discardableResult
    func openWiFiCredentials(for mode: SmartGlassesDeviceMode) async -> SmartGlassesWiFiCredentials? {
        guard isConnected else { return nil }
        do {
            let credentials = try await withCheckedThrowingContinuation { continuation in
                QCSDKCmdCreator.openWifi(with: mode.qcValue) { ssid, password in
                    continuation.resume(returning: SmartGlassesWiFiCredentials(ssid: ssid, password: password, lastUpdated: Date()))
                } fail: { code in
                    continuation.resume(throwing: DiagnosticsError.operationFailed("Unable to enable Wi-Fi (code: \(code))."))
                }
            }
            modifyAdvancedStatus { status in
                status.wifiCredentials = credentials
            }
            return credentials
        } catch {
            lastError = SmartGlassesError(message: error.localizedDescription)
            return nil
        }
    }

    func setAISpeakMode(_ mode: SmartGlassesAISpeakMode) async {
        guard isConnected else { return }
        do {
            try await withCheckedThrowingContinuation { continuation in
                QCSDKCmdCreator.setAISpeekModel(mode.qcValue) { success, error in
                    if success {
                        continuation.resume(returning: ())
                    } else {
                        continuation.resume(throwing: error ?? DiagnosticsError.operationFailed("Unable to set AI speaking mode."))
                    }
                }
            }
            modifyAdvancedStatus { $0.aiSpeakMode = mode }
        } catch {
            lastError = SmartGlassesError(message: error.localizedDescription)
        }
    }

    func toggleVoiceWakeup(_ isOn: Bool) async {
        guard isConnected else { return }
        do {
            try await withCheckedThrowingContinuation { continuation in
                QCSDKCmdCreator.setVoiceWakeup(isOn) { success, error, _ in
                    if success {
                        continuation.resume(returning: ())
                    } else {
                        continuation.resume(throwing: error ?? DiagnosticsError.operationFailed("Unable to update voice wake."))
                    }
                }
            }
            modifyAdvancedStatus { $0.voiceWakeEnabled = isOn }
        } catch {
            lastError = SmartGlassesError(message: error.localizedDescription)
        }
    }

    func toggleWearingDetection(_ isOn: Bool) async {
        guard isConnected else { return }
        do {
            try await withCheckedThrowingContinuation { continuation in
                QCSDKCmdCreator.setWearingDetection(isOn) { success, error, _ in
                    if success {
                        continuation.resume(returning: ())
                    } else {
                        continuation.resume(throwing: error ?? DiagnosticsError.operationFailed("Unable to update wearing detection."))
                    }
                }
            }
            modifyAdvancedStatus { $0.wearingDetectionEnabled = isOn }
        } catch {
            lastError = SmartGlassesError(message: error.localizedDescription)
        }
    }

    func toggleBluetooth(_ isOn: Bool) async {
        do {
            try await withCheckedThrowingContinuation { continuation in
                QCSDKCmdCreator.setBTStatus(isOn) { success, error in
                    if success {
                        continuation.resume(returning: ())
                    } else {
                        continuation.resume(throwing: error ?? DiagnosticsError.operationFailed("Unable to update Bluetooth state."))
                    }
                }
            }
            modifyAdvancedStatus { $0.bluetoothEnabled = isOn }
        } catch {
            lastError = SmartGlassesError(message: error.localizedDescription)
        }
    }

    func setVolume(level: Int, for mode: SmartGlassesVolumeMode) async {
        guard isConnected else { return }
        if advancedStatus.volumeInfo == nil {
            await refreshVolumeStatus()
        }
        guard var info = advancedStatus.volumeInfo else { return }
        let changed = info.update(level: level, for: mode)
        info.mode = mode
        guard changed else {
            modifyAdvancedStatus { $0.volumeInfo = info }
            return
        }

        do {
            try await sendVolumeInfo(info)
            modifyAdvancedStatus { $0.volumeInfo = info }
        } catch {
            lastError = SmartGlassesError(message: error.localizedDescription)
        }
    }

    func getDeviceMediaCount() async -> (photos: Int, videos: Int, audio: Int, totalSize: Int)? {
        guard isConnected else {
            print("❌ getDeviceMediaCount: Not connected")
            return nil
        }
        print("📊 Fetching device media count...")
        do {
            let result = try await withCheckedThrowingContinuation { continuation in
                QCSDKCmdCreator.getDeviceMedia { photoCount, videoCount, audioCount, totalSize in
                    print("✅ Got media count: \(photoCount) photos, \(videoCount) videos, \(audioCount) audio")
                    continuation.resume(returning: (photos: photoCount, videos: videoCount, audio: audioCount, totalSize: totalSize))
                } fail: {
                    print("❌ getDeviceMedia failed")
                    continuation.resume(throwing: DiagnosticsError.operationFailed("Unable to fetch media count from device."))
                }
            }
            return result
        } catch {
            print("❌ getDeviceMediaCount error: \(error.localizedDescription)")
            lastError = SmartGlassesError(message: error.localizedDescription)
            return nil
        }
    }

    func downloadThumbnail(at index: Int) async -> UIImage? {
        guard isConnected else {
            print("❌ downloadThumbnail: Not connected")
            return nil
        }
        print("📥 Downloading thumbnail at index \(index)...")
        do {
            let (imageData, width, height) = try await withCheckedThrowingContinuation { continuation in
                QCSDKCmdCreator.getThumbnail(index) { imageData, width, height in
                    print("✅ Got thumbnail data: \(imageData.count) bytes, size: \(width)x\(height)")
                    continuation.resume(returning: (imageData, width, height))
                } fail: {
                    print("❌ getThumbnail(\(index)) failed")
                    continuation.resume(throwing: DiagnosticsError.operationFailed("Unable to download thumbnail at index \(index)."))
                }
            }

            guard let image = UIImage(data: imageData) else {
                print("❌ Failed to convert \(imageData.count) bytes to UIImage")
                lastError = SmartGlassesError(message: "Unable to convert image data to UIImage.")
                return nil
            }

            print("✅ Successfully created UIImage from thumbnail \(index)")
            return image
        } catch {
            print("❌ downloadThumbnail(\(index)) error: \(error.localizedDescription)")
            lastError = SmartGlassesError(message: error.localizedDescription)
            return nil
        }
    }

    private func refreshVoiceWakeupStatus() async {
        do {
            let isOn = try await fetchVoiceWakeupStatus()
            modifyAdvancedStatus { $0.voiceWakeEnabled = isOn }
        } catch {
            lastError = SmartGlassesError(message: error.localizedDescription)
        }
    }

    private func refreshWearingDetectionStatus() async {
        do {
            let isOn = try await fetchWearingDetectionStatus()
            modifyAdvancedStatus { $0.wearingDetectionEnabled = isOn }
        } catch {
            lastError = SmartGlassesError(message: error.localizedDescription)
        }
    }

    private func refreshBluetoothStatus() async {
        do {
            let isOn = try await fetchBluetoothStatus()
            modifyAdvancedStatus { $0.bluetoothEnabled = isOn }
        } catch {
            lastError = SmartGlassesError(message: error.localizedDescription)
        }
    }

    private func refreshVolumeStatus() async {
        do {
            let info = try await fetchVolumeInfo()
            modifyAdvancedStatus { $0.volumeInfo = info }
        } catch {
            lastError = SmartGlassesError(message: error.localizedDescription)
        }
    }

    private func refreshWifiIPAddress() async {
        do {
            let ip = try await fetchWifiIPAddress()
            modifyAdvancedStatus { $0.wifiIPAddress = ip }
        } catch {
            lastError = SmartGlassesError(message: error.localizedDescription)
        }
    }

    private func fetchVoiceWakeupStatus() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            QCSDKCmdCreator.getVoiceWakeup { success, error, result in
                if let error, !success {
                    continuation.resume(throwing: error)
                    return
                }
                if let value = self.boolValue(from: result) {
                    continuation.resume(returning: value)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }

    private func fetchWearingDetectionStatus() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            QCSDKCmdCreator.getWearingDetection { success, error, result in
                if let error, !success {
                    continuation.resume(throwing: error)
                    return
                }
                if let value = self.boolValue(from: result) {
                    continuation.resume(returning: value)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }

    private func fetchBluetoothStatus() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            QCSDKCmdCreator.getBTStatus { isOn, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: isOn)
                }
            }
        }
    }

    private func fetchVolumeInfo() async throws -> SmartGlassesVolumeInfo {
        try await withCheckedThrowingContinuation { continuation in
            QCSDKCmdCreator.getVolumeWithFinished { success, error, result in
                if let error, !success {
                    continuation.resume(throwing: error)
                    return
                }
                guard let model = result as? QCVolumeInfoModel, let info = SmartGlassesVolumeInfo(model: model) else {
                    continuation.resume(throwing: DiagnosticsError.operationFailed("Unable to parse volume information."))
                    return
                }
                continuation.resume(returning: info)
            }
        }
    }

    private func fetchWifiIPAddress() async throws -> String? {
        let rawIP = try await withCheckedThrowingContinuation { continuation in
            QCSDKCmdCreator.getDeviceWifiIPSuccess { ip in
                continuation.resume(returning: ip)
            } failed: {
                continuation.resume(throwing: DiagnosticsError.operationFailed("Unable to query Wi-Fi IP address."))
            }
        }

        // Fix incorrect IP address returned by QCSDK
        if rawIP == "3.192.168.31" {
            return "192.168.31.1"
        }

        return rawIP
    }

    private func sendVolumeInfo(_ info: SmartGlassesVolumeInfo) async throws {
        try await withCheckedThrowingContinuation { continuation in
            QCSDKCmdCreator.setVolume(info.toQCModel()) { success, error, _ in
                if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: error ?? DiagnosticsError.operationFailed("Unable to update volume levels."))
                }
            }
        }
    }

    func modifyAdvancedStatus(_ mutation: (inout SmartGlassesAdvancedStatus) -> Void) {
        var status = advancedStatus
        mutation(&status)
        advancedStatus = status
    }

    private func boolValue(from result: Any?) -> Bool? {
        switch result {
        case let number as NSNumber:
            return number.boolValue
        case let string as NSString:
            return string.boolValue
        case let dict as [String: Any]:
            let keys = ["isOpen", "enabled", "status", "on", "value"]
            for key in keys {
                if let number = dict[key] as? NSNumber {
                    return number.boolValue
                }
                if let string = dict[key] as? NSString {
                    return string.boolValue
                }
            }
            return nil
        default:
            return nil
        }
    }

    private func updateConnectionState(_ qcState: QCState) {
        switch qcState {
        case .connecting:
            connectionState = .connecting
        case .connected:
            connectionState = .connected
            if let peripheral = centralManager?.connectedPeripheral {
                connectedDevice = availableDevices.first(where: { $0.id == peripheral.identifier.uuidString })
                    ?? SmartGlassesDevice(peripheral: peripheral)
            }
            stopScanning()
        case .disconnecting:
            connectionState = .disconnecting
            connectedDevice = nil
            connectionDiagnostics = nil
        case .disconnected:
            connectionState = .disconnected
            connectedDevice = nil
            connectionDiagnostics = nil
        case .unbind, .unkown:
            connectionState = .idle
            connectedDevice = nil
            connectionDiagnostics = nil
        @unknown default:
            connectionState = .idle
            connectionDiagnostics = nil
        }
    }

    private func updateBluetoothState(_ qcState: QCBluetoothState) {
        bluetoothState = SmartGlassesBluetoothState(qcState: qcState)
        if bluetoothState != .poweredOn {
            isScanning = false
        }
    }

    private enum DiagnosticsError: LocalizedError {
        case operationFailed(String)

        var errorDescription: String? {
            switch self {
            case .operationFailed(let message):
                return message
            }
        }
    }

    private func fetchBatteryStatus() async throws -> (Int, Bool) {
        try await withCheckedThrowingContinuation { continuation in
            QCSDKCmdCreator.getDeviceBattery { battery, charging in
                continuation.resume(returning: (battery, charging))
            } fail: {
                continuation.resume(throwing: DiagnosticsError.operationFailed("Unable to read battery status from the glasses."))
            }
        }
    }

    private func fetchMacAddress() async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            QCSDKCmdCreator.getDeviceMacAddressSuccess { mac in
                continuation.resume(returning: mac)
            } fail: {
                continuation.resume(throwing: DiagnosticsError.operationFailed("Unable to read the glasses' MAC address."))
            }
        }
    }

    func forgetCurrentDevice() {
        centralManager?.forgetLastConnectedPeripheral()
        centralManager?.remove()

        connectedDevice = nil
        connectionState = .idle
        availableDevices.removeAll()
        isScanning = false
        lastError = nil
        batteryLevel = nil
        isCharging = false
        mediaSummary = SmartGlassesMediaSummary()
        latestAIImage = nil
        connectionDiagnostics = nil
        isRunningDiagnostics = false
        advancedStatus = SmartGlassesAdvancedStatus()

        stopScanning()
    }
}

// MARK: - QCCentralManagerDelegate

extension SmartGlassesService: QCCentralManagerDelegate {
    func didState(_ state: QCState) {
        Task { @MainActor in
            self.updateConnectionState(state)
        }
    }

    func didBluetoothState(_ state: QCBluetoothState) {
        Task { @MainActor in
            self.updateBluetoothState(state)
        }
    }

    func didScanPeripherals(_ peripheralArr: [QCBlePeripheral]) {
        Task { @MainActor in
            let devices = peripheralArr.compactMap(SmartGlassesDevice.init(qcPeripheral:))
            self.availableDevices = devices
        }
    }

    func scanPeripheralFinish() {
        Task { @MainActor in
            self.isScanning = false
        }
    }

    func didFailConnected(_ peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            self.connectionState = .disconnected
            self.lastError = SmartGlassesError(message: error?.localizedDescription ?? "Unable to connect to HeyCyan glasses.")
        }
    }
}

// MARK: - QCSDKManagerDelegate

extension SmartGlassesService: QCSDKManagerDelegate {
    func didUpdateBatteryLevel(_ battery: Int, charging: Bool) {
        Task { @MainActor in
            self.batteryLevel = battery
            self.isCharging = charging
        }
    }

    func didUpdateMedia(withPhotoCount photo: Int, videoCount: Int, audioCount: Int, type: Int) {
        Task { @MainActor in
            let previousPhotoCount = self.mediaSummary.photos
            self.mediaSummary = SmartGlassesMediaSummary(photos: photo, videos: videoCount, audio: audioCount, type: type)

            // If photo count increased, a new photo was taken
            if photo > previousPhotoCount {
                self.photoWasTaken = true

                // Post notification for AppDelegate to handle (works in background)
                NotificationCenter.default.post(name: NSNotification.Name("SmartGlassesPhotoTaken"), object: nil)
            }
        }
    }

    func didReceiveAIChatImageData(_ imageData: Data) {
        Task { @MainActor in
            self.latestAIImage = imageData
        }
    }
}

#endif

// MARK: - Fallback Implementation (Non-iOS / SDK unavailable)

#if !(canImport(QCSDK) && os(iOS))

@MainActor
final class SmartGlassesService: NSObject, ObservableObject {
    static let shared = SmartGlassesService()

    @Published private(set) var bluetoothState: SmartGlassesBluetoothState = .unsupported
    @Published private(set) var connectionState: SmartGlassesConnectionState = .idle
    @Published private(set) var isScanning = false
    @Published private(set) var availableDevices: [SmartGlassesDevice] = []
    @Published private(set) var connectedDevice: SmartGlassesDevice?
    @Published private(set) var lastError: SmartGlassesError?
    @Published private(set) var batteryLevel: Int?
    @Published private(set) var isCharging = false
    @Published private(set) var mediaSummary = SmartGlassesMediaSummary()
    @Published private(set) var latestAIImage: Data?
    @Published private(set) var connectionDiagnostics: SmartGlassesConnectionDiagnostics?
    @Published private(set) var isRunningDiagnostics = false
    @Published private(set) var advancedStatus = SmartGlassesAdvancedStatus()

    var isConnected: Bool { false }

    func startScanning(timeout: TimeInterval = 30) {
        isScanning = true
        lastError = nil
        
        // Simulate finding demo devices
        let simulateScan = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.availableDevices = [
                SmartGlassesDevice(id: "demo-1", name: "HeyCyan Glasses Pro", macAddress: "AA:BB:CC:DD:EE:01", rssi: -45),
                SmartGlassesDevice(id: "demo-2", name: "HeyCyan Glasses Lite", macAddress: "AA:BB:CC:DD:EE:02", rssi: -60)
            ]
            self.isScanning = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: simulateScan)
    }

    func stopScanning() {
        isScanning = false
    }

    func connect(to device: SmartGlassesDevice) {
        connectionState = .connecting
        lastError = nil
        
        // Simulate connection process
        let simulateConnect = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.connectedDevice = device
            self.connectionState = .connected
            self.batteryLevel = 85
            self.isCharging = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: simulateConnect)
    }

    func disconnect() {
        connectionState = .idle
        connectedDevice = nil
        connectionDiagnostics = nil
    }

    func requestPermissions() async -> Bool {
        false
    }

    func performConnectionDiagnostics() async -> SmartGlassesConnectionDiagnostics? {
        guard let device = connectedDevice else {
            lastError = SmartGlassesError(message: "Connect to a demo device before running diagnostics.")
            return nil
        }

        connectionDiagnostics = nil
        isRunningDiagnostics = true
        defer { isRunningDiagnostics = false }

        let result = SmartGlassesConnectionDiagnostics(
            batteryLevel: batteryLevel ?? 85,
            isCharging: isCharging,
            macAddress: device.macAddress ?? "AA:BB:CC:DD:EE:FF"
        )
        connectionDiagnostics = result
        return result
    }

    func refreshAdvancedStatus() async {
        if advancedStatus.volumeInfo == nil {
            advancedStatus.volumeInfo = SmartGlassesVolumeInfo(
                mode: .music,
                music: SmartGlassesVolumeLevel(min: 0, max: 10, current: 5),
                call: SmartGlassesVolumeLevel(min: 0, max: 10, current: 5),
                system: SmartGlassesVolumeLevel(min: 0, max: 10, current: 5)
            )
        }
        if advancedStatus.voiceWakeEnabled == nil {
            advancedStatus.voiceWakeEnabled = true
        }
        if advancedStatus.wearingDetectionEnabled == nil {
            advancedStatus.wearingDetectionEnabled = true
        }
        if advancedStatus.bluetoothEnabled == nil {
            advancedStatus.bluetoothEnabled = true
        }
        if advancedStatus.wifiIPAddress == nil {
            advancedStatus.wifiIPAddress = "192.168.0.10"
        }
    }

    func setDeviceMode(_ mode: SmartGlassesDeviceMode) async {
        advancedStatus.deviceMode = mode
    }

    @discardableResult
    func openWiFiCredentials(for mode: SmartGlassesDeviceMode) async -> SmartGlassesWiFiCredentials? {
        let credentials = SmartGlassesWiFiCredentials(ssid: "Demo-Net", password: "password123", lastUpdated: Date())
        advancedStatus.wifiCredentials = credentials
        return credentials
    }

    func setAISpeakMode(_ mode: SmartGlassesAISpeakMode) async {
        advancedStatus.aiSpeakMode = mode
    }

    func toggleVoiceWakeup(_ isOn: Bool) async {
        advancedStatus.voiceWakeEnabled = isOn
    }

    func toggleWearingDetection(_ isOn: Bool) async {
        advancedStatus.wearingDetectionEnabled = isOn
    }

    func toggleBluetooth(_ isOn: Bool) async {
        advancedStatus.bluetoothEnabled = isOn
    }

    func setVolume(level: Int, for mode: SmartGlassesVolumeMode) async {
        if advancedStatus.volumeInfo == nil {
            await refreshAdvancedStatus()
        }
        guard var info = advancedStatus.volumeInfo else { return }
        _ = info.update(level: level, for: mode)
        info.mode = mode
        advancedStatus.volumeInfo = info
    }

    func forgetCurrentDevice() {
        connectionState = .idle
        connectedDevice = nil
        availableDevices.removeAll()
        isScanning = false
        lastError = nil
        batteryLevel = nil
        isCharging = false
        mediaSummary = SmartGlassesMediaSummary()
        latestAIImage = nil
        connectionDiagnostics = nil
        isRunningDiagnostics = false
        advancedStatus = SmartGlassesAdvancedStatus()
    }
}

#endif
