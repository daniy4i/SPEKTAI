import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @StateObject private var purchaseService = PurchaseService.shared
    @State private var selectedPlan: PaidPlan = .free
    @State private var currentUsage = UsageData()
    @State private var isPurchasing = false
    @State private var showingPurchaseError = false
    @State private var purchaseErrorMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Current plan header
                    currentPlanHeader

                    // Usage overview
                    usageOverview

                    // Plan options
                    planOptions

                    // Current plan details
                    currentPlanDetails

                    // Restore purchases button
                    restorePurchasesButton
                }
                .padding(20)
            }
            .background(Color.gray.opacity(0.1))
            .navigationTitle("Subscription")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("Done") { dismiss() }
                }
                #endif
            }
            .onAppear {
                Task {
                    selectedPlan = await purchaseService.currentSubscription()
                }
            }
            .alert("Purchase Error", isPresented: $showingPurchaseError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(purchaseErrorMessage)
            }
        }
    }

    private func purchasePlan(_ plan: PaidPlan, product: StoreKit.Product) {
        isPurchasing = true

        Task {
            do {
                let transaction = try await purchaseService.purchase(product)

                await MainActor.run {
                    isPurchasing = false
                    if transaction != nil {
                        selectedPlan = plan
                        // Show success message or navigate
                    }
                }
            } catch {
                await MainActor.run {
                    isPurchasing = false
                    purchaseErrorMessage = error.localizedDescription
                    showingPurchaseError = true
                }
            }
        }
    }

    private func restorePurchases() {
        Task {
            do {
                try await purchaseService.restorePurchases()
                selectedPlan = await purchaseService.currentSubscription()
            } catch {
                purchaseErrorMessage = "Failed to restore purchases: \(error.localizedDescription)"
                showingPurchaseError = true
            }
        }
    }
    
    private var currentPlanHeader: some View {
        let currentPlan = selectedPlan

        return VStack(spacing: 8) {
            Text("Current Plan")
                .font(.title2)
                .foregroundColor(.secondary)

            Text(currentPlan.rawValue)
                .font(.title)
                .fontWeight(.bold)

            if currentPlan != .free {
                Text("Active")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                Text(currentPlan.price)
                    .font(.title3)
                    .foregroundColor(.blue)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(DS.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var usageOverview: some View {
        VStack(spacing: 16) {
            Text("Usage This Month")
                .font(.title2)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 20) {
                // Chat usage
                VStack(spacing: 8) {
                    UsageRing(
                        progress: currentUsage.chatProgress,
                        size: 60,
                        color: .blue
                    )
                    Text("Chat")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Audio usage
                VStack(spacing: 8) {
                    UsageRing(
                        progress: currentUsage.audioProgress,
                        size: 60,
                        color: .orange
                    )
                    Text("Audio")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Video usage
                VStack(spacing: 8) {
                    UsageRing(
                        progress: currentUsage.videoProgress,
                        size: 60,
                        color: .red
                    )
                    Text("Video")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(DS.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var planOptions: some View {
        VStack(spacing: 16) {
            Text("Available Plans")
                .font(.title2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if purchaseService.isLoading {
                ProgressView("Loading plans...")
                    .padding()
            } else if let error = purchaseService.errorMessage {
                VStack(spacing: 8) {
                    Text("Error loading products:")
                        .font(.caption)
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                    
                    // Debug info
                    Text("Product IDs: arthuraiplus, arthur_pro_monthly")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding()
            } else {
                ForEach(PaidPlan.allCases.filter { $0 != .free }, id: \.self) { plan in
                    if let product = purchaseService.product(for: plan) {
                        // Show with StoreKit product data
                        PlanOptionCard(
                            plan: plan,
                            product: product,
                            isSelected: selectedPlan == plan,
                            isPurchased: false, // Will be updated when we check subscription status
                            isPurchasing: isPurchasing && selectedPlan == plan,
                            onSelect: { selectedPlan = plan },
                            onPurchase: { purchasePlan(plan, product: product) }
                        )
                    } else {
                        // Show with fallback data when StoreKit product isn't available
                        PlanOptionCard(
                            plan: plan,
                            product: nil,
                            isSelected: selectedPlan == plan,
                            isPurchased: false,
                            isPurchasing: isPurchasing && selectedPlan == plan,
                            onSelect: { selectedPlan = plan },
                            onPurchase: { 
                                // Show message that product isn't available for testing
                                purchaseErrorMessage = "Product not available for testing. Use StoreKit Configuration or TestFlight."
                                showingPurchaseError = true
                            }
                        )
                    }
                }
                
                // Debug section - remove in production
                VStack(alignment: .leading, spacing: 4) {
                    Text("Debug Info:")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("Loaded products: \(purchaseService.products.count)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    ForEach(purchaseService.products, id: \.id) { product in
                        Text("• \(product.id): \(product.displayName)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .background(DS.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var currentPlanDetails: some View {
        let currentPlan = selectedPlan

        return VStack(spacing: 16) {
            Text("Plan Features")
                .font(.title2)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(currentPlan.bullets, id: \.self) { bullet in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title3)

                        Text(bullet)
                            .font(.body)
                    }
                }
            }
        }
        .padding(20)
        .background(DS.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var restorePurchasesButton: some View {
        Button(action: restorePurchases) {
            Text("Restore Purchases")
                .font(.caption)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 16)
        }
    }
}

struct PlanOptionCard: View {
    let plan: PaidPlan
    let product: StoreKit.Product?
    let isSelected: Bool
    let isPurchased: Bool
    let isPurchasing: Bool
    let onSelect: () -> Void
    let onPurchase: () -> Void

    init(plan: PaidPlan, product: StoreKit.Product? = nil, isSelected: Bool = false, isPurchased: Bool = false, isPurchasing: Bool = false, onSelect: @escaping () -> Void = {}, onPurchase: @escaping () -> Void = {}) {
        self.plan = plan
        self.product = product
        self.isSelected = isSelected
        self.isPurchased = isPurchased
        self.isPurchasing = isPurchasing
        self.onSelect = onSelect
        self.onPurchase = onPurchase
    }

    var body: some View {
        VStack(spacing: 0) {
            // Plan header
            Button(action: onSelect) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(plan.rawValue)
                                .font(.body)
                                .fontWeight(.semibold)
                            
                            if plan.hasFreeTrial {
                                Text("FREE TRIAL")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green)
                                    .cornerRadius(4)
                            }
                        }

                        if let product = product {
                            VStack(alignment: .leading, spacing: 2) {
                                if plan.hasFreeTrial {
                                    Text(plan.freeTrialInfo ?? "")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                        .fontWeight(.medium)
                                }
                                Text(product.displayPrice)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                if plan.hasFreeTrial {
                                    Text(plan.freeTrialInfo ?? "")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                        .fontWeight(.medium)
                                }
                                Text(plan.price)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Spacer()

                    if isPurchased {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                    } else if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                    } else {
                        Circle()
                            .stroke(Color.gray, lineWidth: 2)
                            .frame(width: 24, height: 24)
                    }
                }
                .padding(20)
                .background(isSelected ? Color.blue.opacity(0.1) : DS.background)
            }
            .buttonStyle(.plain)

            // Purchase button
            if isSelected && !isPurchased {
                Divider()

                Button(action: onPurchase) {
                    HStack {
                        if isPurchasing {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Processing...")
                        } else {
                            if plan.hasFreeTrial {
                                Text("Start Free Trial")
                            } else {
                                Text("Subscribe")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(plan.hasFreeTrial ? Color.green : Color.blue)
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                }
                .disabled(isPurchasing)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.gray, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .background(DS.background)
    }
}

struct UsageData {
    let chatProgress: Double = 0.65  // 65% of monthly limit
    let audioProgress: Double = 0.30 // 30% of monthly limit  
    let videoProgress: Double = 0.15 // 15% of monthly limit
}

#Preview {
    SubscriptionView()
}
