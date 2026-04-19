//
//  AnalyticsService.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 9/2/25.
//

import Foundation
import FirebaseAnalytics

class AnalyticsService {
    static let shared = AnalyticsService()
    
    private init() {}
    
    // MARK: - Chat Events
    
    func trackMessageSent(platform: String) {
        Analytics.logEvent("message_sent", parameters: [
            "platform": platform,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackMessageReceived(platform: String, responseTime: TimeInterval) {
        Analytics.logEvent("message_received", parameters: [
            "platform": platform,
            "response_time": responseTime,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Attachment Events
    
    func trackAttachmentButtonTapped(platform: String) {
        Analytics.logEvent("attachment_button_tapped", parameters: [
            "platform": platform,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackPhotoLibrarySelected(platform: String) {
        Analytics.logEvent("photo_library_selected", parameters: [
            "platform": platform,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackCameraSelected(platform: String) {
        Analytics.logEvent("camera_selected", parameters: [
            "platform": platform,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackFilePickerSelected(platform: String) {
        Analytics.logEvent("file_picker_selected", parameters: [
            "platform": platform,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackVideoPickerSelected(platform: String) {
        Analytics.logEvent("video_picker_selected", parameters: [
            "platform": platform,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackFileUploaded(platform: String, fileType: String, fileSize: Int) {
        Analytics.logEvent("file_uploaded", parameters: [
            "platform": platform,
            "file_type": fileType,
            "file_size": fileSize,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Navigation Events
    
    func trackConversationSelected(platform: String) {
        Analytics.logEvent("conversation_selected", parameters: [
            "platform": platform,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackNewConversationCreated(platform: String) {
        Analytics.logEvent("new_conversation_created", parameters: [
            "platform": platform,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackProjectSelected(platform: String, projectType: String) {
        Analytics.logEvent("project_selected", parameters: [
            "platform": platform,
            "project_type": projectType,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Authentication Events
    
    func trackUserLogin(platform: String, method: String) {
        Analytics.logEvent(AnalyticsEventLogin, parameters: [
            "platform": platform,
            "method": method,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackUserSignup(platform: String) {
        Analytics.logEvent(AnalyticsEventSignUp, parameters: [
            "platform": platform,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Error Events
    
    func trackError(platform: String, error: String, context: String) {
        Analytics.logEvent("error_occurred", parameters: [
            "platform": platform,
            "error": error,
            "context": context,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Helper Methods
    
    var currentPlatform: String {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        #elseif os(macOS)
        return "macOS"
        #elseif os(watchOS)
        return "watchOS"
        #else
        return "unknown"
        #endif
    }
}