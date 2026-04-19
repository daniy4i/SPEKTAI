# Background Voice Chat Implementation

## Overview
When you press the photo button on your smart glasses while the app is in the background, the app automatically starts a voice chat session **without requiring you to open the app**. You can just start talking and the AI will respond through your device/glasses speakers.

## How It Works

### Scenario 1: App in Foreground
```
Press photo button → Opens realtime view → VAD enabled → Start talking
```

### Scenario 2: App in Background (NEW!)
```
Press photo button
    ↓
Bluetooth detects photo event
    ↓
BackgroundRealtimeManager starts voice chat session automatically
    ↓
Notification appears: "Voice chat started - just speak naturally"
    ↓
Audio session runs in background
    ↓
You can talk immediately - no need to open app!
    ↓
AI responds through speakers
    ↓
Session continues until you manually stop it
```

## Key Features

### ✅ True Background Operation
- Voice chat runs completely in background
- No need to tap notification or open app
- Just start talking after you see the notification
- Works even if phone is locked (if audio plays through connected device)

### ✅ Voice Activity Detection (VAD)
- Server-side speech detection
- Automatically detects when you start/stop speaking
- No button presses needed
- Natural conversation flow

### ✅ Low Latency
- Direct WebSocket connection to OpenAI
- Streaming audio (no recording → upload delay)
- Fast response times

## Files Created/Modified

### NEW Files:

1. **BackgroundRealtimeManager.swift** (184 lines)
   - Manages realtime sessions that run in background
   - Handles audio streaming without UI
   - Uses `AVAudioSession` with `.playAndRecord` category for background audio
   - Streams audio continuously via WebSocket
   - Singleton pattern for global access

### MODIFIED Files:

2. **AppDelegate.swift** (lines 37-78)
   - Detects if app is in background or foreground
   - Starts `BackgroundRealtimeManager` automatically when photo button pressed in background
   - Sends informational notification (no tap required)
   - Opens realtime view if app is in foreground

3. **RealtimeChatView.swift**
   - Simplified to VAD-only mode
   - Removed manual recording controls
   - Auto-starts VAD on session start

4. **BACKGROUND_SETUP_INSTRUCTIONS.md**
   - Added requirement for "Audio, AirPlay, and Picture in Picture" background mode

## Required Xcode Configuration

### Background Modes (CRITICAL)
You **MUST** enable these three background modes:

1. ✅ **Audio, AirPlay, and Picture in Picture**
   - Allows voice chat to continue in background
   - Required for microphone and speaker access

2. ✅ **Uses Bluetooth LE accessories**
   - Maintains connection to smart glasses
   - Receives photo button events

3. ✅ **Remote notifications**
   - Delivers informational notifications

### How to Enable:
1. Xcode → Project → Target → Signing & Capabilities
2. Click "+ Capability" → "Background Modes"
3. Check all three boxes above

## Technical Implementation

### Audio Session Configuration
```swift
AVAudioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
```
- `.playAndRecord` - Allows simultaneous input/output
- `.voiceChat` - Optimized for voice communication
- `.defaultToSpeaker` - Audio plays through speaker by default
- `.allowBluetooth` - Routes audio to Bluetooth devices (glasses)

### Continuous Audio Streaming
- Records at 24kHz, 16-bit mono (OpenAI Realtime requirement)
- Sends 100ms chunks every 100ms
- Strips WAV header, sends raw PCM16 data
- Server-side VAD detects speech automatically

### Event Handling
- Receives audio deltas from OpenAI
- Plays responses through device speakers
- Transcripts logged to console
- Can be enhanced to show responses in notification

## Testing Instructions

### Test 1: Background Voice Chat (Main Feature)
1. Open app, connect to glasses
2. Press Home button (app goes to background)
3. Press photo button on glasses
4. See notification: "Voice chat started - just speak naturally"
5. **Start talking immediately** (don't tap notification)
6. Listen for AI response through speaker/glasses
7. Continue conversation naturally

### Test 2: Foreground Behavior
1. Keep app open
2. Press photo button on glasses
3. Realtime view opens
4. VAD enables automatically
5. Start talking

### Test 3: Locked Screen (Advanced)
1. Lock phone
2. Make sure Bluetooth is connected
3. Press photo button on glasses
4. Check if audio routing works (may need AirPods/glasses)
5. Talk and listen for response

## Important Notes

### Audio Routing
- By default, audio plays through iPhone speaker
- If Bluetooth device (AirPods/glasses) is connected, audio routes there
- Background sessions work best with Bluetooth audio

### Session Management
- Background session continues until manually stopped
- To stop: Open app → Realtime view → "End Session"
- Or: Force quit the app
- Sessions timeout after extended silence (OpenAI limit)

### iOS Limitations
- Background audio sessions can run indefinitely with proper audio category
- iOS may suspend if no audio is playing for extended period
- Keep conversation active to maintain session
- System alerts/calls will interrupt session

### Privacy & Battery
- Microphone is active when session is running
- Shows microphone indicator in status bar (orange dot on iOS 14+)
- Battery usage higher during background sessions
- Users should be aware session is active

## Troubleshooting

### Background session doesn't start:
- Check "Audio, AirPlay, and Picture in Picture" is enabled in Background Modes
- Verify microphone permission granted
- Check console for error messages

### No audio in background:
- Make sure audio category is `.playAndRecord`
- Check audio routing settings
- Try with Bluetooth device connected

### Session stops after a few seconds:
- Ensure background modes are enabled
- Keep conversation active
- Check for competing audio sessions

### Can't hear AI responses:
- Check volume is up
- Verify audio routing (Settings → Bluetooth)
- Make sure phone isn't in silent mode for voice output

## Future Enhancements

### Possible Improvements:
1. **Rich Notifications**
   - Show AI responses in notification
   - Quick reply actions
   - Conversation history

2. **Visual Feedback**
   - Live Activity showing conversation state
   - Waveform visualization in notification
   - Speaking/listening indicator

3. **Smart Session Management**
   - Auto-end after period of silence
   - Battery optimization
   - Conversation summaries

4. **Multi-Modal**
   - Photo context in conversation
   - Show captured photo in chat
   - Reference images in queries

## Architecture Diagram

```
Smart Glasses (Photo Button)
         ↓
    Bluetooth LE
         ↓
SmartGlassesService.didUpdateMedia()
         ↓
NotificationCenter.post("SmartGlassesPhotoTaken")
         ↓
    AppDelegate
         ↓
UIApplication.applicationState check
         ↓
    ┌─────────┴─────────┐
    │                   │
Foreground         Background
    │                   │
Opens View      BackgroundRealtimeManager
    │                   │
RealtimeChat    ├─ Get API Key
    │           ├─ Connect WebSocket
    │           ├─ Start Audio Session
    │           └─ Stream Audio (VAD)
    │                   │
    └───────────────────┘
              ↓
      User starts talking
              ↓
    Audio → OpenAI Realtime API
              ↓
      AI Response (Audio)
              ↓
    Device Speaker/Bluetooth
```

## Summary

This implementation provides a seamless voice chat experience triggered by your smart glasses photo button. The key innovation is **true background operation** - you don't need to open the app or tap any notifications. Just press the button on your glasses and start talking. The AI will respond naturally through your device speakers or connected Bluetooth audio.

**Key requirement**: Enable the "Audio, AirPlay, and Picture in Picture" background mode in Xcode!
