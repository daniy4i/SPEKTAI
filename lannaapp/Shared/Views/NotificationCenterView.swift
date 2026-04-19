//
//  NotificationCenterView.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 10/1/25.
//

import SwiftUI

struct NotificationCenterView: View {
    @StateObject private var syncService = NotificationSyncService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingResetAlert = false

    var body: some View {
        NavigationView {
            List {
                // Header Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.blue)

                            Spacer()

                            if syncService.isSyncing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            }
                        }

                        Text("Notification Center")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Manage your notification preferences")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                // Quick Actions
                Section {
                    Button(action: {
                        syncService.enableAll()
                    }) {
                        Label("Enable All Notifications", systemImage: "bell.fill")
                            .foregroundColor(.blue)
                    }

                    Button(action: {
                        syncService.disableAll()
                    }) {
                        Label("Disable All Notifications", systemImage: "bell.slash")
                            .foregroundColor(.orange)
                    }

                    Button(action: {
                        showingResetAlert = true
                    }) {
                        Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                            .foregroundColor(.red)
                    }
                } header: {
                    Text("Quick Actions")
                }

                // Individual Notification Settings
                ForEach(AdrianaNotificationType.allCases, id: \.self) { type in
                    Section {
                        NotificationSettingRow(
                            type: type,
                            setting: syncService.getSetting(for: type),
                            onToggle: {
                                syncService.toggleNotification(type)
                            },
                            onUpdateTime: { time in
                                syncService.updateScheduledTime(for: type, time: time)
                            },
                            onUpdateLeadTime: { minutes in
                                syncService.updateLeadTime(for: type, minutes: minutes)
                            },
                            onUpdateInterval: { minutes in
                                syncService.updateInterval(for: type, minutes: minutes)
                            }
                        )
                    } header: {
                        HStack {
                            Text(type.emoji)
                            Text(type.displayName)
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Reset All Settings?", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    syncService.resetAllToDefaults()
                }
            } message: {
                Text("This will reset all notification settings to their default values. This action cannot be undone.")
            }
        }
    }
}

// MARK: - Notification Setting Row

struct NotificationSettingRow: View {
    let type: AdrianaNotificationType
    let setting: AdrianaNotificationSettings?
    let onToggle: () -> Void
    let onUpdateTime: (String) -> Void
    let onUpdateLeadTime: (Int) -> Void
    let onUpdateInterval: (Int) -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main Toggle Row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(type.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(isExpanded ? nil : 2)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { setting?.isEnabled ?? false },
                    set: { _ in onToggle() }
                ))
                .labelsHidden()
            }

            // Configuration Options (shown when enabled)
            if setting?.isEnabled == true {
                Divider()

                if type.requiresScheduledTime {
                    scheduledTimePicker
                }

                if type.requiresLeadTime {
                    leadTimePicker
                }

                if type.requiresInterval {
                    intervalPicker
                }

                // Additional Info
                if type.isEventBased {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("Triggered by calendar events")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Configuration Views

    @ViewBuilder
    private var scheduledTimePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scheduled Time")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.blue)

                DatePicker(
                    "Time",
                    selection: Binding(
                        get: {
                            timeFromString(setting?.scheduledTime ?? type.defaultTime)
                        },
                        set: { newDate in
                            onUpdateTime(timeToString(newDate))
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .datePickerStyle(.compact)
            }
        }
    }

    @ViewBuilder
    private var leadTimePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notify Before Event")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            HStack {
                Image(systemName: "bell.badge")
                    .foregroundColor(.blue)

                Picker("Lead Time", selection: Binding(
                    get: { setting?.leadTimeMinutes ?? 45 },
                    set: { onUpdateLeadTime($0) }
                )) {
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                    Text("45 minutes").tag(45)
                    Text("1 hour").tag(60)
                    Text("2 hours").tag(120)
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        }
    }

    @ViewBuilder
    private var intervalPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Work Interval")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            HStack {
                Image(systemName: "timer")
                    .foregroundColor(.blue)

                Picker("Interval", selection: Binding(
                    get: { setting?.intervalMinutes ?? 25 },
                    set: { onUpdateInterval($0) }
                )) {
                    Text("15 minutes").tag(15)
                    Text("25 minutes (Pomodoro)").tag(25)
                    Text("30 minutes").tag(30)
                    Text("45 minutes").tag(45)
                    Text("60 minutes").tag(60)
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        }
    }

    // MARK: - Helper Methods

    private func timeFromString(_ timeString: String) -> Date {
        let components = timeString.split(separator: ":")
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return Date()
        }

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        return Calendar.current.date(from: dateComponents) ?? Date()
    }

    private func timeToString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    NotificationCenterView()
}
