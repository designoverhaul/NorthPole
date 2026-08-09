//
//  MyWishlistView.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData

/// Payload for `.sheet(item:)` so the activity controller is always built with
/// the text from the tap that presented it.
private struct ShareableWishlist: Identifiable {
    let id = UUID()
    let text: String
}

struct MyWishlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<WishlistItem> { $0.isOwnedByCurrentUser == true },
        sort: \WishlistItem.createdAt,
        order: .reverse
    ) private var items: [WishlistItem]
    @Query(sort: \Child.name) private var children: [Child]
    @ObservedObject private var firebase = FirebaseManager.shared
    @ObservedObject private var superwall = SuperwallManager.shared

    @State private var showingAddGift = false
    @State private var itemToEdit: WishlistItem?
    @State private var selectedItem: WishlistItem?
    @State private var selectedChild: Child? = nil // Selected child for viewing their wishlist
    @State private var purchasedItemIdForSparkle: UUID? = nil
    @State private var showFallingSnow: Bool = false
    @AppStorage("showPurchasedItems") private var showPurchasedItems = false

    // Share wishlist state
    @State private var shareContent: ShareableWishlist?
    @State private var showingError = false
    @State private var errorMessage: String?
    @State private var lastSyncTime: Date? = nil
    @State private var isInitialLaunch = true // Track if this is the first sync attempt

    var myItems: [WishlistItem] {
        if let selectedChild = selectedChild {
            // Show items for selected child
            return items.filter { $0.ownerId == selectedChild.id }
        } else {
            // Show user's own items (items not belonging to any child)
            let childIds = children.map { $0.id }
            return items.filter { !childIds.contains($0.ownerId) }
        }
    }

    /// Gifts counted against the selected person's free allowance. Deduplicated by id for the
    /// same reason `itemsList` is: a stale duplicate row shouldn't eat into the allowance.
    private var myItemCount: Int {
        Set(myItems.map(\.id)).count
    }

    /// Only surface the allowance once the person is close to using it up.
    private static let capacityHintThreshold = 3

    var titleText: String {
        if let child = selectedChild {
            return String(localized: "\(child.name)'s Wishlist")
        }
        return children.isEmpty
            ? String(localized: "My Wishlist")
            : String(localized: "Our Wishlist")
    }

    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("")
                .goldTitle(verbatim: titleText)
                .navigationDestination(item: $selectedItem) { item in
                    MyItemDetailView(
                        item: item,
                        onEdit: {
                            itemToEdit = item
                        },
                        onDelete: {
                            // Pop before deleting so the detail view never renders a deleted model
                            selectedItem = nil
                            deleteItem(item)
                        },
                        onTogglePurchase: {
                            togglePurchase(item)
                        }
                    )
                }
                .sheet(isPresented: $showingAddGift) {
                    AddGiftView(
                        userId: selectedChild?.id ?? UUID(), // Will be ignored, AddGiftView determines owner
                        onItemAdded: {
                            // Sparkle will show when item is purchased, not when added
                        }
                    )
                }
                .sheet(item: $itemToEdit) { item in
                    AddGiftView(
                        userId: selectedChild?.id ?? UUID(),
                        onItemAdded: {
                            // Sparkle will show when item is purchased, not when added
                        },
                        itemToEdit: item
                    )
                }
                .sheet(item: $shareContent) { content in
                    ShareSheet(activityItems: [content.text])
                }
                .alert("Error", isPresented: $showingError) {
                    Button("OK", role: .cancel) { }
                } message: {
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                    }
                }
        }
        .task {
            // Wait for authentication to be ready before syncing
            // This prevents the "Please sign in to continue" error on app launch
            var attempts = 0
            while !firebase.isAuthenticated && attempts < 10 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                attempts += 1
            }

            // Only sync if authenticated
            if firebase.isAuthenticated {
                await loadChildren()
                await downloadAllItemsFromFirebase()
            } else {
                // After grace period, if still not authenticated, mark initial launch as complete
                // This allows error messages to show for genuine auth failures
                print("⚠️ [TASK] Auth grace period expired without authentication")
                isInitialLaunch = false
            }
        }
        .onChange(of: firebase.shouldRefreshChildren) { _, _ in
            Task {
                await loadChildren()
            }
        }
        .onChange(of: firebase.isAuthenticated) { _, isAuth in
            if isAuth {
                Task {
                    await loadChildren()
                    await downloadAllItemsFromFirebase()
                }
            }
        }
        .onAppear {
            // Auto-sync items when view appears (throttled to avoid excessive syncs)
            // Only sync if authenticated to avoid showing errors during app launch
            guard firebase.isAuthenticated else {
                print("⏸️ [ONAPPEAR] Skipping sync - not authenticated yet")
                return
            }

            let now = Date()
            if let lastSync = lastSyncTime {
                // Only sync if it's been more than 30 seconds since last sync
                let timeSinceLastSync = now.timeIntervalSince(lastSync)
                if timeSinceLastSync < 30 {
                    return
                }
            }

            Task {
                await downloadAllItemsFromFirebase()
                lastSyncTime = now
            }
        }
    }

    private var mainContent: some View {
        ZStack {
            // Background
            Color.creamBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Profile Picker (only if there are children)
                if !children.isEmpty {
                    profilePicker
                }

                if myItems.isEmpty {
                    emptyStateView
                } else {
                    itemsList
                }
            }

            floatingActionButton
            
            // Falling snow overlay - covers entire screen including header
            // Temporarily hidden
            // if showFallingSnow {
            //     FallingSnowEffect(snowflakeCount: Int.random(in: 15...25))
            //         .allowsHitTesting(false)
            //         .transition(.opacity)
            // }
        }
    }

    private var profilePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "Me" pill
                ProfilePill(
                    name: String(localized: "Me"),
                    isSelected: selectedChild == nil,
                    action: {
                        HapticManager.buttonTapped()
                        selectedChild = nil
                    }
                )

                // Children pills
                ForEach(children) { child in
                    ProfilePill(
                        name: child.name,
                        isSelected: selectedChild?.id == child.id,
                        action: {
                            HapticManager.buttonTapped()
                            selectedChild = child
                        }
                    )
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.md)
        }
        .background(Color.creamBackground)
    }

    private var itemsList: some View {
        // Deduplicate items by ID (keep first occurrence)
        let uniqueItems = Array(Dictionary(grouping: myItems, by: { $0.id }).values.compactMap { $0.first }).sorted(by: { $0.createdAt > $1.createdAt })

        return List {
            sendToFriendsButton
                .listRowInsets(EdgeInsets(top: 0, leading: Spacing.md, bottom: Spacing.md, trailing: Spacing.md))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            ForEach(uniqueItems, id: \.id) { item in
                Button {
                    selectedItem = item
                } label: {
                    WishlistItemRow(
                        item: item,
                        showPurchaseButton: false,
                        onDelete: nil,
                        onTogglePurchase: nil,
                        giftIndex: computeGiftIndex(for: item, in: uniqueItems),
                        showSparkle: purchasedItemIdForSparkle == item.id,
                        onSparkleComplete: {
                            purchasedItemIdForSparkle = nil
                        }
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .listRowInsets(EdgeInsets(top: 0, leading: Spacing.md, bottom: 0, trailing: Spacing.md))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        deleteItem(item)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            if let remaining = superwall.remainingGifts(usedCount: uniqueItems.count),
               remaining <= Self.capacityHintThreshold {
                giftCapacityFooter(remaining: remaining)
            }
        }
        .listStyle(.plain)
        .listRowSpacing(2)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, Spacing.md, for: .scrollContent)
        .contentMargins(.bottom, 80, for: .scrollContent) // Space for FAB
        .refreshable {
            print("🔄 [PULL-TO-REFRESH] User pulled to refresh")
            HapticManager.buttonTapped()
            await downloadAllItemsFromFirebase()
        }
    }
    
    private var sendToFriendsButton: some View {
        Button(action: shareWishlist) {
            Label("Send to Friends", systemImage: "paperplane.fill")
        }
        .buttonStyle(GoldButtonStyle())
    }

    private func giftCapacityFooter(remaining: Int) -> some View {
        Group {
            if remaining == 0 {
                Text("All \(SuperwallManager.freeGiftsPerPerson) free gifts used — tap + to add more")
            } else {
                Text("\(remaining) of \(SuperwallManager.freeGiftsPerPerson) free gifts left")
            }
        }
        .font(.caption)
        .foregroundColor(.warmGray)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, Spacing.sm)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .accessibilityAddTraits(.isStaticText)
    }

    // Whether the owner's list shows this item as purchased:
    // self-marks always show; friend claims only when showPurchasedItems is on.
    private func isVisiblyPurchased(_ item: WishlistItem) -> Bool {
        item.purchasedByOwner || (showPurchasedItems && item.isPurchased)
    }

    // Compute gift index for an item based on its position among visibly purchased items
    private func computeGiftIndex(for item: WishlistItem, in allItems: [WishlistItem]) -> Int? {
        guard isVisiblyPurchased(item) else { return nil }

        let purchasedItems = allItems
            .filter { isVisiblyPurchased($0) }
            .sorted { $0.createdAt < $1.createdAt }

        return purchasedItems.firstIndex(where: { $0.id == item.id })
    }

    private var floatingActionButton: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                FloatingActionButton(
                    action: {
                        HapticManager.buttonTapped()
                        superwall.requestAddGift(
                            usedCount: myItemCount,
                            isForChild: selectedChild != nil
                        ) {
                            showingAddGift = true
                        }
                    },
                    icon: "plus"
                )
                .sparkle()
                .padding(Spacing.lg)
            }
        }
    }
    
    // Helper view for the profile pills
    struct ProfilePill: View {
        let name: String
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Text(name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(isSelected ? .white : .warmGray)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.forestGreen : Color.white)
                    )
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? Color.forestGreen : Color.warmGray.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: isSelected ? Color.forestGreen.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
            }
        }
    }

    private var emptyStateView: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                Spacer()

                Image(systemName: "gift")
                    .font(.system(size: 72))
                    .foregroundColor(.warmGrayLight)

                Text("No items yet")
                    .font(.headingMedium)
                    .foregroundColor(.warmGray)

                Text("Tap the + button to add items\nto your wishlist")
                    .font(.bodyMedium)
                    .foregroundColor(.warmGray)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .refreshable {
            print("🔄 [PULL-TO-REFRESH] User pulled to refresh (empty state)")
            HapticManager.buttonTapped()
            await downloadAllItemsFromFirebase()
        }
    }

    private func deleteItem(_ item: WishlistItem) {
        // Optimistically delete from UI
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            HapticManager.itemDeleted()
            modelContext.delete(item)
            try? modelContext.save()
        }
        
        // Delete from Firebase
        Task {
            await deleteItemFromFirebase(item)
        }
    }

    @MainActor
    private func deleteItemFromFirebase(_ item: WishlistItem) async {
        guard firebase.isAuthenticated else {
            print("⚠️ [DELETE] Not authenticated, skipping Firebase deletion")
            return
        }

        print("🗑️ [DELETE] Deleting item '\(item.name)' from Firebase...")

        do {
            try await firebase.deleteWishlistItem(id: item.id)
            print("✅ [DELETE] Successfully deleted from Firebase")
        } catch {
            print("❌ [DELETE] Failed to delete from Firebase: \(error.localizedDescription)")
        }
    }
    
    private func togglePurchase(_ item: WishlistItem) {
        let marking = !isVisiblyPurchased(item)

        withAnimation {
            HapticManager.buttonTapped()
            item.purchasedByOwner = marking
            item.isPurchased = marking // optimistic; friend claims re-resolved below
            if marking {
                HapticManager.itemMarkedPurchased()
                purchasedItemIdForSparkle = item.id
            } else {
                HapticManager.impact(.medium)
            }
            try? modelContext.save()
        }

        let itemId = item.id
        Task {
            // On unmark, isPurchased stays true remotely if a friend still has an
            // active claim; mirror the resolved value locally.
            if let resolvedClaim = try? await firebase.setOwnerPurchased(id: itemId, purchased: marking) {
                await MainActor.run {
                    item.isPurchased = resolvedClaim
                    try? modelContext.save()
                }
            }
        }
    }

    @MainActor
    private func downloadAllItemsFromFirebase() async {
        print("📥 [FIREBASE SYNC] Starting sync from Firebase")

        guard firebase.isAuthenticated else {
            print("⚠️ [FIREBASE] Not authenticated")
            // Only show error if we're past the initial auth grace period
            // During initial launch, Firebase might still be initializing
            if !isInitialLaunch {
                errorMessage = String(localized: "Please sign in to continue")
                showingError = true
            } else {
                print("ℹ️ [FIREBASE] Skipping error alert - still in initial auth grace period")
            }
            return
        }

        do {
            // Fetch items and children from Firebase (returns local immediately, syncs in background)
            _ = try await firebase.fetchMyWishlistItems(context: modelContext)
            _ = try await firebase.fetchMyChildren(context: modelContext)

            print("✅ [FIREBASE SYNC] Sync completed successfully")
            // Mark that we've completed initial sync successfully
            isInitialLaunch = false
        } catch {
            print("❌ [FIREBASE SYNC] Failed: \(error.localizedDescription)")
            // Only show sync errors if we're authenticated but sync failed
            // Don't show errors during initial launch when auth might still be initializing
            if !isInitialLaunch {
                errorMessage = String(localized: "Failed to sync: \(error.localizedDescription)")
                showingError = true
            }
        }
    }

    // Share wishlist function
    private func shareWishlist() {
        HapticManager.buttonTapped()

        let itemLines = myItems.map { item -> String in
            if let url = item.url, !url.isEmpty {
                return "• \(item.name)\n  \(url)"
            }
            return "• \(item.name)"
        }.joined(separator: "\n")

        let message = String(localized: """
        Hi! Would you like to do a gift exchange? Build your list here and we can sync up.

        \(titleText)
        \(itemLines)

        Get the app: https://apps.apple.com/app/id6755366177
        """)

        shareContent = ShareableWishlist(text: message)
    }
    
    private func loadChildren() async {
        guard firebase.isAuthenticated else {
            print("⚠️ [MYWISHLIST] Not authenticated with Firebase")
            return
        }

        do {
            // Fetch children from Firebase (returns local immediately, syncs in background)
            _ = try await firebase.fetchMyChildren(context: modelContext)
            print("✅ [MYWISHLIST] Loaded children from Firebase")
        } catch {
            print("❌ [MYWISHLIST] Error loading children: \(error.localizedDescription)")
        }
    }
}

