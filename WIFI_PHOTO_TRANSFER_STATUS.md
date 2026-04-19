# WiFi Photo Transfer - Implementation Status

## 🎯 Current Status: DISCOVERY PHASE

### ✅ What's Been Implemented

#### 1. HTTP Endpoint Discovery Tool
**Files created:**
- `SmartGlassesEndpointDiscovery.swift` - Discovery logic
- `SmartGlassesEndpointDiscoveryView.swift` - UI for testing
- Integrated into SmartGlassesSetupView

**Features:**
- Tests 50+ HTTP endpoints automatically
- Tries 6 common IP addresses
- Tests file naming patterns
- Shows response data and content types
- Export results to text
- Built-in retry logic

#### 2. Existing WiFi Infrastructure
**Files:**
- `SmartGlassesTransferService.swift` - Transfer orchestration
- `SmartGlassesMediaTransferView.swift` - UI (partially working)

**Working features:**
- WiFi hotspot enablement
- iPhone connection to glasses hotspot
- IP address detection
- Basic HTTP requests

**Incomplete features:**
- ❌ File listing (endpoints unknown)
- ❌ Thumbnail loading (endpoints unknown)
- ❌ File download (pattern unknown)

#### 3. Documentation
- `ENDPOINT_DISCOVERY_GUIDE.md` - Comprehensive guide
- `QUICK_TEST_STEPS.md` - Quick reference
- This status document

---

## 🔍 Next Steps (Priority Order)

### STEP 1: Run Discovery Tool ⭐ **DO THIS FIRST**

**Action required:**
1. Connect HeyCyan glasses via Bluetooth
2. Open Lanna app
3. Navigate to Smart Glasses setup
4. Tap "Debug: Discover HTTP Endpoints"
5. Let it run completely (~3 minutes)
6. Export and review results

**Why this is critical:**
We need to discover the actual HTTP endpoints the glasses use. The SDK doesn't document these, so we must find them through testing.

**Expected discoveries:**
- File listing endpoint (e.g., `/files/list`, `/media/list`)
- File download pattern (e.g., `/files/{filename}`)
- Thumbnail access pattern (e.g., `/thumbnails/{index}.jpg`)
- JSON structure for file metadata

---

### STEP 2: Update Transfer Service

**File:** `SmartGlassesTransferService.swift`

**Functions to update:**

#### A. `fetchDeviceMediaList()` (Lines 318-384)
Replace with discovered endpoint:
```swift
private func fetchDeviceMediaList(ipAddress: String?) async throws -> [DeviceMediaFile] {
    // Use discovered endpoint from testing
    let listURL = URL(string: "http://\(ipAddress)/DISCOVERED_ENDPOINT")!
    let (data, response) = try await URLSession.shared.data(from: listURL)

    // Parse using discovered JSON structure
    let json = try JSONDecoder().decode(DiscoveredStructure.self, from: data)
    return json.files.map { convertToDeviceMediaFile($0) }
}
```

#### B. `downloadFile()` (Lines 539-603)
Update with discovered download pattern:
```swift
private func downloadFile(_ file: DeviceMediaFile) async throws -> URL {
    // Use discovered download pattern
    let downloadURL = URL(string: "http://\(ipAddress)/DISCOVERED_PATTERN/\(file.name)")!
    let (data, _) = try await URLSession.shared.data(from: downloadURL)
    // ... save to disk
}
```

#### C. Add thumbnail loading:
```swift
func loadThumbnail(for file: DeviceMediaFile, ipAddress: String) async -> UIImage? {
    // Use discovered thumbnail endpoint
    let thumbURL = URL(string: "http://\(ipAddress)/DISCOVERED_THUMB_ENDPOINT")!
    let (data, _) = try? await URLSession.shared.data(from: thumbURL)
    return data.flatMap { UIImage(data: $0) }
}
```

---

### STEP 3: Create Thumbnail Grid View

