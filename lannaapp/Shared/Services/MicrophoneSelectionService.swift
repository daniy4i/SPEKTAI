//
//  MicrophoneSelectionService.swift
//  lannaapp
//
//  Enhanced microphone selection and management service
//

import Foundation
import AVFoundation
#if os(iOS)
import CoreBluetooth
#endif

struct MicrophoneDevice: Identifiable, Hashable {
    let id: String
    let name: String
    let type: HeadsetType
    let portType: AVAudioSession.Port?
    let isAvailable: Bool
    let isPreferred: Bool

    var displayName: String {
        return name
    }

    var icon: String {
        return type.icon
    }
}

@MainActor
class MicrophoneSelectionService: ObservableObject {
    static let shared = MicrophoneSelectionService()

    @Published var availableDevices: [MicrophoneDevice] = []
    @Published var selectedDevice: MicrophoneDevice?
    @Published var currentInputDevice: MicrophoneDevice?
    @Published var isScanning = false

    private var audioRouteChangeObserver: NSObjectProtocol?
    private let userDefaults = UserDefaults.standard
    private let preferredDeviceKey = "PreferredMicrophoneDevice"

    private init() {
        setupAudioSessionObserver()
        refreshAvailableDevices()
        loadPreferredDevice()
    }

    deinit {
        if let observer = audioRouteChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setupAudioSessionObserver() {
        #if os(iOS)
        audioRouteChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("🎙️ Audio route changed")
            self?.handleAudioRouteChange(notification: notification)
        }

        // Also listen for device connection changes
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔄 Media services were reset")
            self?.refreshAvailableDevices()
        }
        #endif
    }

    private func handleAudioRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonRaw = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw) else {
            return
        }

        print("🎙️ Route change reason: \(reason)")

        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable, .routeConfigurationChange:
            refreshAvailableDevices()
            updateCurrentInputDevice()
        case .categoryChange, .override:
            updateCurrentInputDevice()
        default:
            break
        }
    }

    func refreshAvailableDevices() {
        print("🔍 Refreshing available microphone devices")

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        var devices: [MicrophoneDevice] = []

        // Always add built-in microphone
        let builtInDevice = MicrophoneDevice(
            id: "builtin",
            name: "Built-in Microphone",
            type: .none,
            portType: .builtInMic,
            isAvailable: true,
            isPreferred: false
        )
        devices.append(builtInDevice)

        // Get available inputs
        do {
            let availableInputs = session.availableInputs ?? []
            print("📱 Available inputs: \(availableInputs.map { "\($0.portName) (\($0.portType.rawValue))" })")

            for input in availableInputs {
                if input.portType != .builtInMic {
                    let device = createMicrophoneDevice(from: input)
                    devices.append(device)
                }
            }
        }

        // Check current route for additional devices
        let currentRoute = session.currentRoute
        for input in currentRoute.inputs {
            let deviceExists = devices.contains { $0.portType == input.portType && $0.name == input.portName }
            if !deviceExists && input.portType != .builtInMic {
                let device = createMicrophoneDevice(from: input)
                devices.append(device)
            }
        }

        // Also check outputs for headphones with mics
        for output in currentRoute.outputs {
            if output.portType == .bluetoothA2DP || output.portType == .bluetoothHFP || output.portType == .bluetoothLE {
                let deviceExists = devices.contains { $0.name == output.portName }
                if !deviceExists {
                    let headsetType: HeadsetType
                    if output.portName.lowercased().contains("airpod") {
                        headsetType = .airpods
                    } else if HeadsetDetectionService.shared.isSmartGlassesConnected {
                        headsetType = .smartGlasses
                    } else {
                        headsetType = .bluetooth
                    }

                    let device = MicrophoneDevice(
                        id: "bluetooth-\(output.portName.replacingOccurrences(of: " ", with: "-").lowercased())",
                        name: output.portName,
                        type: headsetType,
                        portType: output.portType,
                        isAvailable: true,
                        isPreferred: false
                    )
                    devices.append(device)
                }
            }
        }

        #else
        // macOS support - simplified for now
        var devices: [MicrophoneDevice] = []
        let builtInDevice = MicrophoneDevice(
            id: "builtin",
            name: "Built-in Microphone",
            type: .none,
            portType: nil,
            isAvailable: true,
            isPreferred: false
        )
        devices.append(builtInDevice)
        #endif

        self.availableDevices = devices
        updateCurrentInputDevice()

        print("✅ Found \(devices.count) microphone devices:")
        for device in devices {
            print("   - \(device.name) (\(device.type.rawValue))")
        }
    }

    private func createMicrophoneDevice(from input: AVAudioSessionPortDescription) -> MicrophoneDevice {
        let headsetType: HeadsetType

        switch input.portType {
        case .headsetMic:
            headsetType = .wired
        case .bluetoothHFP, .bluetoothA2DP, .bluetoothLE:
            if input.portName.lowercased().contains("airpod") {
                headsetType = .airpods
            } else if HeadsetDetectionService.shared.isSmartGlassesConnected {
                headsetType = .smartGlasses
            } else {
                headsetType = .bluetooth
            }
        default:
            if HeadsetDetectionService.shared.isSmartGlassesConnected &&
               input.portName.lowercased().contains("glass") {
                headsetType = .smartGlasses
            } else {
                headsetType = .none
            }
        }

        return MicrophoneDevice(
            id: "input-\(input.uid)",
            name: input.portName,
            type: headsetType,
            portType: input.portType,
            isAvailable: true,
            isPreferred: false
        )
    }

    private func updateCurrentInputDevice() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        let currentRoute = session.currentRoute

        if let currentInput = currentRoute.inputs.first {
            currentInputDevice = availableDevices.first { device in
                device.portType == currentInput.portType && device.name == currentInput.portName
            } ?? availableDevices.first { $0.type == .none } // Fallback to built-in
        } else {
            currentInputDevice = availableDevices.first { $0.type == .none }
        }
        #else
        currentInputDevice = availableDevices.first { $0.type == .none }
        #endif

        print("🎤 Current input device: \(currentInputDevice?.name ?? "Unknown")")
    }

    func selectDevice(_ device: MicrophoneDevice) async -> Bool {
        print("🎯 Selecting microphone device: \(device.name)")

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()

        do {
            // Configure audio session for recording
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])

            // If it's not the built-in mic, try to set preferred input
            if device.type != .none, let portType = device.portType {
                let availableInputs = session.availableInputs ?? []

                if let targetInput = availableInputs.first(where: {
                    $0.portType == portType && $0.portName == device.name
                }) {
                    try session.setPreferredInput(targetInput)
                    print("✅ Set preferred input to: \(targetInput.portName)")
                } else {
                    print("⚠️ Target input not found, using automatic selection")
                }
            } else {
                // For built-in mic, set preferred input to nil
                try session.setPreferredInput(nil)
                print("✅ Set to use built-in microphone")
            }

            try session.setActive(true, options: .notifyOthersOnDeactivation)

            // Update our state
            selectedDevice = device
            savePreferredDevice(device)
            updateCurrentInputDevice()

            // Notify other services
            HeadsetDetectionService.shared.checkCurrentAudioRoute()

            return true

        } catch {
            print("❌ Failed to select microphone device: \(error)")
            return false
        }
        #else
        // macOS - simplified
        selectedDevice = device
        currentInputDevice = device
        savePreferredDevice(device)
        return true
        #endif
    }

    private func savePreferredDevice(_ device: MicrophoneDevice) {
        userDefaults.set(device.id, forKey: preferredDeviceKey)
        print("💾 Saved preferred device: \(device.name)")
    }

    private func loadPreferredDevice() {
        guard let deviceId = userDefaults.string(forKey: preferredDeviceKey) else {
            return
        }

        if let device = availableDevices.first(where: { $0.id == deviceId }) {
            selectedDevice = device
            print("📱 Loaded preferred device: \(device.name)")
        }
    }

    func autoSelectBestDevice() async {
        print("🤖 Auto-selecting best available microphone")

        // Priority order: Smart Glasses > AirPods > Wired Headset > Bluetooth > Built-in
        let priorityOrder: [HeadsetType] = [.smartGlasses, .airpods, .wired, .bluetooth, .none]

        for type in priorityOrder {
            if let device = availableDevices.first(where: { $0.type == type && $0.isAvailable }) {
                let success = await selectDevice(device)
                if success {
                    print("✅ Auto-selected: \(device.name)")
                    return
                }
            }
        }

        print("⚠️ Could not auto-select any device")
    }

    func requestMicrophonePermission() async -> Bool {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        if session.recordPermission == .undetermined {
            return await withCheckedContinuation { continuation in
                session.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
        return session.recordPermission == .granted
        #else
        return true
        #endif
    }
}