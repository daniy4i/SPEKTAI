//
//  NotificationSyncService.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 10/1/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class NotificationSyncService: ObservableObject {
    static let shared = NotificationSyncService()

    @Published var notificationSettings: [AdrianaNotificationSettings] = []
    @Published var isLoading = false
    @Published var isSyncing = false
    @Published var lastSyncError: String?

    private let db = Firestore.firestore()
    private let localDB = NotificationDatabaseManager.shared
    private var listener: ListenerRegistration?

    private init() {
        loadLocalSettings()
    }

    deinit {
        stopListening()
    }

    // MARK: - Load & Initialize

    func loadLocalSettings() {
        let settings = localDB.getAllNotificationSettings()

        if settings.isEmpty {
            // Initialize with default settings
            notificationSettings = AdrianaNotificationType.allCases.map { type in
                AdrianaNotificationSettings(type: type, isEnabled: false)
            }
            _ = localDB.saveAllSettings(notificationSettings)
        } else {
            notificationSettings = settings
        }
    }

    // MARK: - Firebase Sync

    func startListening(userId: String) {
        stopListening()

        listener = db.collection("users")
            .document(userId)
            .collection("notification_settings")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("❌ Error listening to notification settings: \(error.localizedDescription)")
                    self.lastSyncError = error.localizedDescription
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("⚠️ No notification settings found in Firebase")
                    return
                }

                self.syncFromFirebase(documents: documents)
            }

        print("✅ Started listening to notification settings for user: \(userId)")
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    private func syncFromFirebase(documents: [QueryDocumentSnapshot]) {
        var updatedSettings: [AdrianaNotificationSettings] = []

        for document in documents {
            if let settings = AdrianaNotificationSettings.fromFirebaseDict(document.data()) {
                updatedSettings.append(settings)
                _ = localDB.saveNotificationSettings(settings)
            }
        }

        // Update published settings
        DispatchQueue.main.async {
            // Merge with existing settings (keep local-only settings)
            let existingTypes = Set(updatedSettings.map { $0.type })
            let localOnlySettings = self.notificationSettings.filter { !existingTypes.contains($0.type) }

            self.notificationSettings = updatedSettings + localOnlySettings
        }

        print("✅ Synced \(updatedSettings.count) notification settings from Firebase")
    }

    func syncToFirebase(userId: String) async throws {
        isSyncing = true
        defer { isSyncing = false }

        let batch = db.batch()

        for setting in notificationSettings {
            let docRef = db.collection("users")
                .document(userId)
                .collection("notification_settings")
                .document(setting.type.rawValue)

            var updatedSetting = setting
            updatedSetting.lastSyncedAt = Date()
            updatedSetting.updatedAt = Date()

            batch.setData(updatedSetting.toFirebaseDict(), forDocument: docRef)

            // Update local database with sync time
            _ = localDB.saveNotificationSettings(updatedSetting)
        }

        try await batch.commit()

        // Update published settings with new sync times
        await MainActor.run {
            self.notificationSettings = self.notificationSettings.map { setting in
                var updated = setting
                updated.lastSyncedAt = Date()
                return updated
            }
        }

        print("✅ Synced all notification settings to Firebase")
    }

    func syncSingleSettingToFirebase(userId: String, setting: AdrianaNotificationSettings) async throws {
        isSyncing = true
        defer { isSyncing = false }

        var updatedSetting = setting
        updatedSetting.lastSyncedAt = Date()
        updatedSetting.updatedAt = Date()

        let docRef = db.collection("users")
            .document(userId)
            .collection("notification_settings")
            .document(setting.type.rawValue)

        try await docRef.setData(updatedSetting.toFirebaseDict())

        // Update local database
        _ = localDB.saveNotificationSettings(updatedSetting)

        // Update published settings
        await MainActor.run {
            if let index = self.notificationSettings.firstIndex(where: { $0.type == setting.type }) {
                self.notificationSettings[index] = updatedSetting
            }
        }

        print("✅ Synced notification setting to Firebase: \(setting.type.displayName)")
    }

    // MARK: - Settings Management

    func updateSetting(_ setting: AdrianaNotificationSettings) {
        if let index = notificationSettings.firstIndex(where: { $0.type == setting.type }) {
            var updatedSetting = setting
            updatedSetting.updatedAt = Date()

            notificationSettings[index] = updatedSetting
            _ = localDB.saveNotificationSettings(updatedSetting)

            // Sync to Firebase if user is logged in
            if let userId = Auth.auth().currentUser?.uid {
                Task {
                    try? await syncSingleSettingToFirebase(userId: userId, setting: updatedSetting)
                }
            }
        }
    }

    func toggleNotification(_ type: AdrianaNotificationType) {
        if let index = notificationSettings.firstIndex(where: { $0.type == type }) {
            var updatedSetting = notificationSettings[index]
            updatedSetting.isEnabled.toggle()
            updatedSetting.updatedAt = Date()

            notificationSettings[index] = updatedSetting
            _ = localDB.saveNotificationSettings(updatedSetting)

            // Sync to Firebase if user is logged in
            if let userId = Auth.auth().currentUser?.uid {
                Task {
                    try? await syncSingleSettingToFirebase(userId: userId, setting: updatedSetting)
                }
            }

            print("✅ Toggled notification: \(type.displayName) -> \(updatedSetting.isEnabled ? "ON" : "OFF")")
        }
    }

    func updateScheduledTime(for type: AdrianaNotificationType, time: String) {
        if let index = notificationSettings.firstIndex(where: { $0.type == type }) {
            var updatedSetting = notificationSettings[index]
            updatedSetting.scheduledTime = time
            updatedSetting.updatedAt = Date()

            notificationSettings[index] = updatedSetting
            _ = localDB.saveNotificationSettings(updatedSetting)

            // Sync to Firebase if user is logged in
            if let userId = Auth.auth().currentUser?.uid {
                Task {
                    try? await syncSingleSettingToFirebase(userId: userId, setting: updatedSetting)
                }
            }

            print("✅ Updated scheduled time for \(type.displayName): \(time)")
        }
    }

    func updateLeadTime(for type: AdrianaNotificationType, minutes: Int) {
        if let index = notificationSettings.firstIndex(where: { $0.type == type }) {
            var updatedSetting = notificationSettings[index]
            updatedSetting.leadTimeMinutes = minutes
            updatedSetting.updatedAt = Date()

            notificationSettings[index] = updatedSetting
            _ = localDB.saveNotificationSettings(updatedSetting)

            // Sync to Firebase if user is logged in
            if let userId = Auth.auth().currentUser?.uid {
                Task {
                    try? await syncSingleSettingToFirebase(userId: userId, setting: updatedSetting)
                }
            }

            print("✅ Updated lead time for \(type.displayName): \(minutes) minutes")
        }
    }

    func updateInterval(for type: AdrianaNotificationType, minutes: Int) {
        if let index = notificationSettings.firstIndex(where: { $0.type == type }) {
            var updatedSetting = notificationSettings[index]
            updatedSetting.intervalMinutes = minutes
            updatedSetting.updatedAt = Date()

            notificationSettings[index] = updatedSetting
            _ = localDB.saveNotificationSettings(updatedSetting)

            // Sync to Firebase if user is logged in
            if let userId = Auth.auth().currentUser?.uid {
                Task {
                    try? await syncSingleSettingToFirebase(userId: userId, setting: updatedSetting)
                }
            }

            print("✅ Updated interval for \(type.displayName): \(minutes) minutes")
        }
    }

    func getSetting(for type: AdrianaNotificationType) -> AdrianaNotificationSettings? {
        return notificationSettings.first(where: { $0.type == type })
    }

    // MARK: - Batch Operations

    func resetAllToDefaults() {
        notificationSettings = AdrianaNotificationType.allCases.map { type in
            AdrianaNotificationSettings(type: type, isEnabled: false)
        }

        _ = localDB.saveAllSettings(notificationSettings)

        // Sync to Firebase if user is logged in
        if let userId = Auth.auth().currentUser?.uid {
            Task {
                try? await syncToFirebase(userId: userId)
            }
        }

        print("✅ Reset all notification settings to defaults")
    }

    func disableAll() {
        notificationSettings = notificationSettings.map { setting in
            var updated = setting
            updated.isEnabled = false
            updated.updatedAt = Date()
            return updated
        }

        _ = localDB.saveAllSettings(notificationSettings)

        // Sync to Firebase if user is logged in
        if let userId = Auth.auth().currentUser?.uid {
            Task {
                try? await syncToFirebase(userId: userId)
            }
        }

        print("✅ Disabled all notifications")
    }

    func enableAll() {
        notificationSettings = notificationSettings.map { setting in
            var updated = setting
            updated.isEnabled = true
            updated.updatedAt = Date()
            return updated
        }

        _ = localDB.saveAllSettings(notificationSettings)

        // Sync to Firebase if user is logged in
        if let userId = Auth.auth().currentUser?.uid {
            Task {
                try? await syncToFirebase(userId: userId)
            }
        }

        print("✅ Enabled all notifications")
    }
}
