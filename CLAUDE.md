# Christmas Wishlist

iOS app (display name **North Pole**). Bundle ID: `com.designoverhaul.ChristmasWishlist` — NEVER change.

## Stack
- Swift / SwiftUI + SwiftData (App Group shared with share extension)
- Firebase Auth (phone), Firestore, Storage, Messaging, Cloud Functions
- Xcode project: `ChristmasWishlist.xcodeproj`
- Ask Santa / title cleanup: xAI **grok-4.5** via `XAIService`
- Paywall / subscriptions: **Superwall** (`SuperwallKit`) via `SuperwallManager`

## Architecture
- **Remote source of truth:** Firestore (`users`, `wishlistItems`, `children`, `friends`, `purchases`)
- **Local cache:** SwiftData in App Group `group.com.designoverhaul.ChristmasWishlist`
- **Identity:** Canonical phone digits with US country code (`PhoneNumber.normalize`) — e.g. `12055551234`
- **Friends:** One-way edges; doc id `{userPhone}_{friendPhone}`; add path is `FirebaseManager.addFriend` (onboarding, contacts, deep links)
- **Claims:** Friends set `purchases` + `wishlistItems.isPurchased`. Friend UI/claim status uses `isPurchased`; `purchaserPhone` is only readable by owner/purchaser (see `firestore.rules`)
- **Self check-off:** `wishlistItems.purchasedByOwner` is set only by the owner (`FirebaseManager.setOwnerPurchased`); friend claim writes can't touch it (rules limit friends to `isPurchased`)
- **Free tier = 8 gifts per person.** `SuperwallManager.freeGiftsPerPerson` is the allowance, and it applies to each profile separately (you and each child), matching `MyWishlistView.myItems`. The `+` button routes through `SuperwallManager.requestAddGift`, which only involves Superwall once the person is at the limit; then the `gift_limit_reached` placement decides. Settings' upgrade row uses `unlock_unlimited_gifts`. Both placements need a **Gated** paywall in the dashboard, otherwise the limit isn't enforced.
- **Ask Santa is gated purely from the dashboard.** `AskSantaView.performSearch` routes through `SuperwallManager.requestAskSantaSearch`, which registers `ask_santa_search` on *every* search with no allowance in the app — free vs. limited vs. paid is a campaign decision, and the `is_refining` param separates "Find More" from a first search. Gating happens before any state changes so the input form isn't replaced by an empty results view behind the paywall.
- **Spoiler settings are paywalled and default OFF.** `showPurchasedItems` and `notificationsEnabled` both start `false` (every `@AppStorage` declaration, `NotificationManager`, and the Firestore `settings` seeded by `FirebaseManager.createOrUpdateUser`). Turning either on registers `reveal_purchases` via `SuperwallManager.requestRevealPurchases`, with a `feature` param of `show_purchased_status`, `purchase_notifications`, or `onboarding_surprises` (onboarding's "I don't like surprises." button, which sets both). Like Ask Santa there's no allowance in the app, so the paywall must be **Gated** to actually hold. The Settings switches are bound to mirror `@State` and snap back in `didResolve` when the paywall was dismissed unpurchased.
- **Purchased = wrapped gift:** `WishlistItemPhoto` swaps the item photo for a `gift1`–`gift4` asset. Friend lists: gift whenever `isPurchased`. Own list: gift when `purchasedByOwner` (always) or when `isPurchased && showPurchasedItems` — friends' claims stay secret unless the user opts in ("Show purchased status" in Settings / surprises choice in onboarding). The `isVisiblyPurchased` rule lives in `MyWishlistView`/`WishlistItemRow`/`MyItemDetailView`; keep them in sync.

## Key Rules
- See global `~/.claude/CLAUDE.md` for iOS development guidelines
- Do not reintroduce CloudKit — migration is complete; Firebase only
- Deploy `firestore.rules` when changing security (`firebase deploy --only firestore:rules`)
- Add project-specific gotchas here as you discover them

## Gotchas
- **Never blind-overwrite `wishlistItems` docs.** `isPurchased` is written by *friends* (claims) and `createdAt` must stay stable. `FirebaseManager.saveWishlistItem` is a merge-upsert that only sets `isPurchased`/`createdAt` when the doc doesn't exist yet — keep it that way. A plain `setData` here once wiped every claim in production (gift images reverted to photos).
- **Anything synced *down* from Firestore must get `lastSyncedAt` set.** `uploadUnsyncedLocalItems` (share-extension upload path, runs at every launch) treats `lastSyncedAt == nil` as "needs upload" and would re-upload synced items. It also only handles `childId == ""` items because it uploads with `ownerType: "user"`.
- **Rules that read `resource.data` must handle a missing document.** `resource` is null for a `get()` on a doc that doesn't exist, and dereferencing it aborts rule evaluation, so the client gets "Missing or insufficient permissions" instead of an empty snapshot. Any read rule with an owner check needs a leading `resource == null ||`. This broke adding a new friend: `FirebaseManager.saveFriend` reads `friends/{userPhone}_{friendPhone}` before deciding create vs merge.
- **Queries on `purchases` must be scoped to the current user** (`purchaserPhone == me` or `ownerPhone == me`). Rules are not filters: an `itemId`-only query is rejected outright by `firestore.rules`.
- **A Superwall placement with no campaign runs its feature closure immediately.** That's the deliberate failure mode for `requestAddGift` — if the dashboard isn't configured (or the API key is missing) adding gifts keeps working instead of dead-ending. The flip side is that the 8-gift limit is only *enforced* once the campaign exists with the paywall set to Gated, so don't test the limit against a project with no campaign and conclude the code is broken.
- **`createOrUpdateUser` runs at every launch, so it must not rewrite `settings`.** It now seeds `settings`/`createdAt` only when the user doc is missing; the old `setData(merge: true)` re-sent the defaults on each launch, which would stomp whatever the user chose for purchase notifications (and, before that, silently forced them back *on* server-side while the local toggle said off).
- **Launch may only turn `notificationsEnabled` off, never on.** `ChristmasWishlistApp` still asks for the iOS permission at first launch so the app shows up in Settings → Notifications, but it no longer mirrors the permission into the preference — that would hand out the paywalled setting to anyone who tapped Allow.
- **Don't put a `christmaswishlist://` link in an outgoing message.** Messages and other messaging apps only linkify `http`/`https`, so a custom scheme arrives as untappable plain text — the recipient would have to copy it into Safari, and before they install it does nothing anyway. The invite in `FriendWishlistView.createInviteMessage` is the App Store link only. It doesn't need the add-friend link: the inviter's friend edge already exists, and `wishlistItems` are readable by any signed-in user (`firestore.rules`), so the invitee's list shows up as soon as they sign in with that number. The edge is a contact list, not an access gate. One-tap reciprocal add would need a real universal link — associated domains entitlement plus an `apple-app-site-association` file hosted on designoverhaul.com — not a custom scheme.
- **Every xAI call needs `reasoning_effort: "low"`.** grok-4.5 reasons before answering and at the default effort the Ask Santa prompt takes 45–80s (measured), so it timed out and Ask Santa returned nothing. Title cleaning was over its 10s timeout too and silently fell back to the raw title. Low effort brings these to ~15s and ~4s with no quality loss. Don't "fix" a timeout here by raising `timeoutInterval` — cap the reasoning instead.
- **Developer Tools in Settings are gated by install type, not `#if DEBUG`.** `DeveloperTools.isAvailable` checks for `embedded.mobileprovision` (present on Xcode installs, stripped from App Store / TestFlight). Gating on `#if DEBUG` hid the section whenever Run used Release — which this scheme historically did for device installs.
