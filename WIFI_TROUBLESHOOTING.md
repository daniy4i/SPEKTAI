# WiFi Connection Troubleshooting - "Unable to Join Network"

## 🔴 Error: "Unable to Join Network"

This error means iOS **cannot connect** to the glasses hotspot. This is usually NOT a code problem - it's a configuration or hardware issue.

---

## 🔍 Diagnosis Checklist

### **Step 1: Verify Glasses Hotspot is Actually Running**

**Try manual connection FIRST:**
1. Put glasses in transfer mode (app should do this)
2. iPhone Settings → WiFi
3. Look for glasses SSID in available networks
4. Tap to connect manually
5. Enter password manually

**Possible outcomes:**

✅ **Manual connection works** → Problem is with your code
❌ **Manual connection fails** → Problem is with glasses hotspot
⚠️ **SSID doesn't appear** → Glasses hotspot not starting

---

### **Step 2: Check Glasses Hotspot Status**

**Visual indicators:**
- Does glasses have LED that blinks when in hotspot mode?
- Does glasses make a sound/vibration when mode changes?
- How long after entering transfer mode does hotspot start?

**Common issues:**
- Hotspot takes 15-30 seconds to fully start
- Glasses battery too low (<20%)
- Glasses in wrong mode
- Previous WiFi session didn't close properly

**Fix:**
```
1. Restart glasses (power off/on)
2. Wait 30 seconds after entering transfer mode
3. Check if SSID appears in iPhone WiFi settings
```

---

### **Step 3: Verify SSID and Password**

**Check what the SDK returns:**

Add logging to see actual credentials:
```swift
guard let credentials = await service.openWiFiCredentials(for: .transfer) else {
    return
}

print("🔑 SSID: '\(credentials.ssid)'")
print("🔑 Password: '\(credentials.password)'")
print("🔑 SSID length: \(credentials.ssid.count)")
print("🔑 Password length: \(credentials.password.count)")
```

**Common issues:**
- SSID has invisible characters (spaces, special chars)
- Password is wrong
- Password has special characters that need escaping
- SSID changes each time hotspot starts

**Fix:**
```swift
// Trim whitespace
let cleanSSID = credentials.ssid.trimmingCharacters(in: .whitespacesAndNewlines)
let cleanPassword = credentials.password.trimmingCharacters(in: .whitespacesAndNewlines)
```

---

### **Step 4: Check iPhone WiFi Settings**

**Is iPhone's WiFi even on?**
- Settings → WiFi → ON (green)
- Not in Airplane Mode
- Not connected to another network that's "sticky"

**Are you connected to another network?**
- If connected to home/work WiFi, **disconnect first**
- iPhone won't switch networks automatically
- "Auto-Join" on home WiFi will fight you

**Fix:**
```
1. Settings → WiFi
2. Tap (i) next to current network
3. Toggle "Auto-Join" to OFF
4. Tap "Forget This Network"
5. Then try glasses hotspot
```

---

### **Step 5: Check Hotspot Type**

**WPA2 vs WPA3 vs WEP:**

Your code uses:
```swift
NEHotspotConfiguration(ssid: ssid, passphrase: passphrase, isWEP: false)
```

This assumes WPA2/WPA3. But what if glasses use:
- Open network (no password)?
- WEP encryption?
- WPA2-Enterprise?

**Test different configurations:**

```swift
// Try 1: WPA2 with password (current)
let config = NEHotspotConfiguration(ssid: ssid, passphrase: passphrase, isWEP: false)

// Try 2: Open network (no password)
let config = NEHotspotConfiguration(ssid: ssid)

// Try 3: WEP encryption
let config = NEHotspotConfiguration(ssid: ssid, passphrase: passphrase, isWEP: true)
```

**How to find out:**
1. iPhone Settings → WiFi
2. Tap (i) next to glasses network
3. Look at "Security" field
4. Should say "WPA2", "WEP", "None", etc.

---

### **Step 6: Check App Capabilities**

