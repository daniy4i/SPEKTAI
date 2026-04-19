# StoreKit Setup Guide for Lanna AI App

## ✅ What's Already Configured

Your app now has StoreKit fully enabled with the following components:

### 1. **StoreKit Framework** 
- ✅ Linked in Xcode project
- ✅ Available for iOS, macOS, and watchOS

### 2. **StoreKit Configuration File**
- ✅ `Configuration.storekit` created with your products:
  - `lannaplus` - Lanna AI Plus ($4.99/month)
  - `lanna_pro_monthly` - Lanna AI Pro ($9.99/month)
- ✅ Both products have 3-day free trials
- ✅ Testing mode enabled

### 3. **Entitlements**
- ✅ In-App Purchase capability added
- ✅ Merchant ID configured

### 4. **PurchaseService**
- ✅ Enhanced with proper async/await methods
- ✅ Better error handling and subscription status checking
- ✅ Transaction listener for real-time updates
- ✅ Cross-platform support (iOS/macOS)

### 5. **SubscriptionView**
- ✅ Updated to work with new async methods
- ✅ Integrated with PurchaseService
- ✅ Shows product information and pricing

## 🧪 How to Test StoreKit

### Option 1: StoreKit Testing (Recommended for Development)

1. **In Xcode:**
   - Go to `Product` → `Scheme` → `Edit Scheme`
   - Select `Run` → `Options`
   - Under `StoreKit Configuration`, select `Configuration.storekit`
   - Run your app

2. **Test Purchases:**
   - Navigate to the Subscription view
   - Select a plan and tap "Start Free Trial"
   - Use the StoreKit testing interface to approve/decline purchases

### Option 2: Sandbox Testing

1. **Create Sandbox Testers:**
   - Go to App Store Connect
   - Navigate to `Users and Access` → `Sandbox Testers`
   - Create test accounts

2. **Test on Device:**
   - Sign out of App Store on your device
   - Build and install your app
   - When prompted, sign in with sandbox tester account
   - Test purchases (they won't charge real money)

### Option 3: TestFlight

1. **Upload to TestFlight:**
   - Archive and upload your app
   - Add internal/external testers
   - Testers can make real purchases (but you can refund them)

## 🔧 Configuration Details

### Product IDs
- `lannaplus` - Lanna AI Plus subscription
- `lanna_pro_monthly` - Lanna AI Pro subscription

### Subscription Group
- `arthur_subscriptions` - Groups your products together

### Free Trials
- Both products offer 3-day free trials
- Configured in both StoreKit config and code

## 🚀 Production Deployment

When ready for production:

1. **Update StoreKitConfig.swift:**
   ```swift
   static let isTestingMode = false // Set to false for production
   ```

2. **Create Products in App Store Connect:**
   - Use the same product IDs: `lannaplus`, `lanna_pro_monthly`
   - Set up subscription groups
   - Configure pricing and availability

3. **Test with TestFlight:**
   - Upload to TestFlight first
   - Test with real App Store accounts
   - Verify purchases work correctly

## 🐛 Troubleshooting

### Products Not Loading
- Check product IDs match exactly between code and App Store Connect
- Verify StoreKit configuration file is selected in scheme
- Check network connectivity

### Purchase Failures
- Ensure you're signed in to App Store
- Check device has payment method (for sandbox)
- Verify app is properly signed

### Subscription Status Issues
- Call `checkSubscriptionStatus()` after app launch
- Ensure transaction listener is set up
- Check for proper error handling

## 📱 Usage in Your App

The `PurchaseService` is already integrated into your `SubscriptionView`. Key methods:

```swift
// Check current subscription
let currentPlan = await PurchaseService.shared.currentSubscription()

// Purchase a product
let transaction = try await PurchaseService.shared.purchase(product)

// Restore purchases
try await PurchaseService.shared.restorePurchases()

// Manage subscriptions
await PurchaseService.shared.manageSubscriptions()
```

## 🎯 Next Steps

1. **Test the integration** using StoreKit testing
2. **Create products in App Store Connect** when ready for production
3. **Test with TestFlight** before App Store submission
4. **Monitor analytics** to track subscription performance

Your StoreKit integration is now complete and ready for testing! 🎉




