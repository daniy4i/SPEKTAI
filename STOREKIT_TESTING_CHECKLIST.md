# StoreKit Testing Checklist

## ✅ Development Testing (StoreKit Configuration)

### In Xcode:
- [ ] StoreKit configuration file selected in scheme
- [ ] App builds and runs without errors
- [ ] Subscription view loads and shows products
- [ ] Products display correct names and prices
- [ ] Free trial information shows correctly
- [ ] Purchase flow initiates
- [ ] StoreKit testing dialog appears
- [ ] Successful purchase updates subscription status
- [ ] Cancelled purchase doesn't affect subscription
- [ ] Restore purchases works
- [ ] Error handling works for failed purchases

### Test Scenarios:
- [ ] Purchase Arthur AI Plus
- [ ] Purchase Arthur AI Pro  
- [ ] Cancel purchase
- [ ] Test with no internet connection
- [ ] Test restore purchases
- [ ] Test subscription status checking

## ✅ Production Testing (App Store Connect)

### App Store Connect Setup:
- [ ] Subscription group created: "Arthur AI Subscriptions"
- [ ] Product ID `arthuraiplus` created with correct pricing
- [ ] Product ID `arthur_pro_monthly` created with correct pricing
- [ ] Both products have 3-day free trials
- [ ] Products are localized for target markets
- [ ] Products are approved and ready for sale

### TestFlight Testing:
- [ ] App uploaded to TestFlight successfully
- [ ] TestFlight build processed and available
- [ ] Internal testers added
- [ ] External testers added (if needed)
- [ ] Testers can install app via TestFlight
- [ ] Real purchases work with sandbox accounts
- [ ] Subscription status updates correctly
- [ ] Receipt validation works
- [ ] Subscription management works

### Production Verification:
- [ ] `isTestingMode = false` in StoreKitConfig.swift
- [ ] StoreKit configuration removed from Xcode scheme
- [ ] App works with real App Store products
- [ ] No debug information shown to users
- [ ] Error messages are user-friendly
- [ ] Analytics tracking works (if implemented)

## 🐛 Common Issues & Solutions

### Products Not Loading:
- Check product IDs match exactly between code and App Store Connect
- Verify subscription group is set up correctly
- Ensure products are approved in App Store Connect
- Check network connectivity

### Purchase Failures:
- Verify user is signed in to App Store
- Check device has payment method (for sandbox)
- Ensure app is properly signed with correct team
- Verify bundle ID matches App Store Connect

### Subscription Status Issues:
- Call `checkSubscriptionStatus()` after app launch
- Ensure transaction listener is set up properly
- Check for proper error handling in async methods
- Verify receipt validation is working

### TestFlight Issues:
- Wait for processing to complete (up to 60 minutes)
- Ensure testers have valid Apple IDs
- Check that products are available in their region
- Verify app version is approved for testing

## 📊 Monitoring & Analytics

### Track These Metrics:
- [ ] Purchase conversion rates
- [ ] Free trial to paid conversion
- [ ] Subscription retention rates
- [ ] Churn rates
- [ ] Revenue per user
- [ ] Most popular subscription tier

### Tools to Use:
- App Store Connect analytics
- Firebase Analytics (if integrated)
- Custom analytics events
- Revenue tracking

## 🚀 Go-Live Checklist

Before submitting to App Store:
- [ ] All testing completed successfully
- [ ] Production mode enabled
- [ ] No debug code in production build
- [ ] Privacy policy updated for subscriptions
- [ ] Terms of service updated
- [ ] App Store description mentions subscriptions
- [ ] Screenshots show subscription features
- [ ] App review guidelines compliance checked
- [ ] Final TestFlight testing completed
- [ ] Team approval for App Store submission

## 📞 Support & Maintenance

### Post-Launch:
- [ ] Monitor subscription metrics
- [ ] Respond to user feedback about pricing
- [ ] Handle subscription-related support requests
- [ ] Plan for subscription price changes
- [ ] Monitor for fraudulent purchases
- [ ] Regular testing of purchase flows
- [ ] Keep StoreKit integration updated

---

**Remember:** Always test thoroughly in both development and production environments before going live!




