# Quick Test Steps - WiFi Endpoint Discovery

## 🚀 Fast Track (5 minutes)

### 1. Prepare Glasses
```
✓ Glasses charged >20%
✓ Connected via Bluetooth
✓ Disconnect from home WiFi
```

### 2. Run Discovery
```
1. Open Lanna app
2. Tap "Smart Glasses" setup
3. Scroll to WiFi section
4. Tap "Debug: Discover HTTP Endpoints" (orange)
5. Wait for WiFi connection (~20 sec)
6. Tap "Start Scanning Endpoints"
7. Wait for completion (~2-3 min)
```

### 3. Check Results
```
Look for these successful endpoints:
✅ /files/list          → FILE LISTING (most important!)
✅ /media/list          → Alternative listing
✅ /files/*.jpg         → Direct file download
✅ /thumbnails/*.jpg    → Thumbnail access
✅ /                    → Root directory
```

### 4. Export & Share
```
1. Tap "Export" (top right)
2. Tap "Copy"
3. Paste in Notes
4. Share with team
```

## 🎯 What Success Looks Like

### Best Case Scenario
```
✅ http://192.168.31.1/files/list
   HTTP 200 | application/json | 1.2 KB
   {"files": [{"name": "IMG_0001.jpg", ...}]}

✅ http://192.168.31.1/files/IMG_0001.jpg
   HTTP 200 | image/jpeg | 2 MB

✅ http://192.168.31.1/thumbnails/0.jpg
   HTTP 200 | image/jpeg | 15 KB
```

**This means:** We can list files, download photos, and get thumbnails! 🎉

### Partial Success
```
✅ http://192.168.31.1/
   HTTP 200 | text/html | 5 KB
   <html>...<a href="IMG_0001.jpg">...</html>

❌ /files/list
   HTTP 404
```

**This means:** We need to parse HTML directory listing (still works, just more complex)

### Failure
```
❌ All endpoints failed
```

**This means:**
- Hotspot not working
- Wrong IP address
- Server not running
- Try again with longer waits

## 📋 Checklist

Before starting:
- [ ] Glasses Bluetooth connected
- [ ] Glasses battery >20%
- [ ] iPhone disconnected from other WiFi
- [ ] Glasses in normal mode (not recording)

During discovery:
- [ ] WiFi hotspot enabled successfully
- [ ] iPhone connected to glasses hotspot
- [ ] Discovery shows progress messages
- [ ] At least 1 green checkmark appears

After completion:
- [ ] Found working IP address
- [ ] Found file listing endpoint
- [ ] Found file download pattern
- [ ] Exported results
- [ ] Results copied to Notes

## ⚠️ Troubleshooting Fast Fixes

**Problem:** "Could not find working IP"
**Fix:** Wait 30 seconds, try again

**Problem:** "All endpoints failed"
**Fix:** Check WiFi settings, manually verify connected to glasses

**Problem:** "Only root endpoint works"
**Fix:** Look at HTML response, parse directory listing

**Problem:** Tool crashes
**Fix:** Restart app, forget device, reconnect

## 📸 Taking Test Photos

For best results, take 2-3 test photos first:
```
1. Connect glasses
2. Press photo button on glasses
3. Wait for confirmation
4. Verify photo count increased (check dashboard)
5. THEN run discovery
```

This ensures there's media to list!

## 🔍 Manual Verification (if tool fails)

Use Safari on your iPhone:
```
1. Connect to glasses hotspot manually (Settings → WiFi)
2. Open Safari
3. Type: http://192.168.31.1
4. Try these URLs manually:
   - http://192.168.31.1/files/list
   - http://192.168.31.1/files/
   - http://192.168.31.1/media
   - http://192.168.31.1/
5. Screenshot any working URLs
```

## 📊 Expected Timeline

| Step | Time | Notes |
|------|------|-------|
| Enable hotspot | 15-20s | Glasses LED should blink |
| Connect iPhone | 5-10s | Check WiFi settings |
| Test IP addresses | 10-15s | 6 IPs x 2s each |
| Test endpoints | 90-120s | 40+ endpoints |
| File patterns | 30-45s | Numbered files |
| **Total** | **2-3 min** | If connection is stable |

## ✅ Success Criteria

**Minimum viable result:**
- Found working IP address
- At least 1 working endpoint
- Response data captured

**Ideal result:**
- File listing endpoint found
- Direct download pattern identified
- Thumbnail access working
- JSON structure documented

## 📤 What to Share

When sending results to team:
```
1. Export full report (copy/paste)
2. Note which IP worked
3. Highlight most important endpoints:
   - File listing URL
   - File download pattern
   - Thumbnail pattern
4. Include any JSON response examples
5. Note any error patterns
```

## 🎉 Next Steps After Success

We'll update these files with your discovered endpoints:
- `SmartGlassesTransferService.swift` - Main transfer logic
- `SmartGlassesMediaTransferView.swift` - UI for file browsing
- Add thumbnail grid view
- Add selective download

**You'll then be able to:**
- Browse photos on glasses
- See thumbnail previews
- Download selected photos
- View full resolution images
- Save to iPhone camera roll

---

**Good luck! The discovery tool will do all the hard work - just follow these steps and share the results! 🚀**
