//
//  IntegrationsManager.swift
//  lannaapp
//
//  Single source of truth for all system integration permissions.
//  Checks real authorization status on init, requests on demand,
//  directs user to Settings when denied.
//
//  Safari has no system permission model — it uses a local toggle.
//

import Foundation
import EventKit
import Contacts
import UIKit
import SwiftUI

// MARK: - Integration Type

enum IntegrationType: String, CaseIterable, Identifiable {
    case calendar  = "calendar"
    case contacts  = "contacts"
    case reminders = "reminders"
    case safari    = "safari"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .calendar:  return "calendar"
        case .contacts:  return "person.2"
        case .reminders: return "bell.badge"
        case .safari:    return "safari"
        }
    }

    var title: String {
        switch self {
        case .calendar:  return "Calendar"
        case .contacts:  return "Contacts"
        case .reminders: return "Reminders"
        case .safari:    return "Safari"
        }
    }

    var subtitle: String {
        switch self {
        case .calendar:  return "Read & write events"
        case .contacts:  return "Look up names & details"
        case .reminders: return "Create & manage tasks"
        case .safari:    return "Web search context"
        }
    }
}

// MARK: - Integration Status

enum IntegrationStatus: Equatable {
    case notDetermined
    case authorized
    case denied
    case loading
}

// MARK: - Integrations Manager

@MainActor
final class IntegrationsManager: ObservableObject {

    static let shared = IntegrationsManager()

    @Published var calendarStatus : IntegrationStatus = .notDetermined
    @Published var contactsStatus : IntegrationStatus = .notDetermined
    @Published var remindersStatus: IntegrationStatus = .notDetermined
    @Published var safariStatus   : IntegrationStatus = .notDetermined

    @Published var showDeniedAlert = false
    @Published var deniedService   = ""

    private let eventStore   = EKEventStore()
    private let contactStore = CNContactStore()
    private let safariKey    = "spekt_safari_connected"

    private init() {
        refreshAll()
    }

    // MARK: - Refresh

    func refreshAll() {
        checkCalendar()
        checkContacts()
        checkReminders()
        checkSafari()
    }

    // MARK: - Status helpers

    func status(for type: IntegrationType) -> IntegrationStatus {
        switch type {
        case .calendar:  return calendarStatus
        case .contacts:  return contactsStatus
        case .reminders: return remindersStatus
        case .safari:    return safariStatus
        }
    }

    var connectedCount: Int {
        IntegrationType.allCases.filter { status(for: $0) == .authorized }.count
    }

    // MARK: - Connect dispatcher

    func connect(_ type: IntegrationType) {
        Task { await connectAsync(type) }
    }

    private func connectAsync(_ type: IntegrationType) async {
        switch type {
        case .calendar:  await requestCalendar()
        case .contacts:  await requestContacts()
        case .reminders: await requestReminders()
        case .safari:    toggleSafari()
        }
    }

    // MARK: - Calendar

    func checkCalendar() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .authorized: calendarStatus = .authorized
        case .denied, .restricted:     calendarStatus = .denied
        default:                       calendarStatus = .notDetermined
        }
    }

    private func requestCalendar() async {
        calendarStatus = .loading
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await eventStore.requestFullAccessToEvents()
            } else {
                granted = await withCheckedContinuation { cont in
                    eventStore.requestAccess(to: .event) { ok, _ in cont.resume(returning: ok) }
                }
            }
            calendarStatus = granted ? .authorized : .denied
            if !granted { flagDenied("Calendar") }
        } catch {
            calendarStatus = .denied
        }
    }

    // MARK: - Contacts

    func checkContacts() {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized, .limited: contactsStatus = .authorized
        case .denied, .restricted:  contactsStatus = .denied
        default:                    contactsStatus = .notDetermined
        }
    }

    private func requestContacts() async {
        contactsStatus = .loading
        do {
            let granted = try await contactStore.requestAccess(for: .contacts)
            contactsStatus = granted ? .authorized : .denied
            if !granted { flagDenied("Contacts") }
        } catch {
            contactsStatus = .denied
        }
    }

    // MARK: - Reminders

    func checkReminders() {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess, .authorized: remindersStatus = .authorized
        case .denied, .restricted:     remindersStatus = .denied
        default:                       remindersStatus = .notDetermined
        }
    }

    private func requestReminders() async {
        remindersStatus = .loading
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await eventStore.requestFullAccessToReminders()
            } else {
                granted = await withCheckedContinuation { cont in
                    eventStore.requestAccess(to: .reminder) { ok, _ in cont.resume(returning: ok) }
                }
            }
            remindersStatus = granted ? .authorized : .denied
            if !granted { flagDenied("Reminders") }
        } catch {
            remindersStatus = .denied
        }
    }

    // MARK: - Safari (local toggle — no system permission)

    func checkSafari() {
        safariStatus = UserDefaults.standard.bool(forKey: safariKey) ? .authorized : .notDetermined
    }

    func toggleSafari() {
        let wasConnected = safariStatus == .authorized
        UserDefaults.standard.set(!wasConnected, forKey: safariKey)
        withAnimation(SpektTheme.Motion.springSnappy) {
            safariStatus = wasConnected ? .notDetermined : .authorized
        }
    }

    // MARK: - Settings

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func flagDenied(_ service: String) {
        deniedService   = service
        showDeniedAlert = true
    }
}
