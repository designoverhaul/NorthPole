# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ChristmasWishlist is a native iOS SwiftUI application targeting iOS 26.1. This is a standard Xcode project (not using Swift Package Manager workspace) with unit and UI test targets.

**Bundle Identifier**: com.designoverhaul.ChristmasWishlist

## Build Commands

### Building the App
```bash
# Clean build folder (always do this before building after AI changes)
xcodebuild clean -project ChristmasWishlist.xcodeproj -scheme ChristmasWishlist

# Build for simulator
xcodebuild build -project ChristmasWishlist.xcodeproj -scheme ChristmasWishlist -destination 'platform=iOS Simulator,name=iPhone 16'

# Build for device (requires signing)
xcodebuild build -project ChristmasWishlist.xcodeproj -scheme ChristmasWishlist -destination 'generic/platform=iOS'
```

### Running Tests
```bash
# Run all unit tests
xcodebuild test -project ChristmasWishlist.xcodeproj -scheme ChristmasWishlist -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ChristmasWishlistTests

# Run all UI tests
xcodebuild test -project ChristmasWishlist.xcodeproj -scheme ChristmasWishlist -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ChristmasWishlistUITests

# Run specific test
xcodebuild test -project ChristmasWishlist.xcodeproj -scheme ChristmasWishlist -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ChristmasWishlistTests/ChristmasWishlistTests/testExample
```

## Architecture

### Project Structure
- **ChristmasWishlist/**: Main application code
  - **App Entry**: `ChristmasWishlistApp.swift` - SwiftUI `@main` with SwiftData model container
  - **Data Models**: `WishlistItem.swift`, `Friend.swift`, `User.swift` - SwiftData models
  - **Design System**: `DesignSystem.swift` - Warm minimalist color palette (cream/gold/forest green)
  - **Components**: `CustomComponents.swift` - Reusable buttons, cards, rows
  - **Effects**: `SparkleEffect.swift` - Festive particle animations
  - **Utilities**: `HapticManager.swift` - Haptic feedback, `DemoDataGenerator.swift` - Test data
  - **Views**:
    - `MainTabView.swift`: Tab navigation (My Wishlist, Friends, Settings)
    - `MyWishlistView.swift`: User's wishlist with add/delete
    - `AddGiftView.swift`: Modal sheet for adding items
    - `FriendsListView.swift`: Friends list with Contacts integration
    - `FriendWishlistView.swift`: View/purchase friend's items
    - `SettingsView.swift`: Settings and about pages

### Data Layer
- **SwiftData** for local persistence
- Models: `WishlistItem`, `Friend`, `User`
- Currently local-first (no backend sync)
- Future: CloudKit or Firebase for multi-user sync

### Design System
- **Colors**: Cream backgrounds (#FAF7F2), gold accents (#D4AF37), forest green (#2D5016)
- **Typography**: Rounded system font with custom scales
- **Effects**: Sparkle particles, smooth spring animations, haptic feedback
- **Components**: Custom button styles, floating action buttons, card containers

### Key Features
1. **My Wishlist**: Add/delete items (name, URL, description)
2. **Friends**: Add from Contacts, view their wishlists
3. **Purchase Tracking**: Mark items as bought, prevent duplicates
4. **Permissions**: Full Contacts access for friend discovery

## Critical Development Rules

### File Management with AI
**NEVER modify .pbxproj files directly.** When creating new Swift files:
1. Use Claude Code to create the .swift file
2. Manually add it to the Xcode project via Xcode UI
3. Modifying .pbxproj with AI will corrupt the project and waste hours

### iOS 26.1 Specific Considerations
- Deployment target is iOS 26.1, which is cutting edge
- Document any iOS 26 API edge cases discovered in this file
- Example patterns: "NO .background() before .glassEffect()" - add these as discovered

### SwiftUI Development Patterns
- App uses SwiftUI lifecycle (`@main` struct conforming to `App`)
- Use `#Preview` macro for SwiftUI previews (not `PreviewProvider`)
- Keep views in separate files as the app grows

### Testing After Changes
Always follow this workflow:
1. Clean build folder: Cmd+Shift+K in Xcode or `xcodebuild clean`
2. Build and run on device or simulator
3. Check Xcode console for errors/warnings
4. Verify functionality works as expected

## Common Development Tasks

### Adding Demo Data for Testing
Use `DemoDataGenerator` in any view:
```swift
Button("Load Demo Data") {
    DemoDataGenerator.generateDemoData(in: modelContext)
}
```

### Adding New Colors
Add to `DesignSystem.swift:12-30` color extension

### Creating New Components
Add to `CustomComponents.swift` following existing patterns

### Modifying Data Models
1. Update the `@Model` class in respective file
2. May need to delete app and reinstall if schema changes significantly
3. Consider migration strategy for production

### Adding Haptic Feedback
Use `HapticManager` methods:
- `HapticManager.itemAdded()` - Success feedback
- `HapticManager.buttonTapped()` - Light tap
- `HapticManager.errorOccurred()` - Error feedback

### Info.plist Required Entries
**NSContactsUsageDescription**: "We need access to your contacts to help you add friends to your wishlist"

## Known Issues & Workarounds

### Contacts Integration
- Friend's `hasApp` status is currently randomized (local-first mode)
- Need backend to check if contact phone/email matches registered user

### Purchase Tracking
- Currently only prevents same user from purchasing twice
- Need to show who purchased each item (privacy consideration)

### Data Sync
- All data is local-only using SwiftData
- No cross-device sync implemented yet
- Future: Add CloudKit for iCloud sync or Firebase for cross-platform
