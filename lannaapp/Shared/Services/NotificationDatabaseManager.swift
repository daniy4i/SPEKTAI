//
//  NotificationDatabaseManager.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 10/1/25.
//

import Foundation
import SQLite3

class NotificationDatabaseManager {
    static let shared = NotificationDatabaseManager()

    private var db: OpaquePointer?
    private let dbName = "adriana_notifications.sqlite"

    private init() {
        openDatabase()
        createTables()
    }

    deinit {
        closeDatabase()
    }

    // MARK: - Database Management

    private func openDatabase() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent(dbName)

        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("❌ Error opening database")
            return
        }
        print("✅ Successfully opened notification database at: \(fileURL.path)")
    }

    private func closeDatabase() {
        if sqlite3_close(db) != SQLITE_OK {
            print("❌ Error closing database")
        }
        db = nil
    }

    private func createTables() {
        let createTableQuery = """
        CREATE TABLE IF NOT EXISTS notification_settings (
            type TEXT PRIMARY KEY NOT NULL,
            isEnabled INTEGER NOT NULL DEFAULT 0,
            scheduledTime TEXT,
            leadTimeMinutes INTEGER,
            intervalMinutes INTEGER,
            lastSyncedAt REAL,
            updatedAt REAL NOT NULL,
            createdAt REAL NOT NULL
        );
        """

        if sqlite3_exec(db, createTableQuery, nil, nil, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("❌ Error creating table: \(errorMessage)")
            return
        }
        print("✅ Notification settings table created successfully")
    }

    // MARK: - CRUD Operations

    func saveNotificationSettings(_ settings: AdrianaNotificationSettings) -> Bool {
        let query = """
        INSERT OR REPLACE INTO notification_settings
        (type, isEnabled, scheduledTime, leadTimeMinutes, intervalMinutes, lastSyncedAt, updatedAt, createdAt)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Error preparing insert statement")
            return false
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, settings.type.rawValue, -1, nil)
        sqlite3_bind_int(statement, 2, settings.isEnabled ? 1 : 0)

        if let scheduledTime = settings.scheduledTime {
            sqlite3_bind_text(statement, 3, scheduledTime, -1, nil)
        } else {
            sqlite3_bind_null(statement, 3)
        }

        if let leadTimeMinutes = settings.leadTimeMinutes {
            sqlite3_bind_int(statement, 4, Int32(leadTimeMinutes))
        } else {
            sqlite3_bind_null(statement, 4)
        }

        if let intervalMinutes = settings.intervalMinutes {
            sqlite3_bind_int(statement, 5, Int32(intervalMinutes))
        } else {
            sqlite3_bind_null(statement, 5)
        }

        if let lastSyncedAt = settings.lastSyncedAt {
            sqlite3_bind_double(statement, 6, lastSyncedAt.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(statement, 6)
        }

        sqlite3_bind_double(statement, 7, settings.updatedAt.timeIntervalSince1970)
        sqlite3_bind_double(statement, 8, settings.createdAt.timeIntervalSince1970)

        if sqlite3_step(statement) != SQLITE_DONE {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("❌ Error inserting notification settings: \(errorMessage)")
            return false
        }

        print("✅ Saved notification settings for: \(settings.type.displayName)")
        return true
    }

    func getNotificationSettings(for type: AdrianaNotificationType) -> AdrianaNotificationSettings? {
        let query = "SELECT * FROM notification_settings WHERE type = ?;"

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Error preparing select statement")
            return nil
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, type.rawValue, -1, nil)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }

        return parseNotificationSettings(from: statement)
    }

    func getAllNotificationSettings() -> [AdrianaNotificationSettings] {
        let query = "SELECT * FROM notification_settings;"

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Error preparing select all statement")
            return []
        }

        defer { sqlite3_finalize(statement) }

        var settings: [AdrianaNotificationSettings] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let setting = parseNotificationSettings(from: statement) {
                settings.append(setting)
            }
        }

        return settings
    }

    func deleteNotificationSettings(for type: AdrianaNotificationType) -> Bool {
        let query = "DELETE FROM notification_settings WHERE type = ?;"

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Error preparing delete statement")
            return false
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, type.rawValue, -1, nil)

        if sqlite3_step(statement) != SQLITE_DONE {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("❌ Error deleting notification settings: \(errorMessage)")
            return false
        }

        print("✅ Deleted notification settings for: \(type.displayName)")
        return true
    }

    func updateLastSyncTime(for type: AdrianaNotificationType, syncTime: Date) -> Bool {
        let query = "UPDATE notification_settings SET lastSyncedAt = ? WHERE type = ?;"

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Error preparing update statement")
            return false
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_double(statement, 1, syncTime.timeIntervalSince1970)
        sqlite3_bind_text(statement, 2, type.rawValue, -1, nil)

        if sqlite3_step(statement) != SQLITE_DONE {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("❌ Error updating sync time: \(errorMessage)")
            return false
        }

        return true
    }

    // MARK: - Helper Methods

    private func parseNotificationSettings(from statement: OpaquePointer?) -> AdrianaNotificationSettings? {
        guard let statement = statement else { return nil }

        let typeString = String(cString: sqlite3_column_text(statement, 0))
        guard let type = AdrianaNotificationType(rawValue: typeString) else { return nil }

        let isEnabled = sqlite3_column_int(statement, 1) == 1

        let scheduledTime: String? = if sqlite3_column_type(statement, 2) != SQLITE_NULL {
            String(cString: sqlite3_column_text(statement, 2))
        } else {
            nil
        }

        let leadTimeMinutes: Int? = if sqlite3_column_type(statement, 3) != SQLITE_NULL {
            Int(sqlite3_column_int(statement, 3))
        } else {
            nil
        }

        let intervalMinutes: Int? = if sqlite3_column_type(statement, 4) != SQLITE_NULL {
            Int(sqlite3_column_int(statement, 4))
        } else {
            nil
        }

        let lastSyncedAt: Date? = if sqlite3_column_type(statement, 5) != SQLITE_NULL {
            Date(timeIntervalSince1970: sqlite3_column_double(statement, 5))
        } else {
            nil
        }

        let updatedAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 6))
        let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 7))

        return AdrianaNotificationSettings(
            type: type,
            isEnabled: isEnabled,
            scheduledTime: scheduledTime,
            leadTimeMinutes: leadTimeMinutes,
            intervalMinutes: intervalMinutes,
            lastSyncedAt: lastSyncedAt,
            updatedAt: updatedAt,
            createdAt: createdAt
        )
    }

    // MARK: - Batch Operations

    func saveAllSettings(_ settings: [AdrianaNotificationSettings]) -> Bool {
        var allSuccess = true
        for setting in settings {
            if !saveNotificationSettings(setting) {
                allSuccess = false
            }
        }
        return allSuccess
    }

    func clearAllSettings() -> Bool {
        let query = "DELETE FROM notification_settings;"

        if sqlite3_exec(db, query, nil, nil, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("❌ Error clearing all settings: \(errorMessage)")
            return false
        }

        print("✅ Cleared all notification settings")
        return true
    }
}
