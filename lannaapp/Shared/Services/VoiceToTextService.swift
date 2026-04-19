//
//  VoiceToTextService.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 8/31/25.
//

import Foundation
import AVFoundation
import Speech
#if canImport(UIKit)
import UIKit
#endif

@MainActor
class VoiceToTextService: ObservableObject {
    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var transcribedText = ""
    @Published var errorMessage: String?
    
    private var audioEngine = AVAudioEngine()
    private var speechRecognizer = SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        #if os(iOS)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
        #else
        // macOS doesn't use AVAudioSession, audio permissions are handled differently
        print("Audio session setup not needed on macOS")
        #endif
    }
    
    func startRecording() {
        // Check permissions
        guard checkPermissions() else { return }
        
        // Stop any existing recording
        stopRecording()
        
        // Setup recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Unable to create recognition request"
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Setup audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            isTranscribing = true
            errorMessage = nil
            print("🎤 VoiceToText: Audio engine started, beginning transcription")
        } catch {
            errorMessage = "Failed to start audio engine: \(error.localizedDescription)"
            return
        }

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self?.transcribedText = result.bestTranscription.formattedString
                    print("🎤 VoiceToText: Updated transcript - \(result.bestTranscription.formattedString.prefix(50))...")
                }

                if let error = error {
                    print("❌ VoiceToText: Recognition error - \(error.localizedDescription)")
                    self?.errorMessage = "Recognition error: \(error.localizedDescription)"
                    self?.stopRecording()
                }
            }
        }
    }
    
    func stopRecording() {
        print("🛑 VoiceToText: Stopping recording and transcription")
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        isRecording = false
        isTranscribing = false
        print("✅ VoiceToText: Stopped - final transcript: '\(transcribedText)'")
    }
    
    func clearTranscription() {
        transcribedText = ""
        errorMessage = nil
    }
    
    private func checkPermissions() -> Bool {
        #if os(iOS)
        // Check microphone permission
        let microphoneStatus = AVAudioSession.sharedInstance().recordPermission
        guard microphoneStatus == .granted else {
            errorMessage = "Microphone permission is required for voice recording"
            return false
        }
        #else
        // On macOS, microphone permission is handled by the system
        // We'll assume it's granted if the app is running
        #endif
        
        // Check speech recognition permission (works on both platforms)
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        guard speechStatus == .authorized else {
            errorMessage = "Speech recognition permission is required"
            return false
        }
        
        return true
    }
    
    func requestPermissions() async {
        #if os(iOS)
        // Request microphone permission
        let microphoneStatus = AVAudioSession.sharedInstance().recordPermission
        if microphoneStatus == .undetermined {
            await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    print("Microphone permission granted: \(granted)")
                    continuation.resume()
                }
            }
        }
        #else
        // On macOS, microphone permission is handled by the system
        print("Microphone permission handled by macOS system")
        #endif
        
        // Request speech recognition permission
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        if speechStatus == .notDetermined {
            await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    print("Speech recognition permission status: \(status.rawValue)")
                    continuation.resume()
                }
            }
        }
        
        // Update UI on main thread
        await MainActor.run {
            // Force UI update by checking permissions again
            let _ = hasPermissions
        }
    }
    
    var hasPermissions: Bool {
        #if os(iOS)
        let microphoneStatus = AVAudioSession.sharedInstance().recordPermission
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        return microphoneStatus == .granted && speechStatus == .authorized
        #else
        // On macOS, microphone permission is handled by the system
        // We only need to check speech recognition permission
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        return speechStatus == .authorized
        #endif
    }
}
