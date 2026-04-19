# Project Structure Overview

## Multi-Platform iOS App

This project is configured to support multiple Apple platforms:

### 📱 iOS & iPad
- **Entry Point**: `lannaapp/lannaappApp.swift`
- **Main View**: `lannaapp/ContentView.swift`
- **Scene Type**: `WindowGroup` (supports multiple windows)
- **Deployment**: iOS 18.1+

### 🖥️ macOS
- **Entry Point**: `lannaapp/lannaappApp.swift` (shared with iOS)
- **Main View**: `lannaapp/ContentView.swift` (shared with iOS)
- **Scene Type**: `WindowGroup` (supports multiple windows)
- **Deployment**: macOS 15.1+

### ⌚️ watchOS
- **Entry Point**: `lannaapp/lannaappWatchApp/lannaappWatchApp.swift`
- **Main View**: `lannaapp/lannaappWatchApp/WatchContentView.swift`
- **Scene Type**: `Window` (single window for watch)
- **Deployment**: watchOS 9.0+ (when target is added)

### 🥽 visionOS
- **Entry Point**: `lannaapp/lannaappApp.swift` (shared with iOS/macOS)
- **Main View**: `lannaapp/ContentView.swift` (shared with iOS/macOS)
- **Scene Type**: `WindowGroup` (supports spatial computing)
- **Deployment**: visionOS 2.1+

## File Organization

```
lannaapp/
├── lannaappApp.swift          # iOS/macOS/visionOS entry point
├── ContentView.swift             # Main content view (iOS/macOS/visionOS)
├── Assets.xcassets/              # Shared assets
├── lannaapp.entitlements     # App entitlements
├── lannaappWatchApp/         # watchOS app bundle
│   ├── lannaappWatchApp.swift # watchOS entry point
│   ├── WatchContentView.swift    # watchOS content view
│   └── Info.plist               # watchOS app info
└── Preview Content/              # SwiftUI previews
```

## Key Features

✅ **SwiftUI Only**: No storyboards - pure SwiftUI implementation
✅ **Shared Code**: Common views and logic shared across platforms
✅ **Platform Optimized**: Each platform can have platform-specific views
✅ **Modern Architecture**: Uses latest SwiftUI features for each platform
✅ **Multi-Target**: Supports building for all platforms simultaneously
✅ **No Naming Conflicts**: Each platform has uniquely named views

## Next Steps

1. **Add watchOS Target**: Use Xcode to add watchOS app target
2. **Test Each Platform**: Build and test on each platform simulator
3. **Platform-Specific Features**: Add platform-specific functionality as needed
4. **Asset Optimization**: Optimize assets for each platform's requirements

## Building

- **iOS**: Select iOS simulator or device
- **macOS**: Select macOS target
- **watchOS**: Select watchOS simulator or device (after adding target)
- **visionOS**: Select visionOS simulator or device

## Resolved Issues

✅ **Naming Conflicts**: Fixed duplicate ContentView.swift files
✅ **Build Errors**: Cleared derived data and build artifacts
✅ **File Organization**: Proper separation of platform-specific views
