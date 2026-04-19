//
//  MicrophoneSelectionView.swift
//  lannaapp
//
//  Comprehensive microphone selection UI
//

import SwiftUI

struct MicrophoneSelectionView: View {
    @StateObject private var micService = MicrophoneSelectionService.shared
    @StateObject private var headsetService = HeadsetDetectionService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isRefreshing = false
    @State private var showingPermissionAlert = false

    var body: some View {
        NavigationView {
            List {
                currentDeviceSection
                availableDevicesSection
                actionsSection
            }
            .navigationTitle("Microphone Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refreshDevices) {
                        HStack {
                            if isRefreshing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                    }
                    .disabled(isRefreshing)
                }
            }
            .alert("Microphone Permission Required", isPresented: $showingPermissionAlert) {
                Button("Settings") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please grant microphone access in Settings to use voice features.")
            }
        }
        .onAppear {
            Task {
                await checkPermissionAndRefresh()
            }
        }
    }

    private var currentDeviceSection: some View {
        Section {
            HStack(spacing: DS.spacingM) {
                Image(systemName: micService.currentInputDevice?.icon ?? "mic")
                    .font(.system(size: 20))
                    .foregroundColor(DS.primary)
                    .frame(width: 32, height: 32)
                    .background(DS.primary.opacity(0.1))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: DS.spacingXS) {
                    Text("Current Microphone")
                        .font(Typography.bodyMedium)
                        .foregroundColor(DS.textSecondary)

                    Text(micService.currentInputDevice?.displayName ?? "Unknown")
                        .font(Typography.titleMedium)
                        .foregroundColor(DS.textPrimary)
                }

                Spacer()

                // Status indicator
                Circle()
                    .fill(micService.currentInputDevice != nil ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
            }
            .padding(.vertical, DS.spacingXS)
        } header: {
            Text("Current Device")
        }
    }

    private var availableDevicesSection: some View {
        Section {
            ForEach(micService.availableDevices, id: \.id) { device in
                MicrophoneDeviceRow(
                    device: device,
                    isSelected: micService.selectedDevice?.id == device.id,
                    isCurrent: micService.currentInputDevice?.id == device.id
                ) {
                    selectDevice(device)
                }
            }
        } header: {
            Text("Available Devices")
        } footer: {
            if micService.availableDevices.isEmpty {
                Text("No microphone devices detected. Try connecting a headset or Bluetooth device.")
                    .foregroundColor(DS.textSecondary)
            } else {
                Text("Tap a device to select it as your preferred microphone.")
                    .foregroundColor(DS.textSecondary)
            }
        }
    }

    private var actionsSection: some View {
        Section {
            Button(action: {
                Task {
                    await micService.autoSelectBestDevice()
                }
            }) {
                HStack {
                    Image(systemName: "wand.and.stars")
                        .foregroundColor(DS.primary)
                    Text("Auto-Select Best Device")
                        .foregroundColor(DS.primary)
                }
            }

            Button(action: {
                Task {
                    await checkPermissionAndRefresh()
                }
            }) {
                HStack {
                    Image(systemName: "checkmark.shield")
                        .foregroundColor(DS.primary)
                    Text("Check Permissions")
                        .foregroundColor(DS.primary)
                }
            }
        } header: {
            Text("Quick Actions")
        }
    }

    private func selectDevice(_ device: MicrophoneDevice) {
        Task {
            let success = await micService.selectDevice(device)
            if !success {
                // Could show an error message here
                print("Failed to select device: \(device.name)")
            }
        }
    }

    private func refreshDevices() {
        isRefreshing = true
        micService.refreshAvailableDevices()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isRefreshing = false
        }
    }

    private func checkPermissionAndRefresh() async {
        let hasPermission = await micService.requestMicrophonePermission()

        await MainActor.run {
            if hasPermission {
                micService.refreshAvailableDevices()
            } else {
                showingPermissionAlert = true
            }
        }
    }
}

struct MicrophoneDeviceRow: View {
    let device: MicrophoneDevice
    let isSelected: Bool
    let isCurrent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.spacingM) {
                // Device icon
                Image(systemName: device.icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
                    .frame(width: 28, height: 28)
                    .background(iconBackground)
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: DS.spacingXS) {
                    Text(device.displayName)
                        .font(Typography.bodyMedium)
                        .foregroundColor(DS.textPrimary)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: DS.spacingXS) {
                        Text(device.type.rawValue)
                            .font(Typography.caption)
                            .foregroundColor(DS.textSecondary)

                        if isCurrent {
                            Text("• Active")
                                .font(Typography.caption)
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        }

                        if isSelected && !isCurrent {
                            Text("• Preferred")
                                .font(Typography.caption)
                                .foregroundColor(DS.primary)
                                .fontWeight(.medium)
                        }
                    }
                }

                Spacer()

                // Status indicators
                HStack(spacing: DS.spacingXS) {
                    if isCurrent {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    } else if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DS.primary)
                            .font(.system(size: 16))
                    }

                    if !device.isAvailable {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 14))
                    }
                }
            }
            .padding(.vertical, DS.spacingXS)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(device.isAvailable ? 1.0 : 0.6)
    }

    private var iconColor: Color {
        if isCurrent {
            return .green
        } else if isSelected {
            return DS.primary
        } else {
            return DS.textSecondary
        }
    }

    private var iconBackground: Color {
        if isCurrent {
            return .green.opacity(0.15)
        } else if isSelected {
            return DS.primary.opacity(0.15)
        } else {
            return DS.surface
        }
    }
}

// MARK: - Preview
#if DEBUG
struct MicrophoneSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        MicrophoneSelectionView()
    }
}
#endif