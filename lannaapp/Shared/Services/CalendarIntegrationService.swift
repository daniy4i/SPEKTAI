//
//  CalendarIntegrationService.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 10/1/25.
//

import Foundation
import EventKit
import FirebaseAuth
import FirebaseFirestore

class CalendarIntegrationService: ObservableObject {
    static let shared = CalendarIntegrationService()

    @Published var isCalendarEnabled = false
    @Published var hasCalendarAccess = false
    @Published var isLoadingStatus = false

    private let eventStore = EKEventStore()
    private let db = Firestore.firestore()
    private let userDefaults = UserDefaults.standard

    private let calendarEnabledKey = "isCalendarIntegrationEnabled"

    private init() {
        loadSettings()
        checkCalendarStatus()
    }

    // MARK: - Settings Management

    private func loadSettings() {
        isCalendarEnabled = userDefaults.bool(forKey: calendarEnabledKey)
    }

    private func saveSettings() {
        userDefaults.set(isCalendarEnabled, forKey: calendarEnabledKey)

        // Sync to Firebase
        if let userId = Auth.auth().currentUser?.uid {
            Task {
                try? await syncToFirebase(userId: userId)
            }
        }
    }

    // MARK: - Calendar Access

    func checkCalendarStatus() {
        isLoadingStatus = true
        defer { isLoadingStatus = false }

        let status = EKEventStore.authorizationStatus(for: .event)
        hasCalendarAccess = (status == .fullAccess || status == .authorized)
    }

    func requestCalendarAccess() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                await MainActor.run {
                    hasCalendarAccess = granted
                }
                return granted
            } else {
                return await withCheckedContinuation { continuation in
                    eventStore.requestAccess(to: .event) { [weak self] granted, error in
                        DispatchQueue.main.async {
                            self?.hasCalendarAccess = granted
                            continuation.resume(returning: granted)
                        }
                    }
                }
            }
        } catch {
            print("❌ Error requesting calendar access: \(error)")
            await MainActor.run {
                hasCalendarAccess = false
            }
            return false
        }
    }

    func enableCalendarIntegration() {
        isCalendarEnabled = true
        saveSettings()
        print("✅ Calendar integration enabled")
    }

    func disableCalendarIntegration() {
        isCalendarEnabled = false
        saveSettings()
        print("✅ Calendar integration disabled")
    }

    // MARK: - Event Fetching

    func fetchUpcomingEvents(from startDate: Date = Date(), days: Int = 7) -> [EKEvent] {
        guard isCalendarEnabled && hasCalendarAccess else {
            print("⚠️ Calendar not enabled or no access")
            return []
        }

        let endDate = Calendar.current.date(byAdding: .day, value: days, to: startDate) ?? startDate

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)

        print("📅 Fetched \(events.count) events")
        return events
    }

    func fetchTodayEvents() -> [EKEvent] {
        guard isCalendarEnabled && hasCalendarAccess else { return [] }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        return eventStore.events(matching: predicate)
    }

    func getNextEvent() -> EKEvent? {
        let events = fetchUpcomingEvents(from: Date(), days: 1)
        return events.first { $0.startDate > Date() }
    }

    // MARK: - Event Details

    func getEventDetails(for event: EKEvent) -> EventDetails {
        return EventDetails(
            title: event.title ?? "Untitled Event",
            location: event.location,
            startDate: event.startDate,
            endDate: event.endDate,
            attendees: event.attendees?.compactMap { $0.name } ?? [],
            notes: event.notes,
            url: event.url
        )
    }

    // MARK: - Firebase Sync

    private func syncToFirebase(userId: String) async throws {
        let data: [String: Any] = [
            "isCalendarEnabled": isCalendarEnabled,
            "hasCalendarAccess": hasCalendarAccess,
            "updatedAt": Date().timeIntervalSince1970
        ]

        try await db.collection("users")
            .document(userId)
            .collection("integrations")
            .document("calendar")
            .setData(data, merge: true)

        print("✅ Synced calendar settings to Firebase")
    }

    func loadFromFirebase(userId: String) async {
        do {
            let doc = try await db.collection("users")
                .document(userId)
                .collection("integrations")
                .document("calendar")
                .getDocument()

            if let data = doc.data() {
                await MainActor.run {
                    if let isEnabled = data["isCalendarEnabled"] as? Bool {
                        self.isCalendarEnabled = isEnabled
                        self.userDefaults.set(isEnabled, forKey: self.calendarEnabledKey)
                    }
                }
                print("✅ Loaded calendar settings from Firebase")
            }
        } catch {
            print("❌ Error loading calendar settings from Firebase: \(error)")
        }
    }
}

// MARK: - Event Details Model

struct EventDetails {
    let title: String
    let location: String?
    let startDate: Date
    let endDate: Date
    let attendees: [String]
    let notes: String?
    let url: URL?

    var duration: TimeInterval {
        return endDate.timeIntervalSince(startDate)
    }

    var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }

    var isToday: Bool {
        return Calendar.current.isDateInToday(startDate)
    }

    var isTomorrow: Bool {
        return Calendar.current.isDateInTomorrow(startDate)
    }
}