**Required capabilities:**

1. **Hotspot Configuration** ✅
   - Xcode → Target → Signing & Capabilities
   - Should see "Hotspot Configuration" capability
   - If missing: + Capability → Hotspot Configuration

2. **Access WiFi Information** (for NEHotspotNetwork)
   - This is optional but helpful
   - Allows reading current SSID

3. **Local Network** (iOS 14+)
   - Info.plist needs:
   ```xml
   <key>NSLocalNetworkUsageDescription</key>
   <string>Access local network to transfer photos from smart glasses</string>
   ```

---

### **Step 7: Check Error Code Details**

**Look for the actual error in logs:**

Add this logging:
```swift
NEHotspotConfigurationManager.shared.apply(configuration) { error in
    if let error = error {
        let nsError = error as NSError
        print("❌ Domain: \(nsError.domain)")
        print("❌ Code: \(nsError.code)")
        print("❌ Description: \(nsError.localizedDescription)")
        print("❌ UserInfo: \(nsError.userInfo)")
    }
}
```

**Common error codes:**
- Code 1: Invalid SSID
- Code 2: Invalid WPA password
- Code 3: Invalid WEP password
- Code 7: User denied
- Code 8: Internal error
- Code 13: Already associated

---

## 🛠️ Solutions by Error Type

### **Error: "Invalid WPA/WEP Passphrase"**

**Causes:**
- Wrong password
- SSID/password has special characters
- Password length wrong

**Fixes:**
1. Print the actual password: `print("Password: '\(password)'")`
2. Try connecting manually with that exact password
3. Check for invisible characters
4. Verify password length (WPA: 8-63 chars)

---

### **Error: "Invalid SSID"**

**Causes:**
- SSID has special characters
- SSID too long (>32 chars)
- SSID has emojis or Unicode
- SSID is empty or whitespace

**Fixes:**
1. Print actual SSID: `print("SSID: '\(ssid)' (length: \(ssid.count))")`
2. Check for non-ASCII characters
3. Trim whitespace: `ssid.trimmingCharacters(in: .whitespacesAndNewlines)`

---

### **Error: "User Denied"**

**Cause:**
- User tapped "Cancel" on iOS permission dialog

**Fix:**
- Show user a message explaining they need to approve
- Can't bypass this - it's a security feature

---

### **Error: "Internal Error"**

**Causes:**
- iOS WiFi subsystem confused
- Previous connection didn't clean up
- Timing issue

**Fixes:**
1. Restart iPhone WiFi (Settings → WiFi → Off → On)
2. Restart glasses
3. Increase delay after removeConfiguration
4. Enable Airplane Mode → wait 5s → disable

---

### **Error: "Already Associated" (Code 13)**

**This is actually SUCCESS!**

Your code now treats this as success, but if it's not working:

**Possible issue:**
- Weak/broken association from previous attempt
- Need to remove config and retry

**Fix:**
```swift
NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: ssid)
try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
// Then retry connection
```

---

## 🧪 Debugging Techniques

### **Technique 1: Simplify the Connection**

Remove all retry logic temporarily:

```swift
let config = NEHotspotConfiguration(ssid: ssid, passphrase: passphrase, isWEP: false)

NEHotspotConfigurationManager.shared.apply(config) { error in
    if let error = error {
        print("❌ FAILED: \(error)")
        print("❌ Code: \((error as NSError).code)")
    } else {
        print("✅ SUCCESS")
    }
}

// Wait and see what happens
try await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
```

---

### **Technique 2: Monitor System Logs**

Console.app can show more detailed iOS WiFi logs:

1. Open **Console.app** on Mac
2. Connect iPhone via cable
3. Select iPhone in sidebar
4. Filter for: `nehelper` OR `WiFi` OR `hotspot`
5. Try connection
6. Watch for errors

---

### **Technique 3: Compare with Manual Connection**

1. **Manually connect** via Settings → WiFi
2. Check Console.app logs - note what happens
3. **Then try programmatic** connection
4. Compare logs - see what's different

