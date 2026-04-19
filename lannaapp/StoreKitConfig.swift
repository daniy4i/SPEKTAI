//
//  StoreKitConfig.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 8/31/25.
//

import Foundation
import StoreKit

// MARK: - StoreKit Configuration for Testing

struct StoreKitConfig {
    
    // MARK: - Product IDs
    static let lannaPlusProductID = "lannaplus"  // Updated to match App Store Connect
    static let arthurProProductID = "arthur_pro_monthly"
    
    // MARK: - Subscription Groups
    static let subscriptionGroupID = "arthur_subscriptions"
    
    // MARK: - Free Trial Configuration
    static let freeTrialDuration: TimeInterval = 3 * 24 * 60 * 60 // 3 days in seconds
    
    // MARK: - Testing Configuration
    static let isTestingMode = false // Set to false for production
    
    // MARK: - StoreKit Configuration File
    static let configurationFileName = "Configuration"
    
    // MARK: - Helper Methods
    
    static func getFreeTrialInfo(for productID: String) -> String? {
        switch productID {
        case lannaPlusProductID:
            return "3-day free trial"
        case arthurProProductID:
            return "3-day free trial"
        default:
            return nil
        }
    }
    
    static func hasFreeTrial(for productID: String) -> Bool {
        return getFreeTrialInfo(for: productID) != nil
    }
    
    static func getConfigurationFileURL() -> URL? {
        guard isTestingMode else { return nil }
        return Bundle.main.url(forResource: configurationFileName, withExtension: "storekit")
    }
}

// MARK: - Production Configuration
// This configuration is used for production App Store builds
// Products are loaded from App Store Connect
