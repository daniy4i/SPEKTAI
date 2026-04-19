import Foundation

// MARK: - Paid Plan Model

enum PaidPlan: String, CaseIterable {
    case free = "Free"
    case plus = "Plus"
    case pro = "Pro"
    
    var price: String {
        switch self {
        case .free:
            return "Free"
        case .plus:
            return "$9.99/month"
        case .pro:
            return "$19.99/month"
        }
    }
    
    var freeTrialInfo: String? {
        switch self {
        case .free:
            return nil
        case .plus:
            return "3-day free trial"
        case .pro:
            return "3-day free trial"
        }
    }
    
    var hasFreeTrial: Bool {
        return freeTrialInfo != nil
    }
    
    var bullets: [String] {
        switch self {
        case .free:
            return [
                "5 chat messages per day",
                "Basic AI responses",
                "Standard support"
            ]
        case .plus:
            return [
                "Unlimited chat messages",
                "Advanced AI responses",
                "Image generation (10/month)",
                "Priority support",
                "Export conversations"
            ]
        case .pro:
            return [
                "Everything in Plus",
                "Unlimited image generation",
                "Video generation (5/month)",
                "Audio generation (10/month)",
                "API access",
                "24/7 premium support",
                "Custom AI training"
            ]
        }
    }
    
    var productID: String? {
        switch self {
        case .free:
            return nil
        case .plus:
            return "arthuraiplus"  // Updated to match your App Store Connect product ID
        case .pro:
            return "arthur_pro_monthly"
        }
    }
}
