//
//  IntegrationsView.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 10/1/25.
//

import SwiftUI
import EventKit

struct IntegrationsView: View {
    @StateObject private var calendarService = CalendarIntegrationService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingCalendarPermissionAlert = false

    var body: some View {
        NavigationView {
            List {
                // Header Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "link.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.blue)

                            Spacer()

                            if calendarService.isLoadingStatus {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            }
                        }

                        Text("Integrations")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Connect external services to enhance your experience")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                // Calendar Integration
                Section {
                    IntegrationRow(
                        icon: "calendar",
                        title: "Calendar",
                        subtitle: calendarStatusText,
                        iconColor: .red,
                        isEnabled: Binding(
                            get: { calendarService.isCalendarEnabled },
                            set: { newValue in
                                if newValue {
                                    Task { await enableCalendarAccess() }
                                } else {
                                    disableCalendarAccess()
                                }
                            }
                        )
                    )

                    if calendarService.isCalendarEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Calendar Access")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            if calendarService.hasCalendarAccess {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Calendar access granted")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Text("Events will be used for meeting prep and travel reminders")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                            } else {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Calendar access needed")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Button(action: {
                                    openSettings()
                                }) {
                                    Text("Open Settings")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("Calendar")
                } footer: {
                    Text("Access your calendar events for meeting prep notifications and travel time reminders")
                }

                // Future Integrations Section
                Section {
                    IntegrationRow(
                        icon: "map",
                        title: "Maps",
                        subtitle: "Coming soon",
                        iconColor: .green,
                        isEnabled: .constant(false),
                        isDisabled: true
                    )

                    IntegrationRow(
                        icon: "cloud",
                        title: "Weather",
                        subtitle: "Coming soon",
                        iconColor: .blue,
                        isEnabled: .constant(false),
                        isDisabled: true
                    )

                    IntegrationRow(
                        icon: "envelope",
                        title: "Email",
                        subtitle: "Coming soon",
                        iconColor: .orange,
                        isEnabled: .constant(false),
                        isDisabled: true
                    )
                } header: {
                    Text("Coming Soon")
                }
            }
            .navigationTitle("Integrations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Calendar Permission Required", isPresented: $showingCalendarPermissionAlert) {
                Button("Open Settings") {
                    openSettings()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please grant calendar access in Settings to enable calendar integration.")
            }
        }
        .onAppear {
            calendarService.checkCalendarStatus()
        }
    }

    // MARK: - Helper Methods

    private var calendarStatusText: String {
        if !calendarService.isCalendarEnabled {
            return "Connect your calendar"
        } else if calendarService.hasCalendarAccess {
            return "Connected"
        } else {
            return "Permission needed"
        }
    }

    private func enableCalendarAccess() async {
        let granted = await calendarService.requestCalendarAccess()
        if granted {
            calendarService.enableCalendarIntegration()
        } else {
            await MainActor.run {
                showingCalendarPermissionAlert = true
            }
        }
    }

    private func disableCalendarAccess() {
        calendarService.disableCalendarIntegration()
    }

    private func openSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

// MARK: - Integration Row

struct IntegrationRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let iconColor: Color
    @Binding var isEnabled: Bool
    var isDisabled: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .disabled(isDisabled)
        }
        .padding(.vertical, 4)
        .opacity(isDisabled ? 0.5 : 1.0)
    }
}

// MARK: - Preview

#Preview {
    IntegrationsView()
}
