//
//  PermissionsView.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 8/31/25.
//

import SwiftUI
import AVFoundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct PermissionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var microphonePermission: PermissionStatus = .undetermined
    @State private var showingPermissionAlert = false
    @State private var permissionAlertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)
                    
                    Text("Permissions")
                        .font(.title)
                        .foregroundColor(.primary)
                    
                    Text("Manage app permissions for the best experience")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)
                
                // Permissions List
                VStack(spacing: 16) {
                    // Microphone Permission
                    PermissionRow(
                        icon: "mic.fill",
                        title: "Microphone",
                        description: "Record voice messages and use voice-to-text",
                        status: microphonePermission,
                        action: requestMicrophonePermission
                    )
                    
                    // Future permissions can be added here
                    // Camera Permission
                    PermissionRow(
                        icon: "camera.fill",
                        title: "Camera",
                        description: "Take photos and videos for your projects",
                        status: .granted, // Placeholder - implement camera permission check
                        action: {}
                    )
                    
                    // Photos Permission
                    PermissionRow(
                        icon: "photo.fill",
                        title: "Photos",
                        description: "Access your photo library for attachments",
                        status: .granted, // Placeholder - implement photos permission check
                        action: {}
                    )
                }
                .padding(.horizontal, 16)
                
                Spacer()
                
                // Info Text
                VStack(spacing: 8) {
                    Text("You can change these permissions anytime in Settings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Open Settings") {
                        openAppSettings()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding(.bottom, 24)
            }
            .background(Color.gray.opacity(0.1))
            .navigationTitle("Permissions")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("Done") { dismiss() }
                }
                #endif
            }
            .onAppear {
                checkMicrophonePermission()
            }
            .alert("Permission Required", isPresented: $showingPermissionAlert) {
                Button("Settings") {
                    openAppSettings()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(permissionAlertMessage)
            }
        }
    }
    
    private func checkMicrophonePermission() {
        #if os(iOS)
        let perm = AVAudioSession.sharedInstance().recordPermission
        switch perm {
        case .granted: microphonePermission = .granted
        case .denied: microphonePermission = .denied
        case .undetermined: microphonePermission = .undetermined
        @unknown default: microphonePermission = .undetermined
        }
        #elseif os(macOS)
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized: microphonePermission = .granted
        case .denied: microphonePermission = .denied
        case .restricted: microphonePermission = .denied
        case .notDetermined: microphonePermission = .undetermined
        @unknown default: microphonePermission = .undetermined
        }
        #endif
    }
    
    private func requestMicrophonePermission() {
        #if os(iOS)
        if microphonePermission == .undetermined {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.microphonePermission = granted ? .granted : .denied
                }
            }
        } else if microphonePermission == .denied {
            permissionAlertMessage = "Microphone access is required for voice messages. Please enable it in Settings."
            showingPermissionAlert = true
        }
        #elseif os(macOS)
        if microphonePermission == .undetermined {
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    self.microphonePermission = granted ? .granted : .denied
                }
            }
        } else if microphonePermission == .denied {
            permissionAlertMessage = "Microphone access is required for voice messages. Please enable it in System Settings > Privacy & Security > Microphone."
            showingPermissionAlert = true
        }
        #endif
    }
    
    private func openAppSettings() {
        #if os(iOS)
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
        #elseif os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let status: PermissionStatus
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Status and Action
            HStack(spacing: 8) {
                Text(status.displayName)
                    .font(.caption)
                    .foregroundColor(status.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(status.color.opacity(0.1))
                    .cornerRadius(8)
                
                if status == .undetermined || status == .denied {
                    Button("Enable") {
                        action()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var iconColor: Color {
        switch status {
        case .granted:
            return .green
        case .denied:
            return .red
        case .undetermined:
            return .orange
        }
    }
}

enum PermissionStatus {
    case granted
    case denied
    case undetermined
    
    var displayName: String {
        switch self {
        case .granted:
            return "Allowed"
        case .denied:
            return "Denied"
        case .undetermined:
            return "Not Set"
        }
    }
    
    var color: Color {
        switch self {
        case .granted:
            return .green
        case .denied:
            return .red
        case .undetermined:
            return .orange
        }
    }
}

#Preview {
    PermissionsView()
}
