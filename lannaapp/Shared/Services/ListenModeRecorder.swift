//
//  ListenModeRecorder.swift
//  lannaapp
//
//  Created by Codex on 02/15/2026.
//

import Foundation
import AVFoundation

@MainActor
final class ListenModeRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var errorMessage: String?
    
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private(set) var currentFileURL: URL?
    
    func startRecording() async {
        print("🎙️ ListenModeRecorder: startRecording called")
        guard await ensurePermission() else {
            print("❌ ListenModeRecorder: Permission denied")
            return
        }

        stopInternal(resetElapsed: true)
        print("🔄 ListenModeRecorder: Reset internal state")
        
        do {
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()

            // Enhanced audio session configuration with microphone support
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [
                .defaultToSpeaker,
                .allowBluetooth,
                .allowBluetoothA2DP,
                .duckOthers
            ])

            // Try to use the preferred microphone if one is selected
            let micService = MicrophoneSelectionService.shared
            if let selectedDevice = micService.selectedDevice,
               selectedDevice.type != .none,
               let portType = selectedDevice.portType {

                print("🎤 Attempting to use selected microphone: \(selectedDevice.name)")

                let availableInputs = session.availableInputs ?? []
                if let targetInput = availableInputs.first(where: {
                    $0.portType == portType && $0.portName == selectedDevice.name
                }) {
                    try session.setPreferredInput(targetInput)
                    print("✅ Set preferred input to: \(targetInput.portName)")
                } else {
                    print("⚠️ Selected microphone not available, using automatic selection")
                }
            }

            try session.setActive(true, options: .notifyOthersOnDeactivation)

            // Set input gain to maximum for better recording volume
            if session.isInputGainSettable {
                try session.setInputGain(1.0) // Maximum gain (0.0 to 1.0)
                print("✅ Input gain set to maximum (1.0)")
            }

            print("✅ Audio session configured for recording")
            #endif
            
            let filename = "listen-mode-\(UUID().uuidString).m4a"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                AVEncoderBitRateKey: 128_000, // Higher bit rate for better quality/volume
                AVLinearPCMBitDepthKey: 16    // 16-bit depth for better dynamic range
            ]
            
            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            newRecorder.isMeteringEnabled = true
            newRecorder.prepareToRecord()
            newRecorder.record()
            
            recorder = newRecorder
            currentFileURL = url
            elapsedTime = 0
            startTimer()
            isRecording = true
            errorMessage = nil
            print("✅ ListenModeRecorder: Recording started at \(url.lastPathComponent)")
            print("📊 State: isRecording=\(isRecording), elapsedTime=\(elapsedTime)")
        } catch {
            print("❌ ListenModeRecorder: Failed to start - \(error)")
            errorMessage = error.localizedDescription
            stopInternal(resetElapsed: true)
        }
    }
    
    func stopRecording() -> (url: URL, duration: TimeInterval)? {
        print("🛑 ListenModeRecorder: stopRecording called")
        print("📊 Current state: isRecording=\(isRecording), currentFileURL=\(currentFileURL?.lastPathComponent ?? "nil"), elapsedTime=\(elapsedTime)")

        guard isRecording, let url = currentFileURL else {
            print("❌ ListenModeRecorder: Cannot stop - not recording or no file URL")
            return nil
        }

        let finalDuration = elapsedTime
        stopInternal(resetElapsed: false)

        // Verify file exists
        if FileManager.default.fileExists(atPath: url.path) {
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            print("✅ ListenModeRecorder: Recording stopped - File: \(url.lastPathComponent), Duration: \(finalDuration)s, Size: \(fileSize) bytes")
        } else {
            print("⚠️ ListenModeRecorder: Warning - File doesn't exist at \(url.path)")
        }

        currentFileURL = nil
        return (url, finalDuration)
    }
    
    func pauseRecording() {
        print("⏸️ ListenModeRecorder: pauseRecording called")
        guard isRecording && !isPaused else {
            print("❌ ListenModeRecorder: Cannot pause - not recording or already paused")
            return
        }

        recorder?.pause()
        timer?.invalidate()
        timer = nil
        isPaused = true
        print("✅ ListenModeRecorder: Recording paused")
    }

    func resumeRecording() {
        print("▶️ ListenModeRecorder: resumeRecording called")
        guard isRecording && isPaused else {
            print("❌ ListenModeRecorder: Cannot resume - not recording or not paused")
            return
        }

        recorder?.record()
        startTimer()
        isPaused = false
        print("✅ ListenModeRecorder: Recording resumed")
    }

    func cancelRecording() {
        stopInternal(resetElapsed: true)
        if let url = currentFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        currentFileURL = nil
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.elapsedTime += 1
            }
        }
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func stopInternal(resetElapsed: Bool) {
        print("🔄 ListenModeRecorder: stopInternal called (resetElapsed=\(resetElapsed))")
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        recorder = nil
        isRecording = false
        isPaused = false
        if resetElapsed {
            elapsedTime = 0
        }
        print("📊 After stopInternal: isRecording=\(isRecording), isPaused=\(isPaused), elapsedTime=\(elapsedTime)")
    }
    
    private func ensurePermission() async -> Bool {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        if session.recordPermission == .undetermined {
            await withCheckedContinuation { continuation in
                session.requestRecordPermission { _ in
                    continuation.resume()
                }
            }
        }
        let granted = session.recordPermission == .granted
        if !granted {
            errorMessage = "Microphone permission denied."
        }
        return granted
        #else
        return true
        #endif
    }
}
