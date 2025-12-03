//
//  FriendWishlistView.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI
import CloudKit
import SwiftData

// MARK: - Wishlist Cache
class WishlistCache {
    static let shared = WishlistCache()
    private var cache: [String: CachedWishlist] = [:]

    struct CachedWishlist {
        let items: [CKWishlistItem]
        let purchases: [String: CKPurchase]
        let timestamp: Date
    }

    func get(for key: String) -> CachedWishlist? {
        return cache[key]
    }

    func set(_ wishlist: CachedWishlist, for key: String) {
        cache[key] = wishlist
    }

    func clear(for key: String) {
        cache.removeValue(forKey: key)
    }

    func clearAll() {
        cache.removeAll()
    }
}

struct FriendWishlistView: View {
    let friend: Friend
    let child: CKChild?

    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var cloudKit = CloudKitManager.shared
    @State private var items: [CKWishlistItem] = []
    @State private var purchases: [String: CKPurchase] = [:] // itemRecordID -> Purchase
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccessSparkle = false
    @State private var showingShareSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingHideChildAlert = false
    @State private var showingPurchaseConfirmation = false
    @State private var itemToPurchase: CKWishlistItem?
    @State private var isCheckingForApp = false
    @Environment(\.dismiss) private var dismiss

    // Cache key based on friend/child
    private var cacheKey: String {
        if let child = child {
            return "child_\(child.id)"
        }
        return "friend_\(friend.friendUserRecordID ?? friend.id.uuidString)"
    }

    init(friend: Friend, child: CKChild? = nil) {
        self.friend = friend
        self.child = child
    }

    private var displayName: String {
        child?.name ?? friend.name
    }

    private var ownerRecordID: String? {
        if let child = child {
            return child.id
        }
        return friend.friendUserRecordID
    }