// MARK: - My Item Detail View

struct MyItemDetailView: View {
    @Bindable var item: WishlistItem
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onTogglePurchase: () -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage("showPurchasedItems") private var showPurchasedItems = false
    @State private var showingDeleteConfirmation = false

    // Self-marks always show; friend claims only when showPurchasedItems is on.
    private var isVisiblyPurchased: Bool {
        item.purchasedByOwner || (showPurchasedItems && item.isPurchased)
    }

    var body: some View {
        ZStack {
            Color.creamBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Image if available
                    if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 300)
                            .cornerRadius(CornerRadius.md)
                            .shadow(color: DesignShadow.soft, radius: 8, x: 0, y: 4)
                    }

                    // Item name
                    Text(item.name)
                        .font(.custom("Caveat", size: 44))
                        .foregroundColor(.warmBlack)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Purchase status badge
                    if isVisiblyPurchased {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.successGreen)
                            Text("Checked off")
                                .font(.bodyMedium)
                                .fontWeight(.medium)
                                .foregroundColor(.successGreen)
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.successGreen.opacity(0.1))
                        .cornerRadius(CornerRadius.sm)
                    }

                    // Description
                    if let description = item.itemDescription, !description.isEmpty {
                        Text(description)
                            .font(.bodyMedium)
                            .foregroundColor(.warmGray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Spacing.md)
                    }

                    // Actions
                    VStack(spacing: Spacing.sm) {
                        // Mark as Purchased button
                        Button(action: {
                            HapticManager.buttonTapped()
                            onTogglePurchase()
                        }) {
                            if isVisiblyPurchased {
                                Text("Unpurchase")
                                    .font(.bodyLarge)
                                    .fontWeight(.medium)
                                    .foregroundColor(.warmGray)
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, Spacing.lg)
                                    .padding(.vertical, Spacing.md)
                                    .background(Color.creamCard)
                                    .cornerRadius(CornerRadius.md)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.md)
                                            .stroke(Color.warmGray, lineWidth: 1)
                                    )
                            } else {
                                HStack {
                                    Text("🎁")
                                        .font(.system(size: 20))
                                    Text("Mark as Purchased")
                                }
                                .font(.bodyLarge)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, Spacing.lg)
                                .padding(.vertical, Spacing.md)
                                .background(Color.forestGreen)
                                .cornerRadius(CornerRadius.md)
                                .shadow(
                                    color: DesignShadow.medium,
                                    radius: 8,
                                    x: 0,
                                    y: 4
                                )
                            }
                        }

                        // URL Link
                        if let url = item.url, !url.isEmpty, let urlObj = URL(string: url) {
                            Link(destination: urlObj) {
                                HStack {
                                    Image(systemName: "link")
                                    Text("View Item")
                                }
                                .font(.bodyLarge)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, Spacing.lg)
                                .padding(.vertical, Spacing.md)
                                .background(Color.gold)
                                .cornerRadius(CornerRadius.md)
                                .shadow(
                                    color: Color.gold.opacity(0.3),
                                    radius: 8,
                                    x: 0,
                                    y: 4
                                )
                            }
                        }

                        // Edit button
                        Button(action: {
                            HapticManager.buttonTapped()
                            onEdit()
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Edit")
                            }
                            .font(.bodyLarge)
                            .fontWeight(.medium)
                            .foregroundColor(.goldDeep)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.md)
                            .background(Color.goldLight.opacity(0.5))
                            .cornerRadius(CornerRadius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .stroke(Color.gold.opacity(0.35), lineWidth: 1)
                            )
                        }

                        // Delete button
                        Button(action: {
                            HapticManager.buttonTapped()
                            showingDeleteConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete")
                            }
                            .font(.bodyLarge)
                            .fontWeight(.medium)
                            .foregroundColor(.errorRed)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.md)
                            .background(Color.errorRed.opacity(0.08))
                            .cornerRadius(CornerRadius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .stroke(Color.errorRed.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.top, Spacing.xs)
                }
                .padding(Spacing.lg)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Item", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete '\(item.name)'?")
        }
    }
}

#Preview {
    MyWishlistView()
        .modelContainer(for: [WishlistItem.self])
}