**New file:** `SmartGlassesMediaBrowserView.swift`

**Features:**
- Grid of thumbnail images
- File name and size labels
- Selection checkboxes
- "Download Selected" button
- Progress indicators

**Layout:**
```
┌─────────────────────────────┐
│ Media on Glasses (24)       │
├─────────────────────────────┤
│ ┌───┐ ┌───┐ ┌───┐ ┌───┐    │
│ │[✓]│ │[ ]│ │[✓]│ │[ ]│    │ <- Thumbnails in grid
│ │IMG│ │IMG│ │IMG│ │IMG│    │
│ │001│ │002│ │003│ │004│    │
│ └───┘ └───┘ └───┘ └───┘    │
│                             │
│ [Download 2 Selected]       │ <- Action button
└─────────────────────────────┘
```

---

### STEP 4: Implement Selective Download

**Features:**
- Multi-select thumbnails
- Batch download with progress
- Save to camera roll (with permission)
- Option to keep in app only

**Flow:**
```
1. User opens Media Browser
2. Thumbnails load via WiFi
3. User selects photos to download
4. Tap "Download Selected"
5. Progress bar shows X/Y downloaded
6. Success: Photos saved to Camera Roll
7. Option to delete from glasses
```

---

### STEP 5: Add Photo Management

**Features:**
- View downloaded photos
- Delete from glasses remotely
- Delete all media option
- Storage space indicator

---

## 📊 Implementation Timeline

| Phase | Time Estimate | Blocker |
|-------|---------------|---------|
| **Discovery** | 5 min | User must run tool |
| **Update Service** | 1 hour | Needs discovery results |
| **Thumbnail Grid** | 2-3 hours | Needs updated service |
| **Selective Download** | 1-2 hours | Needs grid view |
| **Photo Management** | 1-2 hours | Needs download working |
| **Testing & Polish** | 2-3 hours | Needs all above |
| **TOTAL** | **8-12 hours** | - |

**Critical path:** Discovery must happen first!

---

## 🐛 Known Issues & Limitations

### Current Problems

1. **Empty thumbnail data via Bluetooth**
   - `getThumbnail()` returns 0 bytes
   - SDK implementation incomplete
   - **Solution:** Use WiFi thumbnails instead

2. **Unknown HTTP endpoints**
   - SDK doesn't document web server API
   - Must discover through testing
   - **Solution:** Run discovery tool

3. **Audio disruption during transfer**
   - Transfer mode disables Bluetooth audio
   - Glasses can't play audio while in WiFi mode
   - **Solution:** Quick sync, then restore normal mode

4. **IP address inconsistency**
   - SDK reports `3.192.168.31` (invalid)
   - Hardcoded fallback to `192.168.31.1`
   - **Solution:** Discovery tool tries multiple IPs

### Workarounds Implemented

1. **Quick thumbnail sync:** Enter/exit transfer mode quickly
2. **Multiple IP attempts:** Try 6 common IPs
3. **Retry logic:** 3 attempts with backoff
4. **Auto mode restoration:** Return to normal after transfer

---

## 🎯 Success Metrics

### Minimum Viable Product (MVP)
- ✅ Discovery tool working
- ⏳ File listing working
- ⏳ File download working
- ⏳ View photos in app

### Enhanced Features
- ⏳ Thumbnail previews
- ⏳ Selective download
- ⏳ Save to camera roll
- ⏳ Delete from glasses

### Polish
- ⏳ Progress indicators
- ⏳ Error handling
- ⏳ Background downloads
- ⏳ Notification on photo taken

---

## 🔧 Technical Architecture

