# HeyCyan Smart Glasses - HTTP Endpoint Discovery Guide

## Overview
This guide explains how to use the new endpoint discovery tool to find working HTTP endpoints on your HeyCyan smart glasses.

## What This Tool Does

The endpoint discovery tool will:
1. ✅ Enable WiFi hotspot on your glasses
2. ✅ Test multiple IP addresses to find the working one
3. ✅ Test 50+ common HTTP endpoints
4. ✅ Try different file naming patterns
5. ✅ Show response data and content types
6. ✅ Export results for analysis

## Step-by-Step Instructions

### 1. Prerequisites
- HeyCyan smart glasses fully charged (>20% battery)
- Glasses connected via Bluetooth to your iPhone
- Disconnect from other WiFi networks (recommended)

### 2. Launch the Discovery Tool

1. Open Lanna app
2. Go to **Smart Glasses Setup/Dashboard**
3. Scroll down to the WiFi section
4. Tap **"Debug: Discover HTTP Endpoints"** (orange button)

### 3. Prepare WiFi Connection

1. The tool will automatically:
   - Set glasses to transfer mode
   - Enable WiFi hotspot
   - Connect your iPhone to the glasses hotspot

2. Wait for **"Connected"** status (~15-20 seconds)
3. Tap **"Start Scanning Endpoints"**

### 4. Wait for Discovery to Complete

The tool will test:
- 6 common IP addresses (192.168.31.1, 192.168.1.1, etc.)
- 40+ endpoint patterns for file listing
- Photo, video, audio, and thumbnail endpoints
- Different HTTP methods (GET, POST)
- File naming patterns (IMG_0001.jpg, PHOTO_0001.jpg, etc.)

**Expected duration:** 2-3 minutes

### 5. Review Results

#### Working Endpoints (Green ✅)
These endpoints returned HTTP 200-299 status codes and contain data.

**Pay special attention to:**
- `/files/list` - File listing endpoint
- `/media/list` - Alternative listing endpoint
- `/thumbnails/*` - Thumbnail access patterns
- `/files/*.jpg` - Direct file access patterns

#### Failed Endpoints (Red ❌)
These returned errors or 404s. Collapsed by default.

### 6. Examine Endpoint Details

Tap on any **working endpoint** to expand and see:
- **Status Code:** HTTP response code
- **Content-Type:** MIME type (json, image/jpeg, text/html, etc.)
- **Size:** Response data size in bytes
- **Response Preview:** First 500 characters of response

**Key indicators:**
- `application/json` → File listing or API endpoint
- `image/jpeg` → Direct image download
- `text/html` → HTML directory listing
- `text/plain` → Plain text file list

### 7. Export Results

1. Tap **"Export"** in the top-right corner
2. Tap **"Copy"** to copy to clipboard
3. Paste into Notes app or send to yourself
4. Share results with developer

## What to Look For

### File Listing Endpoints

```
✅ http://192.168.31.1/files/list
   HTTP 200 | application/json | 1234 bytes
   Response: {"files": [{"name": "IMG_0001.jpg", "size": 2048000}]}
```

**Action:** This is the file listing endpoint! Note the JSON structure.

### Direct File Access

```
✅ http://192.168.31.1/files/IMG_0001.jpg
   HTTP 200 | image/jpeg | 2048000 bytes
```

**Action:** Files can be downloaded directly using `/files/{filename}`

### Thumbnail Access

```
✅ http://192.168.31.1/thumbnails/0.jpg
   HTTP 200 | image/jpeg | 15000 bytes
```

**Action:** Thumbnails accessible using index numbers!

### Directory Listing

```
✅ http://192.168.31.1/files/
   HTTP 200 | text/html | 5000 bytes
   Response: <!DOCTYPE html><html>...
```

**Action:** HTML directory listing - can be parsed for filenames

## Common Patterns Found in Chinese Smart Glasses

Based on similar devices, expect one of these patterns:

### Pattern A: RESTful API
```
GET /api/files           → List all files
GET /api/files/{id}      → Download specific file
GET /api/thumbnails/{id} → Get thumbnail
```

### Pattern B: Simple Web Server
```
GET /files/              → HTML directory listing
GET /files/IMG_0001.jpg  → Direct file download
GET /thumb/IMG_0001.jpg  → Thumbnail
```

### Pattern C: Index-Based Access
```
GET /media/list          → JSON: [{"index": 0, "name": "..."}]
GET /media/0             → Download file at index 0
GET /thumbnails/0        → Thumbnail for file 0
```

### Pattern D: Legacy CGI Style
```
GET /cgi-bin/list.cgi    → File listing
GET /download?file=IMG_0001.jpg → Download
```

## Troubleshooting

### "Could not find working IP address"

**Solutions:**
1. Make sure glasses are in transfer mode
2. Wait longer (30+ seconds) for hotspot to stabilize
3. Check glasses WiFi is actually on (LED indicator)
4. Try manually connecting to glasses WiFi in Settings first

### "All endpoints failed"

