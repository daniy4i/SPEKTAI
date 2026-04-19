# Multi-Platform Architecture

## 🏗️ **Project Structure**

```
lannaapp/
├── Shared/                    # Shared across ALL platforms
│   ├── Models/               # Project, User, etc.
│   ├── Services/             # Firebase, Auth, ProjectService
│   ├── DesignSystem/         # Colors, Typography, Spacing
│   └── Views/                # Platform-agnostic wrappers
├── iOS/                      # iOS-specific views
├── iPadOS/                   # iPad-specific views  
├── macOS/                    # macOS-specific views
└── watchOS/                  # watchOS-specific views
```

## 🔄 **How It Works**

### **1. Platform-Agnostic Wrappers**
```swift
// Shared/Views/AccountSettingsView.swift
struct AccountSettingsView: View {
    var body: some View {
        #if os(macOS)
        AccountSettingsView_macOS()
        #elseif os(iOS)
        AccountSettingsView_iOS()
        #else
        Text("Platform not supported")
        #endif
    }
}
```

### **2. Platform-Specific Implementations**
- **macOS**: Uses `.bordered` buttons, fixed window sizes, no navigation bars
- **iOS**: Uses `NavigationView`, `navigationBarTitleDisplayMode`, iOS-style toolbars
- **iPadOS**: Can have unique layouts for larger screens
- **watchOS**: Optimized for small screens with `WKHostingController`

## ✅ **Benefits**

1. **No More Platform Conflicts**: Each platform has its own view files
2. **Shared Backend Logic**: Models, Services, and Design System are shared
3. **Platform Optimization**: Each view can be optimized for its platform
4. **Easy Maintenance**: Change iOS without affecting macOS
5. **Clear Separation**: Know exactly where platform-specific code lives

## 🎯 **Usage Examples**

### **Creating a New View**

1. **Create platform-specific views:**
   ```swift
   // iOS/MyView_iOS.swift
   struct MyView_iOS: View { ... }
   
   // macOS/MyView_macOS.swift  
   struct MyView_macOS: View { ... }
   ```

2. **Create platform-agnostic wrapper:**
   ```swift
   // Shared/Views/MyView.swift
   struct MyView: View {
       var body: some View {
           #if os(macOS)
           MyView_macOS()
           #elseif os(iOS)
           MyView_iOS()
           #endif
       }
   }
   ```

3. **Use the wrapper everywhere:**
   ```swift
   MyView() // Automatically chooses right platform
   ```

## 🚫 **What NOT to Do**

- ❌ **Don't** put platform-specific code in shared files
- ❌ **Don't** use `#if os()` in shared models/services
- ❌ **Don't** mix iOS and macOS APIs in the same view
- ❌ **Don't** create one view that tries to work on all platforms

## ✅ **What TO Do**

- ✅ **Do** create separate view files for each platform
- ✅ **Do** share models, services, and design tokens
- ✅ **Do** use platform-agnostic wrappers
- ✅ **Do** optimize each platform's UX independently
- ✅ **Do** test each platform separately

## 🔧 **Current Implementation**

- **AccountSettingsView**: ✅ Platform-specific (iOS/macOS)
- **EditProjectView**: ✅ Platform-specific (iOS/macOS)
- **ProjectsListView**: 🔄 Needs platform-specific versions
- **Design System**: ✅ Consolidated in Shared/DesignSystem/

## 📱 **Next Steps**

1. **Create platform-specific ProjectsListView versions**
2. **Add iPadOS-specific layouts for larger screens**
3. **Create watchOS versions of key views**
4. **Add platform-specific navigation patterns**

This architecture gives you the best of both worlds: shared logic with platform-optimized experiences! 🎉
