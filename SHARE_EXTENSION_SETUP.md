# Share Extension Setup Guide

This guide will help you add Share Extension functionality so users can add items from Safari, Amazon, or any app using the iOS share sheet.

## Files Created

Two new files have been created in the `ShareExtension/` folder:
- `ShareViewController.swift` - Extension entry point
- `ShareExtensionView.swift` - SwiftUI interface for adding shared items

## Xcode Setup Steps

### 1. Create Share Extension Target

1. In Xcode, select **File → New → Target**
2. Choose **iOS → Share Extension**
3. Configure the extension:
   - **Product Name**: `ShareExtension`
   - **Team**: Your development team
   - **Organization Identifier**: `com.designoverhaul`
   - **Bundle Identifier**: `com.designoverhaul.ChristmasWishlist.ShareExtension`
   - **Language**: Swift
   - **Include UI Extension**: NO (we're using SwiftUI)
4. Click **Finish**
5. When prompted "Activate 'ShareExtension' scheme?", click **Activate**

### 2. Add Files to ShareExtension Target

1. In Xcode, locate the files you created:
   - `ShareExtension/ShareViewController.swift`
   - `ShareExtension/ShareExtensionView.swift`
2. Select both files, open File Inspector (right panel)
3. Under **Target Membership**, check **ShareExtension**

### 3. Add Shared Files to ShareExtension Target

The Share Extension needs access to your models and design system. Add these existing files to the ShareExtension target:

**Select each file below and check ShareExtension in Target Membership:**
- `WishlistItem.swift`
- `Friend.swift`
- `User.swift`
- `DesignSystem.swift`
- `CustomComponents.swift`
- `HapticManager.swift`

### 4. Configure App Groups (for shared data)

#### A. Enable App Groups for Main App:
1. Select the **ChristmasWishlist** target
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **App Groups**
5. Click **+** and create: `group.com.designoverhaul.ChristmasWishlist`
6. Check the box to enable it

#### B. Enable App Groups for Share Extension:
1. Select the **ShareExtension** target
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **App Groups**
5. Click **+** and use the SAME group: `group.com.designoverhaul.ChristmasWishlist`
6. Check the box to enable it

### 5. Configure Share Extension Info.plist

1. Locate `ShareExtension/Info.plist` in the Project Navigator
2. Find the key **NSExtension → NSExtensionAttributes → NSExtensionActivationRule**
3. Replace it with the following:

```xml
<key>NSExtensionAttributes</key>
<dict>
    <key>NSExtensionActivationRule</key>
    <dict>
        <key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
        <integer>1</integer>
        <key>NSExtensionActivationSupportsWebPageWithMaxCount</key>
        <integer>1</integer>
        <key>NSExtensionActivationSupportsText</key>
        <true/>
        <key>NSExtensionActivationSupportsImageWithMaxCount</key>
        <integer>1</integer>
    </dict>
</dict>
```

This allows sharing URLs, web pages, text, and images.

### 6. Delete Xcode's Default Files

Xcode created some files we don't need:
1. Delete `ShareViewController.swift` from the ShareExtension folder (if different from the one we created)
2. Delete `MainInterface.storyboard` (we're using SwiftUI, not UIKit)
3. Delete `ShareExtension.entitlements` (capabilities will auto-generate this)

### 7. Update ShareExtension's Info.plist Principal Class

1. Open `ShareExtension/Info.plist`
2. Find **NSExtension → NSExtensionPrincipalClass**
3. Change value to: `$(PRODUCT_MODULE_NAME).ShareViewController`

## Testing the Share Extension

### 1. Build and Run the Extension

1. Select the **ShareExtension** scheme in Xcode
2. Choose a simulator or device
3. Click Run (Cmd+R)
4. Xcode will ask "Choose an app to run" - select **Safari**
5. Safari will open

### 2. Test Sharing

1. In Safari, navigate to any product page (e.g., Amazon, Apple Store)
2. Tap the **Share** button
3. Scroll down and tap **ChristmasWishlist** (you may need to tap "More" first)
4. The share extension will open showing:
   - Auto-detected item name from the page
   - The URL
   - Optional notes field
5. Tap **Add to Wishlist**
6. Close Safari and open the main ChristmasWishlist app
7. Your item should appear in My Wishlist!

## Troubleshooting

### "ChristmasWishlist" doesn't appear in share sheet
- Make sure App Groups are configured for BOTH targets
- Rebuild the ShareExtension target
- Delete app from device/simulator and reinstall

### Items not appearing in main app
- Verify both targets use the same App Group ID
- Check that SwiftData models are added to both targets
- Make sure the model container is configured to use the App Group

### Extension crashes on launch
- Verify all required files are in ShareExtension target membership
- Check that Info.plist is configured correctly
- Look at console logs for specific errors

## How It Works

1. **User shares content** from any app (Safari, Amazon, etc.)
2. **iOS shows share sheet** with ChristmasWishlist as an option
3. **Extension loads shared data**: URL, title, images
4. **User edits** item name and adds notes
5. **Item is saved** to shared SwiftData container
6. **Main app** has immediate access to the new item

## Future Enhancements

- Parse product metadata from common shopping sites
- Extract price information
- Better image handling and caching
- Support for multiple item selection