**Solutions:**
1. Verify you're connected to glasses hotspot in Settings → WiFi
2. Check if hotspot password is correct
3. Glasses might use non-standard port (not 80)
4. Try refreshing WiFi credentials
5. Restart glasses

### "Connected but no working endpoints"

**Possible causes:**
1. Web server not started yet (wait longer)
2. Firewall blocking requests
3. Server on different port (try :8080, :8000, :3000)
4. Authentication required (check for 401 errors)

## Next Steps After Discovery

Once you find working endpoints:

### 1. Update SmartGlassesTransferService.swift

Replace `fetchDeviceMediaList()` function with discovered endpoints:

```swift
private func fetchDeviceMediaList(ipAddress: String?) async throws -> [DeviceMediaFile] {
    guard let ipAddress else {
        throw SmartGlassesTransferError.mediaListUnavailable
    }

    // Use discovered endpoint
    guard let listURL = URL(string: "http://\(ipAddress)/files/list") else {
        throw SmartGlassesTransferError.mediaListUnavailable
    }

    let (data, response) = try await URLSession.shared.data(from: listURL)
    // Parse JSON based on discovered structure...
}
```

### 2. Implement Thumbnail Loading

```swift
func loadThumbnail(for file: DeviceMediaFile, ipAddress: String) async -> UIImage? {
    // Use discovered thumbnail endpoint pattern
    guard let url = URL(string: "http://\(ipAddress)/thumbnails/\(file.name)") else {
        return nil
    }

    let (data, _) = try await URLSession.shared.data(from: url)
    return UIImage(data: data)
}
```

### 3. Update Download Logic

```swift
private func downloadFile(_ file: DeviceMediaFile) async throws -> URL {
    // Use discovered download endpoint
    let downloadURL = URL(string: "http://\(ipAddress)/files/\(file.name)")!
    let (data, _) = try await URLSession.shared.data(from: downloadURL)
    // Save to disk...
}
```

## Expected Results

### Successful Discovery Output:
```
Working Endpoints (8):
✅ http://192.168.31.1/files/media.config
✅ http://192.168.31.1/files/list
✅ http://192.168.31.1/files/IMG_0001.jpg
✅ http://192.168.31.1/files/IMG_0002.jpg
✅ http://192.168.31.1/thumbnails/0.jpg
✅ http://192.168.31.1/thumbnails/1.jpg
✅ http://192.168.31.1/media/list
✅ http://192.168.31.1/
```

### File List Response Examples:

**JSON format:**
```json
{
  "files": [
    {
      "name": "IMG_0001.jpg",
      "size": 2048000,
      "type": "image",
      "created": "2025-09-30T12:00:00Z"
    }
  ]
}
```

**Plain text format:**
```
IMG_0001.jpg 2048000 2025-09-30T12:00:00Z
IMG_0002.jpg 1856000 2025-09-30T12:05:00Z
VID_0001.mp4 15728640 2025-09-30T12:10:00Z
```

**HTML format:**
```html
<a href="/files/IMG_0001.jpg">IMG_0001.jpg</a> (2.0 MB)
<a href="/files/IMG_0002.jpg">IMG_0002.jpg</a> (1.8 MB)
```

## Tips for Best Results

1. **Stable Connection:** Keep iPhone near glasses during discovery
2. **Battery:** Ensure glasses have >30% battery
3. **No Interruptions:** Don't take photos or record during discovery
4. **Retry:** If first attempt fails, reset and try again
5. **Document Everything:** Export and save all successful results

## Contact & Support

After running discovery:
1. Export results
2. Note which endpoints worked
3. Share with development team
4. We'll update the transfer service with the correct URLs

## Technical Notes

### HTTP Headers Sent
```
User-Agent: lannaapp/1.0
Accept: */*
Connection: keep-alive
```

### Timeout Settings
- Initial connection: 5 seconds
- Data transfer: 10 seconds
- Between requests: 0.2 seconds (to avoid overwhelming device)

### IP Address Priority
1. SDK-reported IP (from `getDeviceWifiIPSuccess`)
2. 192.168.31.1 (most common for this device)
3. Other common gateway IPs

### Retry Logic
- Config endpoint: 3 attempts with exponential backoff
- List endpoint: 2 attempts
- Individual files: Single attempt per pattern

## Example Session

```
🔍 Starting endpoint discovery...
✅ Found working IP: 192.168.31.1
📊 Testing 40 endpoints...

Testing 1/40: /files/list
✅ Working endpoint: http://192.168.31.1/files/list
   Status: 200 | Type: application/json | Size: 2.1 KB

Testing 2/40: /files/media.config
✅ Working endpoint: http://192.168.31.1/files/media.config
   Status: 200 | Type: text/plain | Size: 156 bytes

Testing 3/40: /files
❌ Failed: HTTP 403 Forbidden

...

Testing 28/40: /thumbnails/0.jpg
✅ Working endpoint: http://192.168.31.1/thumbnails/0.jpg
   Status: 200 | Type: image/jpeg | Size: 14.2 KB

✅ Discovery complete! Found 8 working endpoints
```

---

**Good luck with the discovery! This tool should reveal exactly how the glasses' HTTP server is structured.**
