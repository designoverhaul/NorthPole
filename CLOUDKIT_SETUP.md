# CloudKit Migration Guide

## 🎯 What This Solves

Moving to CloudKit fixes the share extension sandboxing issues AND enables real features:
- ✅ **Share Extension Works** - CloudKit has proper permissions
- ✅ **Real Friend Sharing** - Friends can see your list in real-time
- ✅ **iCloud Sync** - Works across all your devices
- ✅ **Built-in Authentication** - Uses Apple ID automatically

## 📋 Setup Steps (Do These in Xcode)

### Step 1: Enable CloudKit for Main App

1. **Select ChristmasWishlist target** in Project Navigator
2. **Go to Signing & Capabilities** tab
3. **Click + Capability**
4. **Add "iCloud"**
5. **Check "CloudKit"** checkbox
6. **Click +** under "Containers"
7. **Select "Create New Container"**
8. **Name it**: `iCloud.com.designoverhaul.ChristmasWishlist`
9. **Click OK**

### Step 2: Enable CloudKit for Share Extension

1. **Select GiftProduct target**
2. **Go to Signing & Capabilities** tab
3. **Click + Capability**
4. **Add "iCloud"**
5. **Check "CloudKit"** checkbox
6. **Click +** under "Containers"
7. **Select EXISTING container**: `iCloud.com.designoverhaul.ChristmasWishlist`
   - **IMPORTANT**: Use the SAME container as main app!

### Step 3: Add CloudKit Files to Targets

**Add to ChristmasWishlist target:**
- ✅ `CloudKitManager.swift`
- ✅ `CloudKitModels.swift`
- ✅ `CloudKitWishlistView.swift`
- ✅ `CloudKitAddGiftView.swift`

**Add to GiftProduct target:**
- ✅ `CloudKitManager.swift` (same file, both targets)
- ✅ `CloudKitModels.swift` (same file, both targets)
- ✅ `CloudKitShareExtensionView.swift`
- ✅ `DesignSystem.swift` (already should be there)
- ✅ `CustomComponents.swift` (already should be there)
- ✅ `HapticManager.swift` (already should be there)

**How to add files to target:**
1. Click on the file in Project Navigator
2. Open File Inspector (right panel)
3. Under "Target Membership", check the target checkbox

### Step 4: Update App Entry Point

Edit `ChristmasWishlistApp.swift` to use CloudKit view:

```swift
import SwiftUI

@main
struct ChristmasWishlistApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.light)
        }
    }
}
```

Then update `MainTabView.swift` to use `CloudKitWishlistView`:

```swift
TabView(selection: $selectedTab) {
    CloudKitWishlistView()  // Changed from MyWishlistView
        .tabItem {
            Label("My Wishlist", systemImage: "gift")
        }
        .tag(0)

    // ... rest stays the same
}
```

### Step 5: Clean & Build

1. **Delete the app** from device/simulator (fresh start for CloudKit)
2. **Clean Build Folder**: Cmd+Shift+K
3. **Build**: Cmd+B
4. **Fix any errors** (let me know if you get stuck!)

## 🧪 Testing the Share Extension

1. **Run the app** (ChristmasWishlist scheme)
2. **Sign in to iCloud** if prompted
3. **Add a test item** in the app to verify CloudKit works
4. **Open Safari** or Amazon app
5. **Find a product** page
6. **Tap Share** → **ChristmasWishlist**
7. **It should open and work!** 🎉

## 🔍 Troubleshooting

### "Not signed in to iCloud"
- Go to Settings → [Your Name] → iCloud
- Make sure you're signed in
- iCloud Drive should be enabled

### Share Extension Still Crashes
- Make sure CloudKitManager.swift is added to **both** targets
- Make sure **same CloudKit container** in both targets
- Check Console for "☁️" logs to see where it's failing

### Items Not Syncing
- Check iCloud status with Settings → [Your Name] → iCloud
- Try deleting and reinstalling the app
- Check Console for CloudKit errors

## 📊 CloudKit Dashboard

To view/manage your data:
1. Go to https://icloud.developer.apple.com/
2. Sign in with your Apple ID
3. Select your CloudKit container
4. View records, schema, etc.

## 🎁 What's Different from SwiftData

**Old (SwiftData):**
- Local database only
- Share extension couldn't access it (sandboxing)
- No friend sharing

**New (CloudKit):**
- iCloud database
- Share extension has full access
- Real-time sync
- Future: Friend discovery and sharing

## 📝 CloudKit Record Types

The following record types are created automatically:

### WishlistItem
- `name` (String)
- `url` (String)
- `itemDescription` (String)
- `isPurchased` (Bool)
- `createdAt` (Date)
- `ownerID` (String) - references user
- `image` (Asset) - optional photo

### Friend
- `name` (String)
- `phoneNumber` (String)
- `email` (String)
- `ownerID` (String)
- `addedAt` (Date)
- `photo` (Asset)

### User
- `name` (String)

## 🚀 Next Steps After CloudKit Works

1. **Friend Discovery** - Match friends by Apple ID/phone
2. **Public Wishlists** - Friends can view your items
3. **Purchase Tracking** - Mark items as purchased
4. **Push Notifications** - When someone buys your gift
5. **Collaborative Lists** - Family wishlists

---

**Ready to test?** Complete Steps 1-5 above and let me know how it goes! 🎄✨
