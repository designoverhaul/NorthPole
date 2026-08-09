//
//  FriendWishlistView.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.designoverhaul.ChristmasWishlist", category: "FriendWishlist")

struct FriendWishlistView: View {
    let friend: Friend
    let childId: String?
    let childName: String?

    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var firebase = FirebaseManager.shared
    @Query private var cachedItems: [WishlistItem]
    @State private var isSyncing = false
    @State private var errorMessage: String?
    @State private var purchasedItemIdForSparkle: String? = nil
    @State private var showFallingSnow: Bool = false
    @State private var showingShareSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingHideChildAlert = false
    @State private var showingPurchaseConfirmation = false
    @State private var itemToPurchase: WishlistItem?
    @State private var isCheckingForApp = false
    @Environment(\.dismiss) private var dismiss

    init(friend: Friend, childId: String? = nil, childName: String? = nil) {
        self.friend = friend
        self.childId = childId
        self.childName = childName

        let normalizedPhone = PhoneNumber.normalize(friend.phoneNumber ?? "")
        let childFilter = childId ?? ""

        if childFilter.isEmpty {
            let predicate = #Predicate<WishlistItem> { item in
                item.ownerPhone == normalizedPhone &&
                item.isOwnedByCurrentUser == false &&
                item.childId == ""
            }
            _cachedItems = Query(filter: predicate, sort: \.createdAt, order: .reverse)
        } else {
            let predicate = #Predicate<WishlistItem> { item in
                item.ownerPhone == normalizedPhone &&
                item.isOwnedByCurrentUser == false &&
                item.childId == childFilter
            }
            _cachedItems = Query(filter: predicate, sort: \.createdAt, order: .reverse)
        }
    }

    private var displayName: String {
        childName ?? friend.name
    }

    private var friendFirstName: String {
        String(friend.name.split(separator: " ").first ?? "")
    }
    
    private var ownerPhone: String? {
        friend.phoneNumber.map(PhoneNumber.normalize)
    }

    private var mainContent: some View {
        ZStack {
            Color.creamBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    if isCheckingForApp {
                        SnowflakeLoadingView("Checking if friend has app...")
                            .padding()
                    } else if !friend.hasApp {
                        noAppView
                    } else if cachedItems.isEmpty {
                        emptyWishlistView
                    } else {
                        wishlistContent
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var wishlistContent: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                // Create local snapshot like MyWishlistView
                let items = Array(cachedItems)

                ForEach(items, id: \.id) { item in
                    let itemIdString = item.id.uuidString

                    NavigationLink {
                        FriendItemDetailView(item: item)
                    } label: {
                        FriendWishlistItemRow(
                            item: item,
                            isPurchased: item.isPurchased,
                            giftIndex: computeGiftIndex(for: item, in: items),
                            showSparkle: purchasedItemIdForSparkle == itemIdString,
                            onSparkleComplete: {
                                purchasedItemIdForSparkle = nil
                            }
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(Spacing.md)
            .padding(.bottom, 80)
        }
        .refreshable {
            if let ownerPhone = ownerPhone {
                try? await firebase.syncFriendWishlist(
                    ownerPhone: ownerPhone,
                    childId: childId,
                    forceRefresh: true,
                    context: modelContext
                )
            }
        }
    }

    var body: some View {
        mainContent
            .navigationTitle("")
            .friendNameTitle(displayName)
            .toolbar { toolbarContent }
            .task { await onAppearTask() }
            .sheet(isPresented: $showingShareSheet) { shareSheetContent }
            .alert("Remove Friend", isPresented: $showingDeleteAlert) { deleteFriendAlert }
            .alert("Hide Child", isPresented: $showingHideChildAlert) { hideChildAlert }
            .alert(purchaseAlertTitle, isPresented: $showingPurchaseConfirmation) { purchaseConfirmAlert }
            .alert("Error", isPresented: .constant(errorMessage != nil)) { errorAlert }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                if childId != nil {
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
                        Label("Invite \(friendFirstName)", systemImage: "paperplane.fill")
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

    private func onAppearTask() async {
        logger.info("👁️ [APPEAR] FriendWishlistView appeared for \(friend.name)")
        logger.info("👁️ [APPEAR] hasApp: \(friend.hasApp), childId: \(childId ?? "nil")")

        if !friend.hasApp {
            logger.info("👁️ [APPEAR] Friend doesn't have app, checking...")
            await checkIfFriendHasApp()
        }

        if friend.hasApp, let ownerPhone = ownerPhone {
            logger.info("👁️ [APPEAR] Triggering background sync...")
            Task {
                try? await firebase.syncFriendWishlist(
                    ownerPhone: ownerPhone,
                    childId: childId,
                    forceRefresh: false,
                    context: modelContext
                )
            }
        }
    }

    private var shareSheetContent: some View {
        ShareSheet(activityItems: [createInviteMessage()])
    }

    private var deleteFriendAlert: some View {
        Group {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                deleteFriend()
            }
        }
    }

    private var hideChildAlert: some View {
        Group {
            Button("Cancel", role: .cancel) {}
            Button("Hide", role: .destructive) {
                hideChild()
            }
        }
    }

    private var purchaseAlertTitle: String {
        if let item = itemToPurchase {
            return item.isPurchased
                ? String(localized: "Mark \(item.name) as unpurchased?")
                : String(localized: "Mark \(item.name) as purchased?")
        }
        return String(localized: "Mark item as purchased?")
    }

    private var purchaseConfirmAlert: some View {
        Group {
            Button("Cancel", role: .cancel) {
                itemToPurchase = nil
            }
            Button((itemToPurchase?.isPurchased == true) ? "Unmark" : "Purchased", role: .none) {
                confirmPurchaseToggle()
                itemToPurchase = nil
            }
        }
    }

    private var errorAlert: some View {
        Button("OK") {
            errorMessage = nil
        }
    }

    private var noAppView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "app.gift")
                .font(.system(size: 72))
                .foregroundColor(.warmGrayLight)

            Text("\(friend.name) has not installed this app yet")
                .font(.headingMedium)
                .foregroundColor(.warmGray)
                .multilineTextAlignment(.center)

            Button(action: {
                HapticManager.buttonTapped()
                showingShareSheet = true
            }) {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text("Invite \(friendFirstName)")
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

        logger.info("🔍 Checking if \(friend.name) has installed the app...")

        guard let phone = friend.phoneNumber else { return }

        do {
            let hasApp = try await firebase.checkIfFriendHasApp(friendPhone: phone)

            if hasApp {
                logger.info("✅ Found \(friend.name)! They have the app now.")
                await MainActor.run {
                    friend.hasApp = true
                    try? modelContext.save()
                }
            } else {
                logger.info("❌ \(friend.name) hasn't installed the app yet")
            }
        } catch {
            logger.error("❌ Error checking if friend has app: \(error)")
        }
    }

    private func togglePurchase(_ item: WishlistItem) {
        logger.info("🔴 [FREEZE-DEBUG] togglePurchase() called for item: \(item.name)")
        itemToPurchase = item
        showingPurchaseConfirmation = true
    }

    private func confirmPurchaseToggle() {
        logger.info("🟣 [FREEZE-DEBUG] confirmPurchaseToggle() called")
        guard let item = itemToPurchase else { return }
        HapticManager.buttonTapped()

        Task {
            do {
                let itemId = item.id.uuidString
                let wasPurchased = item.isPurchased

                if wasPurchased {
                    guard let userPhone = FirebaseAuthManager.shared.currentUserPhone else {
                        throw FirebaseError.notAuthenticated
                    }

                    let purchasesWithIds = try await firebase.fetchPurchasesForItemWithIds(itemId: itemId)
                    if let (purchaseId, _) = purchasesWithIds.first(where: {
                        PhoneNumber.matches($0.purchase.purchaserPhone, userPhone)
                    }) {
                        try await firebase.deletePurchase(purchaseId: purchaseId, itemId: itemId)
                        await MainActor.run {
                            item.isPurchased = false
                            try? modelContext.save()
                            HapticManager.impact(.medium)
                        }
                        logger.info("✅ Unmarked item as purchased")
                    }
                } else {
                    guard let ownerPhone = ownerPhone else { return }

                    _ = try await firebase.savePurchase(
                        itemId: itemId,
                        itemName: item.name,
                        ownerPhone: ownerPhone
                    )

                    await MainActor.run {
                        item.isPurchased = true
                        try? modelContext.save()
                        HapticManager.itemMarkedPurchased()
                        purchasedItemIdForSparkle = itemId
                    }

                    ReviewManager.shared.markFirstPurchase()

                    logger.info("✅ Marked item as purchased")
                }
            } catch {
                errorMessage = String(localized: "Failed to update item: \(error.localizedDescription)")
                HapticManager.errorOccurred()
                logger.error("❌ Failed to toggle purchase: \(error)")
            }
        }
    }

    /// Only the App Store link goes out. A `christmaswishlist://` add-friend link
    /// is not tappable in Messages, and the friend edge we already created is
    /// enough for their list to appear here once they sign in with this number.
    private func createInviteMessage() -> String {
        String(localized: """
        I have a wishlist here if you are interested. I would like to see yours as well.

        Get the app: https://apps.apple.com/app/id6755366177
        """)
    }

    private func deleteFriend() {
        modelContext.delete(friend)
        try? modelContext.save()
        HapticManager.itemDeleted()

        if let firebaseId = friend.firebaseFriendshipId {
            Task {
                do {
                    try await firebase.deleteFriend(friendId: firebaseId)
                    logger.info("✅ [DELETE_FRIEND] Deleted friend from Firebase: \(friend.name)")
                } catch {
                    logger.error("❌ [DELETE_FRIEND] Failed to delete from Firebase: \(error)")
                }
            }
        }

        dismiss()
    }

    private func hideChild() {
        guard let childId = childId else { return }

        if !friend.hiddenChildRecordIDs.contains(childId) {
            friend.hiddenChildRecordIDs.append(childId)
        }
        try? modelContext.save()

        if let friendshipId = friend.firebaseFriendshipId {
            Task {
                try? await firebase.updateFriendHiddenChildren(
                    friendshipId: friendshipId,
                    hiddenChildren: friend.hiddenChildRecordIDs
                )
            }
        }

        HapticManager.buttonTapped()
        dismiss()
    }
    
    private func computeGiftIndex(for item: WishlistItem, in allItems: [WishlistItem]) -> Int? {
        guard item.isPurchased else { return nil }

        let purchasedItems = allItems
            .filter(\.isPurchased)
            .sorted { $0.createdAt < $1.createdAt }

        return purchasedItems.firstIndex(where: { $0.id == item.id })
    }
}

// MARK: - Friend Item Detail View

struct FriendItemDetailView: View {
    let item: WishlistItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var firebase = FirebaseManager.shared
    @State private var isPurchased: Bool = false
    @State private var isLoading: Bool = false

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
                    Button(action: {
                        Task {
                            await togglePurchase()
                        }
                    }) {
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .tint(.white)
                                Text("Loading...")
                            }
                            .font(.bodyLarge)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.md)
                            .background(Color.forestGreen.opacity(0.6))
                            .cornerRadius(CornerRadius.md)
                        } else if isPurchased {
                            Text("Unpurchase Item")
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
                    .disabled(isLoading)
                }
                .padding(Spacing.lg)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPurchaseStatus()
        }
    }

    private func loadPurchaseStatus() async {
        await MainActor.run {
            isPurchased = item.isPurchased
        }
    }

    private func togglePurchase() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let itemId = item.id.uuidString

            if isPurchased {
                guard let userPhone = FirebaseAuthManager.shared.currentUserPhone else { return }
                let purchasesWithIds = try await firebase.fetchPurchasesForItemWithIds(itemId: itemId)
                if let (purchaseId, _) = purchasesWithIds.first(where: {
                    PhoneNumber.matches($0.purchase.purchaserPhone, userPhone)
                }) {
                    try await firebase.deletePurchase(purchaseId: purchaseId, itemId: itemId)
                    await MainActor.run {
                        item.isPurchased = false
                        isPurchased = false
                        try? modelContext.save()
                        HapticManager.impact(.medium)
                    }
                }
            } else {
                guard !item.ownerPhone.isEmpty else { return }
                _ = try await firebase.savePurchase(
                    itemId: itemId,
                    itemName: item.name,
                    ownerPhone: item.ownerPhone
                )
                await MainActor.run {
                    item.isPurchased = true
                    isPurchased = true
                    try? modelContext.save()
                    HapticManager.itemMarkedPurchased()
                }

                ReviewManager.shared.markFirstPurchase()
            }
        } catch {
            print("Failed to toggle purchase: \(error)")
            HapticManager.errorOccurred()
        }
    }
}

// MARK: - Friend Wishlist Item Row

struct FriendWishlistItemRow: View {
    let item: WishlistItem
    let isPurchased: Bool
    let giftIndex: Int?
    let showSparkle: Bool
    let onSparkleComplete: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Photo on the left (or spacer to maintain alignment)
            // For friends' wishlists: ALWAYS show gift when purchased (ignore showPurchasedItems setting)
            if item.imageData != nil || isPurchased {
                ZStack(alignment: .center) {
                    WishlistItemPhoto(
                        imageData: item.imageData,
                        isPurchased: isPurchased,
                        itemId: item.id.uuidString,
                        giftIndex: giftIndex
                    )
                    
                    // Sparkle overlay on the gift image
                    if showSparkle {
                        SuccessSparkle {
                            onSparkleComplete()
                        }
                        .allowsHitTesting(false)
                    }
                }
            } else {
                // Reserve space to keep text aligned
                Color.clear
                    .frame(width: 84, height: 84)
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
                phoneNumber: "1234567890",
                hasApp: true
            ),
            childId: nil,
            childName: nil
        )
        .modelContainer(for: Friend.self, inMemory: true)
    }
}