```
┌─────────────────────────────────────────────────────┐
│                   User Interface                     │
├─────────────────────────────────────────────────────┤
│ SmartGlassesSetupView                               │
│   ├─ Dashboard (battery, status)                    │
│   ├─ WiFi Controls                                  │
│   └─ [Debug: Discover Endpoints] ← NEW             │
├─────────────────────────────────────────────────────┤
│ SmartGlassesEndpointDiscoveryView ← NEW             │
│   ├─ WiFi Connection UI                             │
│   ├─ Progress Display                               │
│   └─ Results List                                   │
├─────────────────────────────────────────────────────┤
│ SmartGlassesMediaBrowserView ← TODO                 │
│   ├─ Thumbnail Grid                                 │
│   ├─ Selection UI                                   │
│   └─ Download Controls                              │
├─────────────────────────────────────────────────────┤
│                  Business Logic                      │
├─────────────────────────────────────────────────────┤
│ SmartGlassesService (Bluetooth)                     │
│   ├─ Device connection                              │
│   ├─ Battery status                                 │
│   ├─ Media count                                    │
│   └─ Mode control                                   │
├─────────────────────────────────────────────────────┤
│ SmartGlassesTransferService (WiFi)                  │
│   ├─ Hotspot connection                             │
│   ├─ File listing ← NEEDS UPDATE                    │
│   ├─ File download ← NEEDS UPDATE                   │
│   └─ Mode restoration                               │
├─────────────────────────────────────────────────────┤
│ SmartGlassesEndpointDiscovery ← NEW                 │
│   ├─ IP address discovery                           │
│   ├─ Endpoint testing                               │
│   ├─ Pattern detection                              │
│   └─ Result export                                  │
├─────────────────────────────────────────────────────┤
│                   Data Layer                         │
├─────────────────────────────────────────────────────┤
│ QCSDK Framework (from HeyCyan)                      │
│   ├─ BLE communication                              │
│   ├─ Command protocol                               │
│   └─ WiFi credential generation                     │
├─────────────────────────────────────────────────────┤
│ URLSession (HTTP)                                   │
│   ├─ File listing requests                          │
│   ├─ Thumbnail downloads                            │
│   └─ Full file downloads                            │
└─────────────────────────────────────────────────────┘
```

---

## 📝 Code Changes Summary

### New Files
1. ✅ `SmartGlassesEndpointDiscovery.swift` (300 lines)
2. ✅ `SmartGlassesEndpointDiscoveryView.swift` (250 lines)
3. ✅ `ENDPOINT_DISCOVERY_GUIDE.md` (comprehensive guide)
4. ✅ `QUICK_TEST_STEPS.md` (quick reference)
5. ✅ `WIFI_PHOTO_TRANSFER_STATUS.md` (this file)

### Modified Files
1. ✅ `SmartGlassesSetupView.swift` (added discovery button & sheet)

### Files Needing Updates (After Discovery)
1. ⏳ `SmartGlassesTransferService.swift` (update endpoints)
2. ⏳ `SmartGlassesMediaTransferView.swift` (add thumbnail grid)

### Files To Create (After Discovery)
1. ⏳ `SmartGlassesMediaBrowserView.swift` (thumbnail browser)
2. ⏳ `SmartGlassesPhotoDetailView.swift` (full image viewer)

---

## 🚀 Call to Action

### Immediate Tasks (5 minutes)
1. ✅ Install updated code
2. ✅ Build and run app
3. 🔲 Connect glasses via Bluetooth
4. 🔲 Tap "Debug: Discover HTTP Endpoints"
5. 🔲 Wait for discovery to complete
6. 🔲 Export results
7. 🔲 Share results with dev team

### After Discovery (8-12 hours dev time)
1. Update SmartGlassesTransferService with discovered URLs
2. Implement thumbnail loading
3. Create media browser view
4. Add selective download
5. Test end-to-end workflow
6. Polish and release

---

## 📞 Support

If discovery fails or you need help interpreting results:
1. Export the full discovery report
2. Note any error messages
3. Check if glasses are still in WiFi mode
4. Share results for analysis

**The discovery tool will tell us exactly what we need to finish photo transfer! 🎉**
