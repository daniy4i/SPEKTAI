//
//  HeadsetDetectionService.swift
//  lannaapp
//
//  Created by Assistant on 01/23/2025.
//

import Foundation
import AVFoundation
#if os(iOS)
import CoreBluetooth
#endif

enum HeadsetType: String {
    case none = "Built-in Microphone"
    case wired = "Wired Headset"
    case bluetooth = "Bluetooth Headset"
    case airpods = "AirPods"
    case smartGlasses = "Smart Glasses"

    var icon: String {
        switch self {
        case .none:
            return "mic"
        case .wired:
            return "headphones"
        case .bluetooth:
            return "airpodspro"
        case .airpods:
            return "airpods"
        case .smartGlasses:
            return "eyeglasses"
        }
    }
}

@MainActor
class HeadsetDetectionService: ObservableObject {
    static let shared = HeadsetDetectionService()

    @Published var currentHeadsetType: HeadsetType = .none
    @Published var headsetName: String = "Built-in Microphone"
    @Published var isSmartGlassesConnected: Bool = false
    @Published var smartGlassesDevice: SmartGlassesDevice?

    #if os(iOS)
    private var audioRouteChangeObserver: NSObjectProtocol?
    #endif

    private init() {
        setupAudioSessionObserver()
        Task {
            await MainActor.run {
                checkCurrentAudioRoute()
            }
        }
        observeSmartGlasses()
    }

    deinit {
        #if os(iOS)
        if let observer = audioRouteChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        #endif
    }

    private func setupAudioSessionObserver() {
        #if os(iOS)
        audioRouteChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkCurrentAudioRoute()
        }
        #endif
    }

    func checkCurrentAudioRoute() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        let currentRoute = session.currentRoute

        print("🔍 HeadsetDetection: Checking audio route")
        print("📱 Current inputs: \(currentRoute.inputs.map { "\($0.portName) (\($0.portType.rawValue))" })")
        print("📱 Current outputs: \(currentRoute.outputs.map { "\($0.portName) (\($0.portType.rawValue))" })")

        var foundHeadset = false
        var detectedType: HeadsetType = .none
        var detectedName = "Built-in Microphone"

        // First priority: Check preferred input (what we actually want to use)
        if let preferredInput = session.preferredInput {
            print("🎯 Using preferred input: \(preferredInput.portName) (\(preferredInput.portType.rawValue))")
            updateHeadsetType(portType: preferredInput.portType, portName: preferredInput.portName)
            return
        }

        // Second priority: Check current inputs (microphone sources)
        for input in currentRoute.inputs {
            let portType = input.portType
            let portName = input.portName

            print("🎤 Input device: \(portName) (\(portType.rawValue))")

            if portType != .builtInMic {
                foundHeadset = true
                detectedType = getHeadsetType(portType: portType, portName: portName)
                detectedName = portName
                break
            }
        }

        // Third priority: Check outputs to detect Bluetooth devices that might have mics
        if !foundHeadset {
            for output in currentRoute.outputs {
                let portType = output.portType
                let portName = output.portName

                print("🔊 Output device: \(portName) (\(portType.rawValue))")

                // Check if it's a Bluetooth device that likely has a microphone
                if portType == .bluetoothA2DP || portType == .bluetoothHFP || portType == .bluetoothLE {
                    foundHeadset = true
                    detectedType = getHeadsetType(portType: portType, portName: portName)
                    detectedName = portName
                    break
                } else if portType == .headphones || portType == .headsetMic {
                    foundHeadset = true
                    detectedType = .wired
                    detectedName = portName
                    break
                }
            }
        }

        // Update the detected headset type
        currentHeadsetType = detectedType
        headsetName = detectedName

        print("✅ Detected headset: \(detectedType.rawValue) - \(detectedName)")

        #else
        // macOS audio route detection - enhanced for better device detection
        print("🖥️ macOS audio route check")
        currentHeadsetType = .none
        headsetName = "Built-in Microphone"
        #endif
    }

    private func getHeadsetType(portType: AVAudioSession.Port, portName: String) -> HeadsetType {
        #if os(iOS)
        let lowerName = portName.lowercased()

        switch portType {
        case .builtInMic:
            return .none

        case .headsetMic:
            return .wired

        case .bluetoothHFP, .bluetoothA2DP, .bluetoothLE:
            if lowerName.contains("airpod") {
                return .airpods
            } else if isSmartGlassesConnected || lowerName.contains("glass") || lowerName.contains("ray-ban") {
                return .smartGlasses
            } else {
                return .bluetooth
            }

        default:
            // Check for smart glasses by name patterns
            if isSmartGlassesConnected || lowerName.contains("glass") || lowerName.contains("ray-ban") {
                return .smartGlasses
            } else if lowerName.contains("airpod") {
                return .airpods
            } else if portName != "Built-in Microphone" {
                return .bluetooth
            } else {
                return .none
            }
        }
        #else
        return .none
        #endif
    }

    private func updateHeadsetType(portType: AVAudioSession.Port, portName: String) {
        #if os(iOS)
        switch portType {
        case .builtInMic:
            currentHeadsetType = .none
            headsetName = "Built-in Microphone"

        case .headsetMic:
            currentHeadsetType = .wired
            headsetName = portName

        case .bluetoothHFP, .bluetoothA2DP:
            if portName.lowercased().contains("airpod") {
                currentHeadsetType = .airpods
            } else if isSmartGlassesConnected {
                currentHeadsetType = .smartGlasses
            } else {
                currentHeadsetType = .bluetooth
            }
            headsetName = portName

        default:
            // Check if it might be smart glasses based on the name
            if isSmartGlassesConnected {
                currentHeadsetType = .smartGlasses
                headsetName = smartGlassesDevice?.name ?? portName
            } else {
                currentHeadsetType = .none
                headsetName = portName
            }
        }
        #endif
    }

    private func observeSmartGlasses() {
        // Observe SmartGlassesService connection state
        #if canImport(QCSDK) && os(iOS)
        Task {
            // Check if SmartGlassesService is available and connected
            if let service = try? SmartGlassesService.shared {
                // Monitor connection state changes
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("SmartGlassesConnectionChanged"),
                    object: nil,
                    queue: .main
                ) { [weak self] notification in
                    if let device = notification.userInfo?["device"] as? SmartGlassesDevice {
                        self?.smartGlassesDevice = device
                        self?.isSmartGlassesConnected = true
                        self?.checkCurrentAudioRoute()
                    } else {
                        self?.smartGlassesDevice = nil
                        self?.isSmartGlassesConnected = false
                        self?.checkCurrentAudioRoute()
                    }
                }
            }
        }
        #endif
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