---

### **Technique 4: Test with Different Networks**

**Create a test hotspot:**
1. Use another iPhone as hotspot
2. Set simple SSID: "TestNetwork"
3. Set simple password: "12345678"
4. Try connecting to that with your code
5. If this works → problem is with glasses hotspot
6. If this fails → problem is with your code/permissions

---

## 📱 Common HeyCyan Glasses Issues

### **Issue 1: Hotspot Doesn't Start**

**Symptoms:**
- SSID never appears in WiFi list
- Connection times out
- No errors, just hangs

**Causes:**
- Glasses not in transfer mode
- Transfer mode command didn't work
- Glasses firmware bug

**Fix:**
```swift
// Add more delay after setting mode
await service.setDeviceMode(.transfer)
try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds (increase!)

// Verify mode changed
await service.refreshAdvancedStatus()
print("Current mode: \(service.advancedStatus.deviceMode)")
```

---

### **Issue 2: SSID Changes Every Time**

**Some hotspots generate dynamic SSIDs:**
- `HeyCyan_ABC123` (changes to `HeyCyan_DEF456`)
- Based on MAC address
- Random suffix

**Fix:**
```swift
// Check if SSID has pattern
if credentials.ssid.hasPrefix("HeyCyan") {
    print("✅ Glasses hotspot detected: \(credentials.ssid)")
} else {
    print("⚠️ Unexpected SSID: \(credentials.ssid)")
}
```

---

### **Issue 3: Password is Wrong**

**SDK might return incorrect password:**
- Fixed password: "12345678"
- Empty password (open network)
- Wrong password format

**Test:**
```swift
// Try common default passwords
let commonPasswords = ["12345678", "88888888", "00000000", "password"]

for testPassword in commonPasswords {
    print("Trying password: \(testPassword)")
    let config = NEHotspotConfiguration(ssid: ssid, passphrase: testPassword, isWEP: false)
    // Try connection...
}
```

---

## 🎯 Next Steps

### **Immediate Actions:**

1. **Test manual connection:**
   ```
   Settings → WiFi → [Glasses SSID] → Connect
   ```
   - ✅ Works? → Code issue
   - ❌ Fails? → Glasses issue

2. **Print credentials:**
   ```swift
   print("SSID: '\(credentials.ssid)'")
   print("Password: '\(credentials.password)'")
   ```

3. **Check error code:**
   ```swift
   print("Error code: \((error as NSError).code)")
   ```

4. **Try without password:**
   ```swift
   let config = NEHotspotConfiguration(ssid: ssid)
   ```

5. **Increase delays:**
   ```swift
   // After entering transfer mode
   try await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
   ```

---

### **Share These Logs:**

When asking for help, include:
1. Exact error message
2. Error code number
3. SSID and password (from logs)
4. Whether manual connection works
5. iOS version
6. Whether SSID appears in WiFi list

---

## 💡 Quick Fixes to Try

### **Fix 1: Increase Delays**
```swift
// After setDeviceMode
try await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds

// After openWiFiCredentials
try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds

// After removeConfiguration
try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
```

### **Fix 2: Try Open Network**
```swift
// Maybe glasses use open WiFi?
let config = NEHotspotConfiguration(ssid: ssid)
// No password parameter
```

### **Fix 3: Clean SSID/Password**
```swift
let cleanSSID = credentials.ssid
    .trimmingCharacters(in: .whitespacesAndNewlines)
    .replacingOccurrences(of: " ", with: "")

let cleanPassword = credentials.password
    .trimmingCharacters(in: .whitespacesAndNewlines)
```

### **Fix 4: Restart Everything**
```
1. Restart glasses
2. Forget all WiFi on iPhone
3. Restart iPhone
4. Try connection fresh
```

---

**The #1 most important test: Can you connect manually via Settings → WiFi?**

If manual connection fails → problem is NOT your code.
If manual connection works → problem IS your code or permissions.
