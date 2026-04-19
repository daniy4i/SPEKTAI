import Foundation
import StoreKit
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Purchase Service

@MainActor
class PurchaseService: ObservableObject {
    static let shared = PurchaseService()
    
    @Published var products: [StoreKit.Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var purchasedProductIDs: Set<String> = []
    
    private var productIDs: Set<String> = [
        "lannaplus",  // Updated to match your App Store Connect product ID
        "arthur_pro_monthly"
    ]
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupTransactionListener()
        loadProducts()
        Task {
            await checkSubscriptionStatus()
        }
    }
    
    // MARK: - Product Management
    
    func loadProducts() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let storeProducts = try await Product.products(for: productIDs)
                await MainActor.run {
                    self.products = storeProducts
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load products: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    func product(for plan: PaidPlan) -> StoreKit.Product? {
        guard let productID = plan.productID else { return nil }
        return products.first { $0.id == productID }
    }
    
    // MARK: - Purchase Management
    
    func purchase(_ product: StoreKit.Product) async throws -> StoreKit.Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            return transaction
        case .userCancelled, .pending:
            return nil
        default:
            return nil
        }
    }
    
    func restorePurchases() async throws {
        try await AppStore.sync()
        await checkSubscriptionStatus()
    }
    
    func manageSubscriptions() async {
        do {
            #if canImport(UIKit)
            if let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene {
                try await AppStore.showManageSubscriptions(in: windowScene)
            }
            #elseif canImport(AppKit)
            // On macOS, open the App Store subscription management page
            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                NSWorkspace.shared.open(url)
            }
            #endif
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to open subscription management: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Subscription Status
    
    func currentSubscription() async -> PaidPlan {
        // Check for active subscriptions
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.productID == "arthur_pro_monthly" {
                    return .pro
                } else if transaction.productID == "lannaplus" {
                    return .plus
                }
            } catch {
                print("Error checking transaction: \(error)")
            }
        }
        return .free
    }
    
    func isSubscribed(to productID: String) async -> Bool {
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.productID == productID {
                    return true
                }
            } catch {
                print("Error checking subscription: \(error)")
            }
        }
        return false
    }
    
    func checkSubscriptionStatus() async {
        var activeSubscriptions: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                activeSubscriptions.insert(transaction.productID)
            } catch {
                print("Error checking subscription status: \(error)")
            }
        }
        
        await MainActor.run {
            self.purchasedProductIDs = activeSubscriptions
        }
    }
    
    // MARK: - Private Methods
    
    private func setupTransactionListener() {
        Task {
            for await result in Transaction.updates {
                do {
                    let transaction = try checkVerified(result)
                    await transaction.finish()
                    await MainActor.run {
                        self.purchasedProductIDs.insert(transaction.productID)
                    }
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PurchaseError.unverifiedTransaction
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Purchase Error

enum PurchaseError: Error, LocalizedError {
    case unverifiedTransaction
    
    var errorDescription: String? {
        switch self {
        case .unverifiedTransaction:
            return "Transaction could not be verified"
        }
    }
}
