//
//  SmartGlassesSetupView.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 8/31/25.
//  Updated by Codex on 02/15/2026.
//

import SwiftUI
import AVFoundation
#if os(iOS)
import UIKit
#endif

struct SmartGlassesSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isSetupComplete: Bool
    @State private var currentStep = 0
    @State private var cameraPermissionGranted = false
    @State private var microphonePermissionGranted = false
    @State private var showingPermissionAlert = false
    @State private var selectedDeviceID: String?
    @StateObject private var service = SmartGlassesService.shared
    @StateObject private var transferService = SmartGlassesTransferService.shared
    @State private var forceSetupMode = false
    @State private var isRefreshingAdvanced = false
    @State private var showingWiFiCredentials = false
    @State private var wifiCredentials: SmartGlassesWiFiCredentials?
    @State private var wifiErrorMessage: String?
    @State private var showingWiFiError = false
    @State private var hasLoadedAdvanced = false
    @State private var volumeDraft: [SmartGlassesVolumeMode: Double] = [:]
    @State private var transferErrorMessage: String?
    @State private var showingTransferError = false
    @State private var showingPhotoDownload = false
    @State private var showingEndpointDiscovery = false

    private let setupSteps = [
        "Welcome to Smart Glasses Setup",
        "Grant Permissions",
        "Scan for Devices",
        "Connect Your Glasses",
        "Test Connection",
        "Setup Complete"
    ]

    private var shouldShowDashboardOnly: Bool {
        service.isConnected && isSetupComplete && !forceSetupMode
    }

    private var permissionsGranted: Bool {
        cameraPermissionGranted && microphonePermissionGranted
    }

    var body: some View {
        Group {
            if shouldShowDashboardOnly {
                dashboardOnlyView
            } else {
                setupFlowView
            }
        }
    }

    private var setupFlowView: some View {
        NavigationView {
            ZStack {
                backgroundGradient

                VStack(spacing: 15) {
                    header

                    VStack(spacing: 20) {
                        Image(systemName: iconForStep(currentStep))
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)

                        VStack(spacing: 10) {
                            Text(setupSteps[currentStep])
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)

                            Text(descriptionForStep(currentStep))
                                .font(.body)
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 10)
                        }

                        stepSpecificContent
                    }

                    Spacer()

                    footer
                }
                .padding(.vertical, 40)
                .padding(.horizontal, 16)
            }
        }
        .onAppear {
            refreshPermissionState()
            if service.isConnected && !forceSetupMode {
                currentStep = max(currentStep, 4)
                runConnectionTest()
            }
        }
        .onChange(of: service.connectionState) { newValue in
            if newValue == .connected && currentStep == 3 {
                withAnimation {
                    currentStep = 4
                }
                runConnectionTest()
            }
        }
        .alert("Permissions Required", isPresented: $showingPermissionAlert) {
#if os(iOS)
            Button("Open Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
#endif
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Lanna needs camera and microphone access to work with your smart glasses. Please enable these permissions in Settings.")
        }
        .alert("Wi-Fi Hotspot Enabled", isPresented: $showingWiFiCredentials, presenting: wifiCredentials) { _ in
            Button("OK", role: .cancel) { }
        } message: { credentials in
            Text("SSID: \(credentials.ssid)\nPassword: \(credentials.password)")
        }
        .alert("Wi-Fi Issue", isPresented: $showingWiFiError, presenting: wifiErrorMessage) { _ in
            Button("OK", role: .cancel) { }
        } message: { message in
            Text(message)
        }
        .alert("Transfer Issue", isPresented: $showingTransferError, presenting: transferErrorMessage) { _ in
            Button("OK", role: .cancel) { }
        } message: { message in
            Text(message)
        }
        .sheet(isPresented: $showingPhotoDownload) {
            SmartGlassesPhotoDownloadView()
        }
        .sheet(isPresented: $showingEndpointDiscovery) {
            SmartGlassesEndpointDiscoveryView()
        }
    }

    private var dashboardOnlyView: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    if service.isConnected {
                        connectedDashboard
                    } else {
                        Text("Your headset is not currently connected.")
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }

                    if service.isRunningDiagnostics {
                        ProgressView("Gathering device stats…")
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .foregroundColor(.white)
                    } else if service.isConnected {
                        Button("Refresh Stats") {
                            runConnectionTest()
                        }
                        .foregroundColor(Color(red: 0.1, green: 0.3, blue: 0.6))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(25)
                    }

                    if service.isConnected {
                        Button("Open Setup Flow") {
                            forceSetupMode = true
                            isSetupComplete = false
                            hasLoadedAdvanced = false
                            volumeDraft.removeAll()
                            currentStep = 0
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.25))
                        .cornerRadius(25)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
        }
        .navigationTitle("Headset Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
        .onAppear {
            runConnectionTest()
        }
        .sheet(isPresented: $showingPhotoDownload) {
            SmartGlassesPhotoDownloadView()
        }
        .sheet(isPresented: $showingEndpointDiscovery) {
            SmartGlassesEndpointDiscoveryView()
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


    private var header: some View {
        VStack(spacing: 20) {
            Text("Smart Glasses Setup")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            HStack(spacing: 8) {
                ForEach(0..<setupSteps.count, id: \.self) { index in
                    Rectangle()
                        .fill(index <= currentStep ? Color.white : Color.white.opacity(0.3))
                        .frame(height: 4)
                        .animation(.easeInOut, value: currentStep)
                }
            }
            .padding(.horizontal, 20)

            Text("Step \(currentStep + 1) of \(setupSteps.count)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if currentStep > 0 {
                Button("Back") {
                    withAnimation {
                        currentStep = max(0, currentStep - 1)
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.2))
                .cornerRadius(25)
            }

       

            if currentStep < 3 {
                Button("Skip Setup") {
                    isSetupComplete = true
                }
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(25)
            }

            Button(action: nextStep) {
                HStack {
                    if currentStep == setupSteps.count - 1 {
                        Text("Finish Setup")
                    } else {
                        Text("Next")
                    }

                    if isWorking {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                }
            }
            .foregroundColor(Color(red: 0.1, green: 0.3, blue: 0.6))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(25)
            .disabled(!canProceed)
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var stepSpecificContent: some View {
        VStack(spacing: 20) {
            if let error = service.lastError {
                Text(error.message)
                    .font(.footnote)
                    .foregroundColor(.yellow)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            switch currentStep {
            case 0:
                Text("Let's get your smart glasses connected to Lanna")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))

            case 1:
                permissionStep

            case 2:
                scanningStep

            case 3:
                connectionStep

            case 4:
                testStep

            case 5:
                completionStep

            default:
                EmptyView()
            }
        }
    }

    private var permissionStep: some View {
        VStack(spacing: 20) {
            SimplePermissionRow(
                icon: "camera.fill",
                title: "Camera Access",
                description: "For gesture recognition",
                isGranted: cameraPermissionGranted
            )

            SimplePermissionRow(
                icon: "mic.fill",
                title: "Microphone Access",
                description: "For voice commands",
                isGranted: microphonePermissionGranted
            )

            Button("Request Permissions") {
                requestPermissions()
            }
            .foregroundColor(Color(red: 0.1, green: 0.3, blue: 0.6))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(25)
        }
    }

    private var scanningStep: some View {
        VStack(spacing: 16) {
            // Scanning status at the top
            if service.isScanning {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)

                    Text("Scanning for smart glasses...")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(.bottom, 20)
            } else {
                Button(action: startScanning) {
                    Text(service.availableDevices.isEmpty ? "Start Scanning" : "Scan Again")
                }
                .foregroundColor(Color(red: 0.1, green: 0.3, blue: 0.6))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.white)
                .cornerRadius(25)
                .padding(.bottom, 20)
            }

            // Device list takes up most of the space
            if !service.availableDevices.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Devices Nearby")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(service.availableDevices.count) found")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.25))
                            .cornerRadius(16)
                    }

                    ScrollView {
                        LazyVStack(spacing: 20) {
                            ForEach(service.availableDevices) { device in
                                Button {
                                    selectedDeviceID = device.id
                                    currentStep = 3
                                } label: {
                                    HStack(spacing: 20) {
                                        Image(systemName: "eyeglasses")
                                            .font(.system(size: 32))
                                            .foregroundColor(.white)
                                            .frame(width: 40)
                                        
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(device.name)
                                                .font(.title2)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                                .multilineTextAlignment(.leading)
                                            if let rssi = device.rssi {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "wifi")
                                                        .font(.subheadline)
                                                        .foregroundColor(.white.opacity(0.8))
                                                    Text("Signal: \(rssi) dBm")
                                                        .font(.headline)
                                                        .foregroundColor(.white.opacity(0.8))
                                                }
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.title2)
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 24)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.white.opacity(0.4), lineWidth: 2)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 20)
            } else if !service.isScanning {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("No devices found")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("Make sure your glasses are in pairing mode and within range")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 40)
            }
        }
    }

    private var connectionStep: some View {
        VStack(spacing: 16) {
            if let device = selectedDevice {
                Text("Selected: \(device.name)")
                    .font(.headline)
                    .foregroundColor(.white)
            } else if service.availableDevices.isEmpty {
                Text("No devices selected yet.")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
            }

            if service.connectionState == .connecting {
                ProgressView("Connecting to glasses...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .foregroundColor(.white)
            } else if service.isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
                Text("Glasses Connected!")
                    .font(.headline)
                    .foregroundColor(.white)

                Button(role: .destructive) {
                    service.forgetCurrentDevice()
                    selectedDeviceID = nil
                    isSetupComplete = false
                    forceSetupMode = true
                    withAnimation {
                        currentStep = 2
                    }
                } label: {
                    Text("Forget This Device")
                        .font(.subheadline)
                }
                .padding(.top, 8)
            } else {
                if let device = selectedDevice {
                    Button("Connect to \(device.name)") {
                        connect(device: device)
                    }
                    .foregroundColor(Color(red: 0.1, green: 0.3, blue: 0.6))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(25)
                } else {
                    Text("Select your HeyCyan glasses from the scan results to connect.")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private var testStep: some View {
        VStack(spacing: 24) {
            if service.isConnected {
                connectedDashboard
            }

            if service.isRunningDiagnostics {
                ProgressView("Gathering device stats…")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .foregroundColor(.white)
            } else if service.isConnected {
                Button("Refresh Stats") {
                    runConnectionTest()
                }
                .foregroundColor(Color(red: 0.1, green: 0.3, blue: 0.6))
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.white)
                .cornerRadius(25)
            } else {
                Text("Reconnect your glasses to continue with setup.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var connectedDashboard: some View {
        VStack(spacing: 20) {
            Image(systemName: "eyeglasses")
                .font(.system(size: 48))
                .foregroundColor(.white)

            Text(selectedDevice?.name ?? "Connected Headset")
                .font(.title3)
                .foregroundColor(.white)

            VStack(spacing: 14) {
                statusRow(
                    title: "Battery",
                    value: formattedBattery,
                    systemImage: batteryIconName()
                )

                statusRow(
                    title: "Charging",
                    value: service.isCharging ? "Yes" : "No",
                    systemImage: service.isCharging ? "bolt.fill" : "bolt.slash"
                )

                if let mac = service.connectionDiagnostics?.macAddress ?? service.connectedDevice?.macAddress, !mac.isEmpty {
                    statusRow(
                        title: "MAC Address",
                        value: mac,
                        systemImage: "network"
                    )
                }

                if let rssi = selectedDevice?.rssi {
                    statusRow(
                        title: "Signal",
                        value: "\(rssi) dBm",
                        systemImage: "antenna.radiowaves.left.and.right"
                    )
                }
            }
            .padding()
            .background(Color.white.opacity(0.12))
            .cornerRadius(18)

            advancedControls

            Button(role: .destructive) {
                service.forgetCurrentDevice()
                selectedDeviceID = nil
                isSetupComplete = false
                forceSetupMode = true
                hasLoadedAdvanced = false
                volumeDraft.removeAll()
                withAnimation {
                    currentStep = 2
                }
            } label: {
                Text("Forget This Device")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.15))
                    .foregroundColor(.white)
                    .cornerRadius(25)
            }
        }
        .task {
            guard service.isConnected else { return }
            if !hasLoadedAdvanced {
                await MainActor.run { isRefreshingAdvanced = true }
                await service.refreshAdvancedStatus()
                await MainActor.run {
                    isRefreshingAdvanced = false
                    hasLoadedAdvanced = true
                    volumeDraft.removeAll()
                }
            }
        }
    }


    private var advancedControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Controls & Options")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if isRefreshingAdvanced {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }

            Divider()
                .background(Color.white.opacity(0.2))

            deviceModeSection
            aiSpeakSection
            featureToggleSection
            wifiSection
            volumeSection
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .cornerRadius(18)
    }

    private var deviceModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Device Mode", systemImage: "gearshape")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))

            Menu {
                ForEach(SmartGlassesDeviceMode.allCases, id: \.self) { mode in
                    Button {
                        performAdvancedChange {
                            await service.setDeviceMode(mode)
                            await service.refreshAdvancedStatus()
                        }
                    } label: {
                        HStack {
                            Text(mode.displayName)
                            if mode == service.advancedStatus.deviceMode {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(service.advancedStatus.deviceMode.displayName)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.12))
                .cornerRadius(12)
            }
            .disabled(isRefreshingAdvanced)
        }
    }

    private var aiSpeakSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("AI Speaking Mode", systemImage: "bubble.left.and.bubble.right")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))

            Menu {
                ForEach(SmartGlassesAISpeakMode.allCases, id: \.self) { mode in
                    Button {
                        performAdvancedChange {
                            await service.setAISpeakMode(mode)
                            await service.refreshAdvancedStatus()
                        }
                    } label: {
                        HStack {
                            Text(mode.displayName)
                            if mode == service.advancedStatus.aiSpeakMode {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(service.advancedStatus.aiSpeakMode.displayName)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.12))
                .cornerRadius(12)
            }
            .disabled(isRefreshingAdvanced)
        }
    }

    private var featureToggleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quick Toggles", systemImage: "slider.horizontal.3")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))

            toggleRow(
                title: "Voice Wake",
                systemImage: "waveform",
                binding: voiceWakeBinding,
                isAvailable: service.advancedStatus.voiceWakeEnabled != nil
            )

            toggleRow(
                title: "Wearing Detection",
                systemImage: "eye",
                binding: wearingDetectionBinding,
                isAvailable: service.advancedStatus.wearingDetectionEnabled != nil
            )

            toggleRow(
                title: "Bluetooth",
                systemImage: "dot.radiowaves.left.and.right",
                binding: bluetoothBinding,
                isAvailable: service.advancedStatus.bluetoothEnabled != nil
            )
        }
    }

    private var wifiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Wi-Fi & Network", systemImage: "wifi")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))

            if let ip = service.advancedStatus.wifiIPAddress, !ip.isEmpty {
                infoRow(title: "IP Address", value: ip, systemImage: "network")
            }

            if let credentials = service.advancedStatus.wifiCredentials {
                infoRow(title: "SSID", value: credentials.ssid, systemImage: "wifi")
                infoRow(title: "Password", value: credentials.password, systemImage: "key.fill")
            }

            Button(action: openWiFiHotspot) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("Generate Wi-Fi Hotspot")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.15))
                .cornerRadius(12)
            }
            .foregroundColor(.white)
            .disabled(isRefreshingAdvanced)

            transferStatusView

            Button(action: {
                print("🔵 Sync Files button tapped")
                print("🔵 canStartTransfer: \(transferService.canStartTransfer)")
                print("🔵 isRefreshingAdvanced: \(isRefreshingAdvanced)")
                print("🔵 service.isConnected: \(service.isConnected)")
                print("🔵 transferService.phase: \(transferService.phase)")
                startTransferPreparation()
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("Sync Files to Device")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.25))
                .cornerRadius(12)
            }
            .foregroundColor(.white)
            .disabled(!transferService.canStartTransfer || isRefreshingAdvanced)

            Button(action: { showingPhotoDownload = true }) {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("View Photo Previews (BT)")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.15))
                .cornerRadius(12)
            }
            .foregroundColor(.white)
            .disabled(!service.isConnected || isRefreshingAdvanced)

            Button(action: { showingEndpointDiscovery = true }) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("Debug: Discover HTTP Endpoints")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.3))
                .cornerRadius(12)
            }
            .foregroundColor(.white)
            .disabled(!service.isConnected || isRefreshingAdvanced)
        }
    }

    private var transferStatusView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Transfer Status", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            switch transferService.phase {
            case .idle:
                Text("Ready to start transfer.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            case .enablingWiFi:
                statusRow(title: "Stage", value: "Enabling headset Wi-Fi", systemImage: "wifi")
            case .disconnectingWiFi:
                statusRow(title: "Stage", value: "Disconnecting from current network…", systemImage: "wifi.slash")
            case .connectingHotspot:
                statusRow(title: "Stage", value: "Joining headset hotspot…", systemImage: "wifi.router")
            case .connected:
                Text("Connected to headset hotspot.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            case .listing:
                Text("Fetching device media list…")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            case .downloading(let current, let total):
                Text("Downloading files: \(current) / \(total)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
            case .completed:
                Text("Transfer complete. \(transferService.deviceFiles.count) files discovered.")
                    .font(.caption)
                    .foregroundColor(.green.opacity(0.9))
            case .failed(let message):
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.9))
            }

            if !transferService.deviceFiles.isEmpty {
                Text("Files on headset: \(transferService.deviceFiles.count)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Volume Levels", systemImage: "speaker.wave.2.fill")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))

            if let music = volumeLimits(for: .music), let call = volumeLimits(for: .call), let system = volumeLimits(for: .system) {
                sliderRow(for: .music, label: "Music", level: music)
                sliderRow(for: .call, label: "Call", level: call)
                sliderRow(for: .system, label: "System", level: system)
            } else {
                Button("Load Volume Info") {
                    performAdvancedChange {
                        await service.refreshAdvancedStatus()
                    }
                }
                .foregroundColor(.white)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.15))
                .cornerRadius(12)
                .disabled(isRefreshingAdvanced)
            }
        }
    }

    private func infoRow(title: String, value: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .foregroundColor(.white)
        }
        .font(.caption)
    }

    @ViewBuilder
    private func toggleRow(title: String, systemImage: String, binding: Binding<Bool>, isAvailable: Bool) -> some View {
        if isAvailable {
            Toggle(isOn: binding) {
                Label(title, systemImage: systemImage)
                    .foregroundColor(.white)
            }
            .disabled(isRefreshingAdvanced)
            .tint(.white)
        } else {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(.white.opacity(0.6))
                Text("\(title) unavailable")
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
            }
            .font(.caption)
        }
    }

    @ViewBuilder
    private func sliderRow(for mode: SmartGlassesVolumeMode, label: String, level: SmartGlassesVolumeLevel) -> some View {
        let upperBound = max(level.min + 1, level.max)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Text("\(level.current)")
                    .font(.caption.bold())
                    .foregroundColor(.white)
            }

            Slider(
                value: volumeBinding(for: mode),
                in: Double(level.min)...Double(upperBound),
                step: 1,
                onEditingChanged: { editing in
                    if !editing {
                        let draftValue = volumeDraft[mode] ?? Double(level.current)
                        let targetLevel = Int(draftValue.rounded())
                        performAdvancedChange {
                            await service.setVolume(level: targetLevel, for: mode)
                            await service.refreshAdvancedStatus()
                        }
                    }
                }
            )
            .tint(.white)
            .disabled(isRefreshingAdvanced)
        }
    }

    private func statusRow(title: String, value: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            Text(value)
                .foregroundColor(.white)
        }
    }

    private var selectedDevice: SmartGlassesDevice? {
        if let connected = service.connectedDevice {
            return connected
        }
        if let id = selectedDeviceID {
            return service.availableDevices.first(where: { $0.id == id })
        }
        return nil
    }

    private var formattedBattery: String {
        if let diagnostics = service.connectionDiagnostics {
            return "\(diagnostics.batteryLevel)%"
        }
        if let level = service.batteryLevel {
            return "\(level)%"
        }
        return "--"
    }

    private func batteryIconName() -> String {
        let level = service.connectionDiagnostics?.batteryLevel ?? service.batteryLevel ?? 0
        switch level {
        case 0...10: return "battery.0"
        case 11...25: return "battery.25"
        case 26...50: return "battery.50"
        case 51...75: return "battery.75"
        default: return "battery.100"
        }
    }

    private var completionStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Setup Complete!")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Your smart glasses are now connected to Lanna. You can start using voice commands and gesture controls.")
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }

    private var isWorking: Bool {
        switch currentStep {
        case 2:
            return service.isScanning
        case 3:
            return service.connectionState == .connecting
        case 4:
            return service.isRunningDiagnostics
        default:
            return false
        }
    }

    private var canProceed: Bool {
        switch currentStep {
        case 1:
            return permissionsGranted
        case 2:
            return !service.availableDevices.isEmpty && !service.isScanning
        case 3:
            return service.isConnected
        case 4:
            return service.isConnected && !service.isRunningDiagnostics && service.connectionDiagnostics != nil
        default:
            return true
        }
    }

    private func nextStep() {
        if currentStep == setupSteps.count - 1 {
            isSetupComplete = true
            forceSetupMode = false
            return
        }

        let nextIndex = currentStep + 1
        withAnimation {
            currentStep = nextIndex
        }

        switch nextIndex {
        case 1:
            requestPermissions()
        case 2:
            startScanning()
        case 4:
            runConnectionTest()
        default:
            break
        }
    }

    private func refreshPermissionState() {
        cameraPermissionGranted = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        microphonePermissionGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    private func requestPermissions() {
        Task {
            let granted = await service.requestPermissions()
            await MainActor.run {
                refreshPermissionState()
                if !granted {
                    showingPermissionAlert = true
                }
            }
        }
    }

    private func startTransferPreparation() {
        guard service.isConnected else { return }
        guard transferService.canStartTransfer else { return }
        Task {
            do {
                try await transferService.prepareSession()
            } catch {
                transferErrorMessage = error.localizedDescription
                showingTransferError = true
                transferService.reset()
            }
        }
    }

    private func performAdvancedChange(_ action: @escaping () async -> Void) {
        Task {
            await MainActor.run { isRefreshingAdvanced = true }
            await action()
            await MainActor.run {
                isRefreshingAdvanced = false
                hasLoadedAdvanced = true
                volumeDraft.removeAll()
            }
        }
    }

    private func openWiFiHotspot() {
        guard service.isConnected else { return }
        Task {
            await MainActor.run { isRefreshingAdvanced = true }
            let targetMode = service.advancedStatus.deviceMode == .unknown ? SmartGlassesDeviceMode.photo : service.advancedStatus.deviceMode
            let credentials = await service.openWiFiCredentials(for: targetMode)
            if credentials != nil {
                await service.refreshAdvancedStatus()
            }
            await MainActor.run {
                isRefreshingAdvanced = false
                if let credentials {
                    wifiCredentials = credentials
                    wifiErrorMessage = nil
                    showingWiFiError = false
                    showingWiFiCredentials = true
                    hasLoadedAdvanced = true
                } else {
                    wifiCredentials = nil
                    wifiErrorMessage = service.lastError?.message ?? "Unable to enable Wi-Fi hotspot."
                    showingWiFiError = wifiErrorMessage != nil
                    showingWiFiCredentials = false
                }
            }
        }
    }

    private var voiceWakeBinding: Binding<Bool> {
        Binding(
            get: { service.advancedStatus.voiceWakeEnabled ?? false },
            set: { newValue in
                performAdvancedChange {
                    await service.toggleVoiceWakeup(newValue)
                    await service.refreshAdvancedStatus()
                }
            }
        )
    }

    private var wearingDetectionBinding: Binding<Bool> {
        Binding(
            get: { service.advancedStatus.wearingDetectionEnabled ?? false },
            set: { newValue in
                performAdvancedChange {
                    await service.toggleWearingDetection(newValue)
                    await service.refreshAdvancedStatus()
                }
            }
        )
    }

    private var bluetoothBinding: Binding<Bool> {
        Binding(
            get: { service.advancedStatus.bluetoothEnabled ?? false },
            set: { newValue in
                performAdvancedChange {
                    await service.toggleBluetooth(newValue)
                    await service.refreshAdvancedStatus()
                }
            }
        )
    }

    private func volumeBinding(for mode: SmartGlassesVolumeMode) -> Binding<Double> {
        Binding(
            get: {
                if let draft = volumeDraft[mode] {
                    return draft
                }
                guard let limits = volumeLimits(for: mode) else { return 0 }
                return Double(limits.current)
            },
            set: { newValue in
                volumeDraft[mode] = newValue
            }
        )
    }

    private func volumeLimits(for mode: SmartGlassesVolumeMode) -> SmartGlassesVolumeLevel? {
        guard let info = service.advancedStatus.volumeInfo else { return nil }
        switch mode {
        case .music: return info.music
        case .call: return info.call
        case .system: return info.system
        }
    }

    private func startScanning() {
        selectedDeviceID = nil
        service.startScanning()
    }

    private func connect(device: SmartGlassesDevice) {
        selectedDeviceID = device.id
        service.stopScanning()
        service.connect(to: device)
    }

    private func runConnectionTest() {
        guard service.isConnected else { return }
        Task {
            await MainActor.run { isRefreshingAdvanced = true }
            _ = await service.performConnectionDiagnostics()
            await service.refreshAdvancedStatus()
            await MainActor.run {
                isRefreshingAdvanced = false
                hasLoadedAdvanced = true
                volumeDraft.removeAll()
            }
        }
    }

    private func iconForStep(_ step: Int) -> String {
        switch step {
        case 0: return "eyeglasses"
        case 1: return "hand.raised"
        case 2: return "magnifyingglass"
        case 3: return "link"
        case 4: return "checkmark.circle"
        case 5: return "checkmark.circle.fill"
        default: return "eyeglasses"
        }
    }

    private func descriptionForStep(_ step: Int) -> String {
        switch step {
        case 0: return "We'll guide you through connecting your smart glasses to Lanna in just a few simple steps."
        case 1: return "Lanna needs access to your camera and microphone to work with smart glasses. These permissions are required for gesture recognition and voice commands."
        case 2: return "Make sure your glasses are in pairing mode and within range."
        case 3: return "Select your smart glasses from the list of available devices and establish a secure connection."
        case 4: return "Let's test the connection to make sure everything is working properly before you start using Lanna."
        case 5: return "Congratulations! Your smart glasses are now connected and ready to use with Lanna."
        default: return ""
        }
    }
}

struct SimplePermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            Image(systemName: isGranted ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundColor(isGranted ? .green : .white.opacity(0.5))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    SmartGlassesSetupView(isSetupComplete: .constant(false))
}
