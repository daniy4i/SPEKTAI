# Background Smart Glasses Photo Button Setup

## What This Does
When you press the photo button on your smart glasses while the app is in the background or closed, you'll receive a notification. Tapping the notification will open the app and start a realtime chat session automatically.

## Files Added/Modified

### 1. AppDelegate.swift (NEW)
- Handles background notifications
- Listens for photo taken events from smart glasses
- Sends local notifications to the user
- Opens realtime view when notification is tapped

### 2. lannaappApp.swift (MODIFIED)
- Now uses UIApplicationDelegateAdaptor to integrate AppDelegate

### 3. SmartGlassesService.swift (MODIFIED)
- Posts NotificationCenter event when photo is taken (line 977)
- Works even when app is in background

### 4. ProjectsListView.swift (MODIFIED)
- Listens for "OpenRealtimeView" notification (line 189-192)
- Opens realtime view when notification is received

### 5. RealtimeChatView.swift (MODIFIED)
- Auto-starts session when view appears (line 34-39)

## Setup Instructions

### Step 1: Add Background Modes and Permissions in Xcode

#### A. Add Background Modes Capability
1. Open `lannaapp.xcodeproj` in Xcode
2. Select your project in the left panel
3. Select the "lannaapp" iOS target
4. Go to "Signing & Capabilities" tab
5. Click "+ Capability" button
6. Search for and add "Background Modes"
7. Check these boxes:
   - ✅ **Audio, AirPlay, and Picture in Picture** (critical for voice chat in background!)
   - ✅ **Uses Bluetooth LE accessories** (for smart glasses connection)
   - ✅ Remote notifications (for notification delivery)

#### B. Add Required Permissions
1. Still in your target settings, go to the "Info" tab
2. Add these keys (if not already present):
   - **Privacy - Bluetooth Always Usage Description**: "Lanna needs Bluetooth to connect to your smart glasses and receive notifications when you take photos."
   - **Privacy - Microphone Usage Description**: "Lanna needs microphone access for voice commands and realtime chat."
   - **Privacy - Camera Usage Description**: "Lanna needs camera access for video features."
   - **Privacy - Location When In Use Usage Description**: "Lanna uses your location to provide context-aware AI responses during voice chats."
   - **Privacy - Location Always and When In Use Usage Description**: "Lanna uses your location to provide context-aware AI responses, even during background voice chats."

Or add them directly to your Info.plist by clicking on it and adding:
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Lanna needs Bluetooth to connect to your smart glasses and receive notifications when you take photos.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Lanna needs microphone access for voice commands and realtime chat.</string>
<key>NSCameraUsageDescription</key>
<string>Lanna needs camera access for video features.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Lanna uses your location to provide context-aware AI responses during voice chats.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Lanna uses your location to provide context-aware AI responses, even during background voice chats.</string>
```

### Step 2: Enable Notification Permissions
The app will automatically request notification permissions on first launch. Make sure to allow them when prompted.

### Step 3: Test the Flow

#### When App is in Foreground:
1. Open the app
2. Press photo button on your smart glasses
3. App should immediately open the RealtimeChatView and start a session

#### When App is in Background:
1. Put app in background (home screen)
2. Make sure Bluetooth is connected to glasses
3. Press photo button on your smart glasses
4. You should receive a notification: "Photo Taken - Tap to start a realtime conversation"
5. Tap the notification
6. App opens and RealtimeChatView appears with session started

#### When App is Closed:
1. Swipe up to close the app completely
2. Wait a few seconds for Bluetooth to reconnect to glasses
3. Press photo button on your smart glasses
4. You should receive a notification
5. Tap notification to reopen app with realtime view

## How It Works

### Event Flow:
```
Smart Glasses Photo Button Pressed
    ↓
Bluetooth → SmartGlassesService.didUpdateMedia()
    ↓
photoWasTaken = true + NotificationCenter.post("SmartGlassesPhotoTaken")
    ↓
AppDelegate.handlePhotoTaken() receives notification
    ↓
Local notification sent to user
    ↓
[User taps notification]
    ↓
AppDelegate.userNotificationCenter(didReceive:)
    ↓
NotificationCenter.post("OpenRealtimeView")
    ↓
ProjectsListView.onReceive() → showingRealtimeMode = true
    ↓
RealtimeChatView.onAppear() → startSession()
```

## Troubleshooting

### Notifications not appearing:
- Check notification permissions in Settings → lannaapp → Notifications
- Make sure Bluetooth is connected to glasses
- Check console logs for "📸 Photo taken notification received"

### App not opening realtime view:
- Verify Background Modes are enabled in Xcode capabilities
- Check console for "OpenRealtimeView" notification
- Make sure you tapped the notification (not just dismissed it)

### Bluetooth not working in background:
- Verify "Uses Bluetooth LE accessories" is checked in Background Modes capability
- Check that Bluetooth Always permission is granted in Settings
- Restart the app and reconnect to glasses

## Notes
- iOS may limit background Bluetooth after ~30 seconds of inactivity
- For best results, keep the glasses connected before going to background
- The notification will appear even if the app is force-closed, as long as Bluetooth was previously connected