    var body: some View {
        ZStack {
            Color.creamBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Content area - always takes full space
                ZStack {
                    if isCheckingForApp {
                        SnowflakeLoadingView("Checking if friend has app...")
                            .padding()
                    } else if !friend.hasApp {
                        noAppView
                    } else if items.isEmpty {
                        emptyWishlistView
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 2) {
                                ForEach(items) { item in
                                    NavigationLink {
                                        FriendItemDetailView(
                                            item: item,
                                            isPurchased: purchases[item.id] != nil,
                                            onTogglePurchase: {
                                                togglePurchase(item)
                                            }
                                        )
                                    } label: {
                                        FriendWishlistItemRow(
                                            item: item,
                                            isPurchased: purchases[item.id] != nil
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .transition(.asymmetric(
                                        insertion: .scale.combined(with: .opacity),
                                        removal: .scale.combined(with: .opacity)
                                    ))
                                }
                            }
                            .padding(Spacing.md)
                            .padding(.bottom, 80)
                        }
                        .refreshable {
                            await loadItems(forceRefresh: true)
                        }
                    }

                    // Non-blocking loading indicator at the bottom - show during loading
                    if isLoading {
                        VStack {
                            Spacer()
                            HStack(spacing: 8) {
                                Image(systemName: "snowflake")
                                    .font(.system(size: 16))
                                    .foregroundColor(.forestGreen)
                                    .rotationEffect(.degrees(isLoading ? 360 : 0))
                                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: isLoading)

                                Text("Updating...")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.warmBlack)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.white)
                                    .shadow(color: DesignShadow.soft, radius: 8, x: 0, y: 4)
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.forestGreen.opacity(0.1), lineWidth: 1)
                                    )
                            )
                            .padding(.bottom, 20)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        .animation(.easeInOut, value: isLoading)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Success sparkle overlay
            if showSuccessSparkle {
                SuccessSparkle {
                    showSuccessSparkle = false
                }
                .allowsHitTesting(false)
            }
        }
        .navigationTitle("")
        .friendNameTitle(displayName)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if child != nil {
                        Button(action: {
                            showingHideChildAlert = true
                        }) {
                            Label("Hide Child", systemImage: "eye.slash")
                                .foregroundColor(.warmGray)
                        }
                    } else {
                        Button(action: {
                            HapticManager.buttonTapped()
                            showingShareSheet = true
                        }) {
                            Label("Invite \(String(friend.name.split(separator: " ").first ?? ""))", systemImage: "paperplane.fill")
                                .foregroundColor(.warmGray)
                        }

                        Button(action: {
                            showingDeleteAlert = true
                        }) {
                            Label("Remove Friend", systemImage: "person.fill.xmark")
                                .foregroundColor(.warmGray)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.warmGray)
                }
            }
        }
        .task {
            print("👁️ [APPEAR] FriendWishlistView appeared for \(friend.name)")
            print("👁️ [APPEAR] hasApp: \(friend.hasApp), recordID: \(friend.friendUserRecordID ?? "nil")")

            // If friend doesn't have app, check if they've installed it since we last checked
            if !friend.hasApp {
                print("👁️ [APPEAR] Friend doesn't have app, checking...")
                await checkIfFriendHasApp()
            }

            // Only load items if friend has the app
            if friend.hasApp {
                // Check cache first
                if let cached = WishlistCache.shared.get(for: cacheKey) {
                    print("💾 [CACHE] Found cached data for \(friend.name), using it immediately")
                    await MainActor.run {
                        items = cached.items
                        purchases = cached.purchases
                    }
                } else {
                    print("👁️ [APPEAR] No cache, loading items from CloudKit...")
                    await loadItems(forceRefresh: false)
                }
            } else {
                print("⚠️ [APPEAR] Still no app after check, showing no-app view")
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [createInviteMessage()])
        }
        .alert("Remove Friend", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                deleteFriend()
            }
        } message: {
            Text("Are you sure you want to remove \(friend.name) from your friends list?")
        }
        .alert("Hide Child", isPresented: $showingHideChildAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Hide", role: .destructive) {
                hideChild()
            }
        } message: {
            if let child = child {
                Text("Hide \(child.name)? You can unhide them later from the friend's wishlist.")
            }
        }
        .alert((itemToPurchase.map { purchases[$0.id] != nil } ?? false) ? "Mark as Unpurchased?" : "Mark as Purchased?",
               isPresented: $showingPurchaseConfirmation) {
            Button("Cancel", role: .cancel) {
                itemToPurchase = nil
            }
            Button((itemToPurchase.map { purchases[$0.id] != nil } ?? false) ? "Unmark" : "Mark Purchased", role: .none) {
                confirmPurchaseToggle()
                itemToPurchase = nil
            }
        } message: {
            if let item = itemToPurchase {
                if purchases[item.id] != nil {
                    Text("Unmark '\(item.name)' as purchased?")
                } else {
                    Text("Mark '\(item.name)' as purchased?")
                }
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }

    private var noAppView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "app.gift")
                .font(.system(size: 72))
                .foregroundColor(.warmGrayLight)

            Text("Can't connect to \(friend.name)")
                .font(.headingMedium)
                .foregroundColor(.warmGray)
                .multilineTextAlignment(.center)

            Text("To see each other's wishlists, you both need to share your profile links")
                .font(.bodyMedium)
                .foregroundColor(.warmGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Text("1.")
                        .fontWeight(.semibold)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Go to My Wishlist tab")
                        Text("Tap")
                            .foregroundColor(.warmGray)
                        + Text(" ")
                        + Text(Image(systemName: "square.and.arrow.up"))
                            .foregroundColor(.forestGreen)
                        + Text(" in top right")
                            .foregroundColor(.warmGray)
                    }
                }

                HStack(alignment: .top, spacing: Spacing.sm) {
                    Text("2.")
                        .fontWeight(.semibold)
                    Text("Send the link to \(String(friend.name.split(separator: " ").first ?? "them"))")
                }

                HStack(alignment: .top, spacing: Spacing.sm) {
                    Text("3.")
                        .fontWeight(.semibold)
                    Text("Ask them to send you theirs too")
                }
            }
            .font(.bodyMedium)
            .foregroundColor(.warmBlack)
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(Color.gold.opacity(0.1))
            )
            .padding(.horizontal, Spacing.lg)

            // Only show invite button if they haven't installed yet
            Button(action: {
                HapticManager.buttonTapped()
                showingShareSheet = true
            }) {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text("Or Invite to Install App")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
            .padding(.horizontal, Spacing.lg)

            Spacer()
        }
        .padding(Spacing.lg)
    }

    private var emptyWishlistView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "gift")
                .font(.system(size: 72))
                .foregroundColor(.warmGrayLight)

            Text("No items yet")
                .font(.headingMedium)
                .foregroundColor(.warmGray)

            Text("\(displayName) hasn't added\nanything to their wishlist")
                .font(.bodyMedium)
                .foregroundColor(.warmGray)
                .multilineTextAlignment(.center)

            Spacer()
        }
    }

    private func checkIfFriendHasApp() async {
        isCheckingForApp = true
        defer { isCheckingForApp = false }

        print("🔍 Checking if \(friend.name) has installed the app...")

        // Try to discover the friend by phone or email
        do {
            // Use the new combined discovery method (tries phone first, then email)
            let phoneNumbers = friend.phoneNumber.map { [$0] } ?? []
            let emails = friend.email.map { [$0] } ?? []

            let discoveredRecordID = try await cloudKit.discoverUser(
                phoneNumbers: phoneNumbers,
                emails: emails
            )

            // If we found them, update the friend record
            if let recordID = discoveredRecordID {
                print("✅ Found \(friend.name)! They have the app now. Record ID: \(recordID.recordName)")

                await MainActor.run {
                    // Update local friend record
                    friend.friendUserRecordID = recordID.recordName
                    friend.hasApp = true
                    try? modelContext.save()
                }
            } else {
                print("❌ \(friend.name) hasn't installed the app yet")
            }
        } catch {
            print("❌ Error checking if friend has app: \(error)")
        }
    }


    private func loadItems(forceRefresh: Bool = false) async {
        print("📦 [LOAD_ITEMS] ===== Starting to load items (forceRefresh: \(forceRefresh)) =====")
        print("📦 [LOAD_ITEMS] Friend: \(friend.name)")
        print("📦 [LOAD_ITEMS] Friend hasApp: \(friend.hasApp)")
        print("📦 [LOAD_ITEMS] Friend recordID: \(friend.friendUserRecordID ?? "nil")")
        print("📦 [LOAD_ITEMS] Child: \(child?.name ?? "nil")")
        print("📦 [LOAD_ITEMS] OwnerRecordID: \(ownerRecordID ?? "nil")")

        // Only load if owner has a record ID
        guard let recordID = ownerRecordID else {
            print("❌ [LOAD_ITEMS] No owner record ID - cannot load items")
            items = []
            return
        }

        // Check cache first (unless force refresh)
        if !forceRefresh, let cached = WishlistCache.shared.get(for: cacheKey) {
            print("💾 [CACHE] Using cached data (skipping CloudKit fetch)")
            await MainActor.run {
                items = cached.items
                purchases = cached.purchases
            }
            return
        }

        print("📦 [LOAD_ITEMS] Fetching from CloudKit...")
        isLoading = true
        defer { isLoading = false }

        do {
            let records = try await cloudKit.fetchFriendWishlistItems(friendRecordID: recordID)
            print("✅ [LOAD_ITEMS] Successfully fetched \(records.count) records from CloudKit")

            let loadedItems = records.map { CKWishlistItem(from: $0) }
            print("✅ [LOAD_ITEMS] Mapped to \(loadedItems.count) CKWishlistItem objects")

            // Log each item
            for (index, item) in loadedItems.enumerated() {
                print("   Item \(index + 1): \(item.name)")
            }

            // Load purchases for all items
            var purchaseDict: [String: CKPurchase] = [:]
            for item in loadedItems {
                do {
                    let purchaseRecords = try await cloudKit.fetchPurchasesForItem(itemRecordID: item.id)
                    // Just take the first purchase (most recent)
                    if let firstPurchase = purchaseRecords.first {
                        purchaseDict[item.id] = CKPurchase(from: firstPurchase)
                    }
                } catch {
                    print("⚠️ [LOAD_ITEMS] Error loading purchases for item \(item.id): \(error)")
                }
            }

            // Cache the results
            let cached = WishlistCache.CachedWishlist(
                items: loadedItems,
                purchases: purchaseDict,
                timestamp: Date()
            )
            WishlistCache.shared.set(cached, for: cacheKey)
            print("💾 [CACHE] Cached \(loadedItems.count) items for key: \(cacheKey)")

            await MainActor.run {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    items = loadedItems
                    purchases = purchaseDict
                }
                print("✅ [LOAD_ITEMS] UI updated with \(items.count) items")
            }
        } catch {
            print("❌ [LOAD_ITEMS] Failed to load wishlist: \(error)")
            if let ckError = error as? CKError {
                print("❌ [LOAD_ITEMS] CloudKit error code: \(ckError.code.rawValue)")
                print("❌ [LOAD_ITEMS] CloudKit error: \(ckError)")
            }
            errorMessage = "Failed to load wishlist: \(error.localizedDescription)"
        }

        print("📦 [LOAD_ITEMS] ===== Finished loading items =====")
    }

    private func togglePurchase(_ item: CKWishlistItem) {
        // Show confirmation alert
        itemToPurchase = item
        showingPurchaseConfirmation = true
    }

    private func confirmPurchaseToggle() {
        guard let item = itemToPurchase else { return }
        HapticManager.buttonTapped()

        Task {
            do {
                let wasPurchased = purchases[item.id] != nil

                // Check if this item is already purchased
                if wasPurchased {
                    // Unpurchase: Delete the purchase record
                    if let existingPurchase = purchases[item.id] {
                        try await cloudKit.deletePurchase(existingPurchase.record.recordID)
                    }

                    // Update UI
                    await MainActor.run {
                        purchases.removeValue(forKey: item.id)
                        HapticManager.impact(.medium)
                    }

                    print("✅ Unmarked item as purchased")
                } else {
                    // Purchase: Create a new purchase record
                    let purchaseRecord = try await cloudKit.savePurchase(itemRecordID: item.id)

                    // Update UI
                    await MainActor.run {
                        purchases[item.id] = CKPurchase(from: purchaseRecord)
                        HapticManager.itemMarkedPurchased()
                        showSuccessSparkle = true
                    }

                    // Track for review prompt (after first purchase)
                    ReviewManager.shared.markFirstPurchase()

                    print("✅ Marked item as purchased")
                }

                // Update cache with new purchase state
                let cached = WishlistCache.CachedWishlist(
                    items: items,
                    purchases: purchases,
                    timestamp: Date()
                )
                WishlistCache.shared.set(cached, for: cacheKey)
                print("💾 [CACHE] Updated cache after purchase toggle")

            } catch {
                errorMessage = "Failed to update item: \(error.localizedDescription)"
                HapticManager.errorOccurred()
            }
        }
    }

    private func createInviteMessage() -> String {

        return """
        I have a wishlist here if you are interested. I would like to see yours as well. Get the list here:

        https://apps.apple.com/app/id6755366177
        """
    }

    private func deleteFriend() {
        modelContext.delete(friend)
        try? modelContext.save()
        HapticManager.itemDeleted()
        dismiss()
    }

    private func hideChild() {
        guard let child = child else { return }

        // Update local friend record
        friend.hiddenChildRecordIDs.append(child.id)
        try? modelContext.save()

        HapticManager.buttonTapped()
        dismiss()
    }
}

