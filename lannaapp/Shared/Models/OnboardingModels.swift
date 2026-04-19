//
//  OnboardingModels.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 8/31/25.
//

import Foundation
import SwiftUI

struct OnboardingPage {
    let id = UUID()
    let title: String
    let subtitle: String
    let imageName: String
    let primaryColor: Color
    let secondaryColor: Color
}

extension OnboardingPage {
    static let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Your Personal Executive Assistant",
            subtitle: "Meet Spekt, your AI-powered executive assistant designed to help you manage tasks, schedule meetings, and boost productivity throughout your day.",
            imageName: "person.badge.plus",
            primaryColor: Color(red: 0.2, green: 0.6, blue: 0.9),
            secondaryColor: Color(red: 0.1, green: 0.4, blue: 0.7)
        ),
        OnboardingPage(
            title: "Smart Glasses Integration",
            subtitle: "Connect your smart glasses for hands-free assistance. Spekt can display information, take notes, and provide real-time updates directly in your field of vision.",
            imageName: "eyeglasses",
            primaryColor: Color(red: 0.9, green: 0.4, blue: 0.2),
            secondaryColor: Color(red: 0.7, green: 0.3, blue: 0.1)
        ),
        OnboardingPage(
            title: "Voice & Gesture Control",
            subtitle: "Control Spekt with natural voice commands and hand gestures. Perfect for when you're on the go or need to keep your hands free for other tasks.",
            imageName: "hand.raised",
            primaryColor: Color(red: 0.6, green: 0.2, blue: 0.8),
            secondaryColor: Color(red: 0.4, green: 0.1, blue: 0.6)
        ),
        OnboardingPage(
            title: "Intelligent Task Management",
            subtitle: "Spekt learns your preferences and proactively manages your calendar, prioritizes tasks, and suggests optimizations to make your workflow more efficient.",
            imageName: "brain.head.profile",
            primaryColor: Color(red: 0.2, green: 0.7, blue: 0.4),
            secondaryColor: Color(red: 0.1, green: 0.5, blue: 0.3)
        ),
        OnboardingPage(
            title: "Ready to Get Started?",
            subtitle: "Let's set up your smart glasses and configure Spekt to work perfectly with your daily routine. This will only take a few minutes.",
            imageName: "checkmark.circle",
            primaryColor: Color(red: 0.8, green: 0.6, blue: 0.2),
            secondaryColor: Color(red: 0.6, green: 0.4, blue: 0.1)
        )
    ]
}
