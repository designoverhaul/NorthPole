# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ChristmasWishlist is a native iOS SwiftUI application targeting iOS 26.1. This is a standard Xcode project (not using Swift Package Manager workspace) with unit and UI test targets.

**Bundle Identifier**: com.designoverhaul.ChristmasWishlist

### How the App Actually Works

**Primary Use Case:**
Users create their own wishlist items that are saved locally on their phone. These items include name, URL, description, and other gift details.

**Child Account Feature:**
Users can create what functions like a "child account" where they can manage and create wishlist items on behalf of their child. This allows parents to:
- Create separate wishlists for their children
- Manage their children's gift requests
- Keep track of what children want without the child needing their own device/account
- **Important**: Child accounts are permanently attached to the parent's phone number - they cannot be separated or transferred

**Data Storage & Sync Architecture:**

The app uses a **local-first architecture** where the user's phone is the ultimate source of truth:

1. **Local Storage (Primary)**: All wishlist items (user's own items and child account items) are stored locally on the device using SwiftData
2. **Cloud Sync (Secondary)**: When a user adds a wishlist item, the app should:
   - **First**: Save the item locally to SwiftData (this is the source of truth)
   - **Then**: Push the item to the cloud so other users can see it
3. **Pulling Updates**: Other users pull wishlist items from the cloud to view what someone wants
4. **Child Accounts**: Child account wishlists follow the same pattern - saved locally first, then synced to cloud
5. **Purchase Tracking**: When a user marks an item as purchased from another user's wishlist:
   - **First**: Save the purchase status locally to SwiftData
   - **Then**: Push the purchase status to the cloud so the item owner and other users can see it's been claimed
6. **Background Sync for Instant UI**: When a user opens the app to view wishlists:
   - **Display immediately**: Show data from local SwiftData with ZERO delay
   - **Background refresh**: Silently check cloud for updates in the background
   - **Seamless updates**: Apply any new changes from cloud without disrupting the view
   - **No loading spinners**: User should never see loading states when opening wishlists

**User Identity & Lookup:**
- **Phone number is the source of truth** for user identity, NOT name
- When adding friends or pulling wishlist data, always use phone number as the unique identifier
- **Phone number normalization is critical**: Different formats must resolve to same user
  - Example: `(205)-292-9663`, `2052929663`, `205-292-9663` should ALL return the same user (John)
  - Strip all formatting (parentheses, dashes, spaces) and match on digits only
  - Store normalized phone numbers in the database
- Names can change, but phone numbers are the permanent identifier
- Child accounts are permanently attached to parent's phone number

**Key Principles**:
- The local database on the user's device is always authoritative
- Cloud is for sharing/syncing, not the primary data store
- UI must be instant - never wait for network requests
- Sync happens silently in the background without blocking the UI
- Phone numbers are the source of truth for user identity

**Current State**: Migrating from CloudKit to Firebase. Firebase implementation in progress (December 2024).

## Quick Reference

### Before Every AI Session
1. Clean build folder (Cmd+Shift+K)
2. Pull latest changes
3. Review recent commits to understand context

### After Every AI Change
1. Clean build folder (Cmd+Shift+K)
2. Build and run on device/simulator
3. Check Xcode console for errors
4. Test the specific functionality changed
5. Commit with descriptive message

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
- **SwiftData** for local persistence (source of truth)
- **Firebase** for cloud sync and multi-user sharing
- Models: `WishlistItem`, `Friend`, `User`, `Child`
- **Architecture**: Local-first with Firebase sync
  - User's phone is always the source of truth
  - When adding items: Save locally first, then push to Firebase
  - When viewing wishlists: Display local data immediately, sync in background
  - Other users pull from Firebase to see wishlists
  - Same pattern for both user items and child account items
- **Performance**: Zero-delay UI - always show local data first, update silently from cloud
- **Firebase Services**:
  - **Firestore**: NoSQL database for wishlist items, children, friends, purchases
  - **Firebase Auth**: Phone number authentication (SMS verification)
  - **Firebase Storage**: Image uploads for wishlist items
  - **Cloud Functions**: Push notifications via Firebase Cloud Messaging (FCM)
- **Current State**: Migrating from CloudKit to Firebase (December 2024)

### Firebase Architecture

**Firestore Collections:**
```
users/{phoneNumber}          - User accounts and settings
wishlistItems/{itemId}       - All wishlist items
children/{childId}           - Child accounts
purchases/{purchaseId}       - Purchase tracking
friends/{friendshipId}       - Friend relationships
```

**Phone Number Normalization:**
- Strip all formatting: `(205)-292-9663` → `2052929663`
- Use normalized phone as Firestore document ID
- For Firebase Auth, use E.164 format: `+12052929663`

**Firebase Managers:**
- `FirebaseManager.swift` - Main coordinator (replaces CloudKitManager)
- `FirebaseAuthManager.swift` - Phone authentication handling
- `FirebaseStorageManager.swift` - Image upload/download
- `FirebaseModels.swift` - Helper structs for Firestore data

**Security Rules:**
- Authenticated users can read most data
- Only owners can modify their own data
- Phone number verification via Firebase Auth

### Design System
- **Colors**: Cream backgrounds (#FAF7F2), gold accents (#D4AF37), forest green (#2D5016)
- **Typography**: Rounded system font with custom scales
- **Effects**: Sparkle particles, smooth spring animations, haptic feedback
- **Components**: Custom button styles, floating action buttons, card containers

### Key Features
1. **My Wishlist**: Add/delete items (name, URL, description)
2. **Friends**: Add from Contacts, view their wishlists
   - **Identity**: Phone number is source of truth, NOT name
   - **Normalization**: Strip formatting from phone numbers for matching
3. **Purchase Tracking**: Mark items as bought, prevent duplicates
4. **Permissions**: Full Contacts access for friend discovery
5. **Child Accounts**: Permanently attached to parent's phone number

## Critical Development Rules

### 1. NEVER Modify .pbxproj Files
**This is the most important rule.** AI modification of .pbxproj files WILL corrupt your project.

When creating new Swift files:
1. Use Claude Code to create the .swift file
2. Manually add it to the Xcode project via Xcode UI (File > Add Files)
3. One corrupted project file = hours wasted

### 2. Always Request Debug Logging
For complex flows, ask Claude Code to add Logger statements:
```swift
import OSLog
private let logger = Logger(subsystem: "com.designoverhaul.ChristmasWishlist", category: "ViewName")

logger.debug("Event happened: \(value)")
logger.error("Error occurred: \(error.localizedDescription)")
```

### 3. Use Feature Flags for Experimental Features
Toggle new features without rebuilding:
```swift
struct FeatureFlags {
    static let enableNewUI = false
    static let debugMode = true
}
```

### 4. Keep AI Conversations Focused
- Don't ask to "refactor the whole app"
- Focus on single components or features
- Smaller scope = better results
- Make incremental changes

### 5. Document Session Changes
At end of major changes, document in this file:
- What broke
- How it was fixed
- Rollback steps if needed

### 6. iOS 26.1 Specific Considerations
Deployment target is iOS 26.1 (cutting edge). Document edge cases below:

**Known iOS 26 Gotchas:**
- (Add discovered issues here as they come up)
- Example format: "NO .background() before .glassEffect()"

### 7. SwiftUI Development Patterns
- App uses SwiftUI lifecycle (`@main` struct conforming to `App`)
- Use `#Preview` macro for SwiftUI previews (not `PreviewProvider`)
- Keep views in separate files as the app grows
- Extract complex view logic into computed properties or separate types

### 8. Testing After Changes
**ALWAYS follow this workflow:**
1. Clean build folder: Cmd+Shift+K in Xcode or `xcodebuild clean`
2. Build and run on device or simulator
3. Check Xcode console for errors/warnings
4. Test the specific functionality changed
5. Test related functionality that might be affected
6. Commit changes with descriptive message

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

### Firebase Development Tasks

**Setup Firebase:**
1. Add `GoogleService-Info.plist` to Xcode project
2. Add Firebase SDK via Swift Package Manager
3. Initialize Firebase in `ChristmasWishlistApp.swift`:
```swift
import FirebaseCore
FirebaseApp.configure()
```

**Common Firebase Operations:**
```swift
// Save item to Firestore
let db = Firestore.firestore()
try await db.collection("wishlistItems").document(itemId).setData([...])

// Fetch items from Firestore
let snapshot = try await db.collection("wishlistItems")
    .whereField("ownerPhone", isEqualTo: normalizedPhone)
    .getDocuments()

// Upload image to Storage
let storageRef = Storage.storage().reference()
let imageRef = storageRef.child("images/\(itemId).jpg")
try await imageRef.putDataAsync(imageData)
```

**Phone Auth Flow:**
```swift
// Send SMS code
PhoneAuthProvider.provider().verifyPhoneNumber("+12052929663") { verificationID, error in
    // Store verificationID
}

// Verify code
let credential = PhoneAuthProvider.provider().credential(
    withVerificationID: verificationID,
    verificationCode: code
)
try await Auth.auth().signIn(with: credential)
```

**Testing with Firebase Emulators:**
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Start emulators locally
firebase emulators:start --only firestore,auth,storage,functions
```

### Git Workflow
```bash
# Current branch: liveBranch (main development branch)
# Stage changes
git add .

# Commit with descriptive message
git commit -m "Brief description of changes"

# Push to remote
git push origin liveBranch
```

## Debugging Tips

### Common Issues and Solutions

**Build Failures After AI Changes:**
1. Clean build folder (Cmd+Shift+K)
2. Close and reopen Xcode
3. Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData`
4. Verify file is added to target in File Inspector

**SwiftData Issues:**
1. Delete app from simulator/device to reset database
2. Check model schema hasn't changed incompatibly
3. Use Xcode's SwiftData debugger (Window > Organizer)

**UI Not Updating:**
1. Verify `@State`, `@Binding`, `@Environment` usage
2. Check view is properly observing model changes
3. Add `.id()` modifier to force view refresh if needed

**Preview Crashes:**
1. Ensure preview has mock data
2. Check for force-unwrapped optionals in view
3. Simplify preview to isolate issue

### Adding Logger for Debugging
```swift
import OSLog

extension Logger {
    static let wishlist = Logger(subsystem: "com.designoverhaul.ChristmasWishlist", category: "Wishlist")
    static let friends = Logger(subsystem: "com.designoverhaul.ChristmasWishlist", category: "Friends")
    static let purchases = Logger(subsystem: "com.designoverhaul.ChristmasWishlist", category: "Purchases")
}

// Usage
Logger.wishlist.debug("Added item: \(itemName)")
Logger.friends.error("Failed to load contacts: \(error)")
```

## Known Issues & Workarounds

### Contacts Integration
- Friend's `hasApp` status is currently randomized (local-first mode)
- Need backend to check if contact phone number matches registered user
- **Critical**: Phone number is the source of truth for user identity
  - When adding friends from Contacts, use phone number as unique identifier
  - When pulling wishlist data, lookup by phone number (not name)
  - **Phone number normalization required**:
    - Store only digits (strip parentheses, dashes, spaces)
    - `(205)-292-9663` and `2052929663` must resolve to same user
    - Example: Normalize to `2052929663` before lookup/storage
- Names are display-only, phone numbers are the permanent identifier

### Purchase Tracking
- Currently only prevents same user from purchasing twice (local-only)
- Need to show who purchased each item (privacy consideration)
- **Sync Requirement**: When a user marks an item as purchased, this action must be synced to the cloud so:
  - The item owner can see it's been claimed
  - Other users can see it's no longer available
  - Purchase status is consistent across all users viewing the wishlist

### Data Sync Architecture
**Critical Understanding**: The app is designed with local-first architecture where the user's phone is the ultimate source of truth.

**Intended Sync Flow** (Firebase implementation in progress):

**Adding Items:**
1. User adds wishlist item → Save to local SwiftData FIRST
2. After local save succeeds → Push to Firebase Firestore
3. Other users can pull from Firestore to see the wishlist
4. Child account items follow same pattern

**Marking Items Purchased:**
1. User marks item as purchased → Save purchase status to local SwiftData FIRST
2. After local save succeeds → Push purchase status to cloud
3. Item owner and other users pull update to see item is claimed
4. This prevents duplicate purchases across all users

**Viewing Wishlists (Critical UX Requirement):**
1. User opens wishlist view → Display local SwiftData IMMEDIATELY (zero delay)
2. In parallel: Trigger background sync to check for updates from cloud
3. When syncing friend's wishlist: Lookup by normalized phone number (not name)
4. If updates found → Apply changes silently to the view without disrupting user
5. NO loading spinners, NO delays, NO blocking the UI
6. This applies to both user's own wishlist and friends' wishlists

**Phone Number Normalization (Critical for Lookups):**
1. When storing phone number → Strip all formatting, store digits only
2. When looking up user → Normalize phone number before query
3. Examples that must match:
   - `(205)-292-9663` → normalize to `2052929663`
   - `205-292-9663` → normalize to `2052929663`
   - `2052929663` → already normalized
4. All three formats above must return John's wishlist data

**Current State**:
- Migrating from CloudKit to Firebase (December 2024)
- Firebase Firestore for multi-user data sharing
- Firebase Auth for phone number authentication
- Firebase Storage for images
- Firebase Cloud Messaging for push notifications
- Maintaining local-first SwiftData architecture

**Important**: Firebase sync follows local-first principle. Always save locally first, then sync to Firestore as a secondary operation. This ensures the app works offline and the user never loses data even if cloud sync fails.

**Critical UX Requirement**: The app must feel instant. When opening any wishlist view:
- Display local data immediately (zero delay)
- Sync happens in the background
- Updates apply silently without blocking or disrupting the UI
- Never show loading spinners when opening wishlists
- Network requests should never block the user interface

## Session Change Log

### Template for Documenting Changes
When making significant changes, add entry here:

**[Date] - [Feature/Fix Name]**
- **What Changed**: Brief description
- **Files Modified**: List of files
- **Breaking Changes**: Any breaking changes
- **Testing Done**: What was tested
- **Rollback Steps**: How to undo if needed
- **Known Issues**: Any remaining issues

---

**2024-12-10 - Firebase Migration Started**
- **What Changed**: Migrating from CloudKit to Firebase for cloud sync
- **Why**: CloudKit issues, need more reliable backend with better notification support
- **New Services**:
  - Firebase Auth (phone number authentication)
  - Firestore (NoSQL database)
  - Firebase Storage (image uploads)
  - Firebase Cloud Messaging (push notifications)
- **Files Being Created**:
  - `Firebase/FirebaseManager.swift` - Main coordinator
  - `Firebase/FirebaseAuthManager.swift` - Phone auth
  - `Firebase/FirebaseStorageManager.swift` - Image handling
  - `Firebase/FirebaseModels.swift` - Helper structs
  - `Views/Auth/PhoneAuthView.swift` - Phone entry UI
  - `Views/Auth/SMSVerificationView.swift` - Code verification UI
- **Files Being Deleted**: All CloudKit files (CloudKitManager, CloudKitDebugHelper, etc.)
- **Architecture**: Maintaining local-first SwiftData, Firebase for sync
- **Timeline**: ~3-4 weeks implementation
- **Testing Strategy**: Firebase Emulators for local testing
- **Rollback Steps**: Keep CloudKit code in git history until Firebase proven stable

---

## Future Enhancements

### Planned Features
- [x] Backend sync with Firebase (IN PROGRESS - December 2024)
- [x] Push notifications via Firebase Cloud Messaging (IN PROGRESS)
- [x] Image uploads via Firebase Storage (IN PROGRESS)
- [ ] Price tracking and budget management
- [ ] Sharing wishlists via link
- [ ] Multi-language support
- [ ] Real-time updates via Firestore listeners

### Technical Debt
- [ ] Add comprehensive unit tests
- [ ] Implement proper error handling throughout
- [ ] Add loading states for async operations
- [ ] Optimize SwiftData queries for large wishlists
- [ ] Add accessibility labels and VoiceOver support
- [ ] Implement phone number normalization utility
- [ ] Add unit tests for phone number normalization edge cases
- [ ] Handle international phone numbers in normalization

## Resources

### Useful Commands
```bash
# View Xcode build logs
tail -f ~/Library/Developer/Xcode/DerivedData/*/Logs/Build/*.xcactivitylog

# Clear all simulators
xcrun simctl erase all

# List available simulators
xcrun simctl list devices

# Open simulator without Xcode
open -a Simulator
```

### Documentation Links
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [iOS 26 Release Notes](https://developer.apple.com/documentation/ios-release-notes)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Firebase iOS Documentation](https://firebase.google.com/docs/ios/setup)
- [Firestore Documentation](https://firebase.google.com/docs/firestore)
- [Firebase Auth Documentation](https://firebase.google.com/docs/auth/ios/phone-auth)
- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging/ios/client)
