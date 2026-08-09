# Friend Wishlist Item Tap Freeze - Investigation Notes

## Problem
Tapping a friend's wishlist item **immediately freezes the app**. User's own wishlist items work perfectly.

---

## PREVIOUS ATTEMPTS (ALL FAILED)

### Attempt 1: Programmatic Navigation with .navigationDestination
- **What we tried:** Used `.navigationDestination(item:)` with `@State selectedItemData`
- **Problem:** Infinite loop in navigation destination closure
- **Why it failed:** Accessing reactive `@Query` in navigation destination caused rebuild loop

### Attempt 2: Pass itemId and Re-fetch in Detail View
- **What we tried:** Passed only `itemId` to detail view, re-fetched item using `FetchDescriptor`
- **Problem:** App still froze
- **Why it failed:** Closure still captured reactive item from parent query

### Attempt 3: Pass @Bindable Item Directly (Current)
- **What we tried:** Match MyItemDetailView pattern exactly - pass `@Bindable var item`
- **Problem:** **STILL FREEZES**
- **Why it failed:** See root cause below

---

## ROOT CAUSE IDENTIFIED ✅

### The Critical Difference

**MyWishlistView (WORKS):**
```swift
ScrollView {
    LazyVStack {
        // Creates LOCAL, STABLE, NON-REACTIVE array
        let uniqueItems = Array(Dictionary(grouping: myItems, by: { $0.id })
            .values.compactMap { $0.first })
            .sorted(by: { $0.createdAt > $1.createdAt })

        ForEach(uniqueItems, id: \.id) { item in  // ← Iterates over LOCAL array
            NavigationLink {
                MyItemDetailView(item: item, ...)
            }
        }
    }
}
```

**FriendWishlistView (FREEZES):**
```swift
ScrollView {
    LazyVStack {
        // Iterates DIRECTLY over REACTIVE @Query
        ForEach(Array(cachedItems.enumerated()), id: \.element.id) { index, item in
            let isPurchased = purchases[itemIdString] != nil  // ← Accesses reactive state

            NavigationLink {
                FriendItemDetailView(item: item, isPurchased: isPurchased, ...)
            }
        }
    }
}
```

**The Freeze Mechanism:**
1. User taps item → NavigationLink evaluates destination closure
2. Closure captures `item` from the REACTIVE `@Query cachedItems`
3. Navigation starts
4. Background sync triggers → `@Query cachedItems` updates
5. SwiftUI re-evaluates ForEach because the reactive query changed
6. NavigationLink destination closure re-evaluates MID-NAVIGATION
7. SwiftUI gets confused about view identity → **FREEZE**

---

## THREE MOST PROBABLE SOLUTIONS

### ⭐ SOLUTION 1: Create Local Stable Array (HIGHEST PROBABILITY)
**Match MyWishlistView pattern exactly**

```swift
ScrollView {
    LazyVStack {
        // Create LOCAL array from reactive query
        let stableItems = Array(cachedItems)  // Snapshot at render time

        ForEach(stableItems, id: \.id) { item in
            let isPurchased = purchases[item.id.uuidString] != nil

            NavigationLink {
                FriendItemDetailView(item: item, isPurchased: isPurchased, ...)
            }
        }
    }
}
```

**Why this should work:**
- `stableItems` is a local copy, NOT reactive
- When `@Query cachedItems` updates, SwiftUI re-renders and creates NEW stable array
- But during navigation, the closure captures the STABLE array item, not the reactive query
- No mid-navigation re-evaluation

**Confidence:** 95% - This is the exact pattern that works in MyWishlistView

---

### SOLUTION 2: Use Computed Property for Stable Items
**Create computed var instead of inline local**

```swift
private var stableCachedItems: [WishlistItem] {
    Array(cachedItems)  // Snapshot the reactive query
}

var body: some View {
    ScrollView {
        LazyVStack {
            ForEach(stableCachedItems, id: \.id) { item in
                NavigationLink {
                    FriendItemDetailView(item: item, ...)
                }
            }
        }
    }
}
```

**Why this might work:**
- Similar to Solution 1 but cleaner
- Computed property evaluates fresh on each render
- Still creates non-reactive snapshot

**Confidence:** 85% - Should work but slightly less direct than Solution 1

---

### SOLUTION 3: Remove Enumeration, Iterate Directly
**Simplify the ForEach to match MyWishlistView**

Current:
```swift
ForEach(Array(cachedItems.enumerated()), id: \.element.id) { index, item in
```

Change to:
```swift
let items = Array(cachedItems)  // Stable snapshot
ForEach(items, id: \.id) { item in
```

**Why this might help:**
- The `.enumerated()` creates an additional wrapper
- Accessing `.element` might be creating reactive dependency
- Direct iteration is simpler

**Confidence:** 70% - Less certain, but worth trying if Solution 1 fails

---

## IMPLEMENTATION PLAN

1. **Try Solution 1 first** (inline local array)
2. If still freezes → **Try Solution 2** (computed property)
3. If still freezes → **Try Solution 3** (remove enumeration)
4. If all fail → **Deep dive into SwiftUI observation system**

---

## Key Observations

- MyWishlistView NEVER iterates directly over reactive @Query
- MyWishlistView ALWAYS creates local array first
- The freeze happens at tap time, not during scroll
- Background sync is the trigger for reactive query updates
- The problem is specifically with NavigationLink closure capturing reactive query items

---

## Files to Modify

**ChristmasWishlist/FriendWishlistView.swift** (lines 84-118)
- Current: `ForEach(Array(cachedItems.enumerated()), ...)`
- Change to: Create local stable array first, then ForEach over that