// MARK: - Friend Item Detail View

struct FriendItemDetailView: View {
    let item: CKWishlistItem
    let isPurchased: Bool
    let onTogglePurchase: () -> Void
    @Environment(\.dismiss) private var dismiss

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
                    if item.isPurchased, let purchasedAt = item.purchasedAt {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.successGreen)
                            Text("Checked off \(purchasedAt.formatted(date: .abbreviated, time: .omitted))")
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

                    // URL Link
                    if let url = item.url, !url.isEmpty, let urlObj = URL(string: url) {
                        Link(destination: urlObj) {
                            HStack {
                                Image(systemName: "link")
                                Text("Visit Link")
                            }
                            .font(.bodyLarge)
                            .fontWeight(.semibold)
                            .foregroundColor(.forestGreen)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.md)
                            .background(Color.creamCard)
                            .cornerRadius(CornerRadius.md)
                            .shadow(
                                color: DesignShadow.medium,
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                        }
                    }

                    // Purchase toggle button
                    // Purchase toggle button
                    Button(action: {
                        HapticManager.buttonTapped()
                        onTogglePurchase()
                        dismiss()
                    }) {
                        if isPurchased {
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
                    .padding(.top, Spacing.md)
                }
                .padding(Spacing.lg)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Friend Wishlist Item Row
struct FriendWishlistItemRow: View {
    let item: CKWishlistItem
    let isPurchased: Bool
    @AppStorage("showPurchasedItems") private var showPurchasedItems = true

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Photo on the left (or spacer to maintain alignment)
            if item.imageData != nil {
                WishlistItemPhoto(
                    imageData: item.imageData,
                    showCheckmark: showPurchasedItems && isPurchased
                )
            } else {
                // Reserve space to keep text aligned
                ZStack {
                    Color.clear
                        .frame(width: 84, height: 84)

                    // Show checkmark in the reserved space if purchased
                    if showPurchasedItems && isPurchased {
                        Image(systemName: "checkmark")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.successGreen)
                    }
                }
            }

            // Item name
            Text(item.name)
                .font(.custom("Caveat", size: 27))
                .lineSpacing(-18)
                .foregroundColor(.warmBlack)
                .lineLimit(2)

            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .cornerRadius(CornerRadius.md)
        .shadow(
            color: DesignShadow.soft,
            radius: 6,
            x: 0,
            y: 2
        )
    }
}

#Preview {
    NavigationStack {
        FriendWishlistView(
            friend: Friend(
                name: "Grace",
                hasApp: true,
                friendUserRecordID: "testID"
            ),
            child: nil
        )
        .modelContainer(for: Friend.self, inMemory: true)
    }
}
