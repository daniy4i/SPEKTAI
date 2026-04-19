//
//  AppDelegate.swift
//  lannaapp
//
//  Background handling for smart glasses events
//

import UIKit
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        // Request notification permissions
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
            } else if let error = error {
                print("❌ Notification permission error: \(error)")
            }
        }

        // Register notification categories with "End Call" action
        let endCallAction = UNNotificationAction(
            identifier: "END_CALL",
            title: "End Call",
            options: [.destructive, .foreground]
        )

        let callCategory = UNNotificationCategory(
            identifier: "VOICE_CALL",
            actions: [endCallAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([callCategory])

        // Listen for photo taken notifications from SmartGlassesService
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePhotoTaken),
            name: NSNotification.Name("SmartGlassesPhotoTaken"),
            object: nil
        )

        return true
    }

    @objc private func handlePhotoTaken() {
        print("📸 Photo taken notification received in AppDelegate")

        // Check if app is in background or foreground
        let appState = UIApplication.shared.applicationState

        if appState == .active {
            // App is in foreground - open realtime view directly
            print("📱 App in foreground - opening realtime view")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("OpenRealtimeView"), object: nil)
            }
        } else {
            // App is in background - start background realtime session
            print("📱 App in background - starting realtime session automatically")

            Task { @MainActor in
                await BackgroundRealtimeManager.shared.startBackgroundSession()

                // Send persistent call-like notification with "End Call" button
                let content = UNMutableNotificationContent()
                content.title = "🎙️ Voice Chat Active"
                content.body = "Tap to return, or swipe to end call"
                content.sound = nil // No sound - session already started
                content.categoryIdentifier = "VOICE_CALL"
                content.threadIdentifier = "voice_call_session"

                // Remove any existing notifications
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["voice_call_active"])

                let request = UNNotificationRequest(
                    identifier: "voice_call_active",
                    content: content,
                    trigger: nil
                )

                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("❌ Error sending notification: \(error)")
                    } else {
                        print("✅ Call indicator notification sent")
                    }
                }
            }
        }
    }

    // Handle notification tap when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    // Handle notification tap when app is in background/closed
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {

        if response.actionIdentifier == "END_CALL" {
            // User tapped "End Call" button
            print("📞 User ended call from notification")
            Task { @MainActor in
                BackgroundRealtimeManager.shared.stopBackgroundSession()
                // Remove the notification
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["voice_call_active"])
            }
        } else if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            // User tapped the notification body - open app
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("OpenRealtimeView"), object: nil)
            }
        }

        completionHandler()
    }
}
