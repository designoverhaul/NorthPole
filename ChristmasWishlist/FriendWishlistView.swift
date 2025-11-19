//
//  FriendWishlistView.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI
import CloudKit

struct FriendWishlistView: View {
    let friend: CKFriend
    let child: CKChild?

    @StateObject private var cloudKit = CloudKitManager.shared
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
    @State private var updatedFriend: CKFriend?
    @State private var isCheckingForApp = false
    @Environment(\.dismiss) private var dismiss

    init(friend: CKFriend, child: CKChild? = nil) {
        self.friend = friend
        self.child = child
    }

    private var currentFriend: CKFriend {
        updatedFriend ?? friend
    }

    private var displayName: String {
        child?.name ?? currentFriend.name
    }

    private var ownerRecordID: String? {
        if let child = child {
            return child.id
        }
        return currentFriend.friendUserRecordID
    }

    var body: some View {
        ZStack {
            Color.creamBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if isCheckingForApp {
                    ProgressView("Checking if friend has app...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .gold))
                        .scaleEffect(1.5)
                        .padding()
                } else if !currentFriend.hasApp {
                    noAppView
                } else if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .gold))
                        .scaleEffect(1.5)
                        .padding()
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
                                        isPurchased: purchases[item.id] != nil,
                                        onTogglePurchase: {
                                            togglePurchase(item)
                                        }
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
                    }
                }
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
                    if let child = child {
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
        .onAppear {
            Task {
                // If friend doesn't have app, check if they've installed it since we last checked
                if !friend.hasApp {
                    await checkIfFriendHasApp()
                }

                // Only load items if friend has the app
                if currentFriend.hasApp {
                    await loadItems()
                }
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

            Text("No wishlist available")
                .font(.headingMedium)
                .foregroundColor(.warmGray)

            Text("\(currentFriend.name) hasn't joined\nChristmas Wishlist yet")
                .font(.bodyMedium)
                .foregroundColor(.warmGray)
                .multilineTextAlignment(.center)

            Button(action: {
                HapticManager.buttonTapped()
                showingShareSheet = true
            }) {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text("Invite \(String(currentFriend.name.split(separator: " ").first ?? ""))")
                }
            }
            .buttonStyle(SecondaryButtonStyle())
            .padding(.top, Spacing.md)

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
            let discoveredRecordID = try await cloudKit.discoverUser(
                phoneNumber: friend.phoneNumber,
                email: friend.email
            )

            // If we found them, update the friend record
            if let recordID = discoveredRecordID {
                print("✅ Found \(friend.name)! They have the app now. Record ID: \(recordID.recordName)")

                // Update the friend record in CloudKit
                friend.record["friendUserRecordID"] = recordID.recordName

                // Save the updated friend record
                do {
                    let container = CKContainer.default()
                    let database = container.privateCloudDatabase
                    _ = try await database.save(friend.record)

                    // Update local state
                    let refreshedFriend = CKFriend(from: friend.record)
                    await MainActor.run {
                        updatedFriend = refreshedFriend
                    }

                    print("✅ Updated friend record. hasApp = \(refreshedFriend.hasApp)")
                } catch {
                    print("❌ Error updating friend record: \(error)")
                }
            } else {
                print("❌ \(friend.name) hasn't installed the app yet")
            }
        } catch {
            print("❌ Error checking if friend has app: \(error)")
        }
    }

    private func loadItems() async {
        // Only load if owner has a record ID
        guard let recordID = ownerRecordID else {
            items = []
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let records = try await cloudKit.fetchFriendWishlistItems(friendRecordID: recordID)
            let loadedItems = records.map { CKWishlistItem(from: $0) }

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
                    print("⚠️ Error loading purchases for item \(item.id): \(error)")
                }
            }

            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                items = loadedItems
                purchases = purchaseDict
            }
        } catch {
            errorMessage = "Failed to load wishlist: \(error.localizedDescription)"
        }
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
            } catch {
                errorMessage = "Failed to update item: \(error.localizedDescription)"
                HapticManager.errorOccurred()
            }
        }
    }

    private func createInviteMessage() -> String {
        let firstName = String(friend.name.split(separator: " ").first ?? "")
        return """
        I have a wishlist here if you are interested. I would like to see yours as well. Get the list here:

        https://apps.apple.com/app/id6755366177
        """
    }

    private func deleteFriend() {
        Task {
            do {
                try await cloudKit.deleteFriend(friend.record.recordID)
                HapticManager.itemDeleted()

                // Trigger friends list refresh
                await MainActor.run {
                    cloudKit.shouldRefreshFriends.toggle()
                }

                dismiss()
            } catch {
                errorMessage = "Failed to remove friend: \(error.localizedDescription)"
                HapticManager.errorOccurred()
            }
        }
    }

    private func hideChild() {
        guard let child = child else { return }

        Task {
            do {
                try await cloudKit.hideChildFromFriend(friendRecordID: friend.record.recordID, childRecordID: child.id)
                HapticManager.buttonTapped()

                // Trigger friends list refresh
                await MainActor.run {
                    cloudKit.shouldRefreshFriends.toggle()
                }

                dismiss()
            } catch {
                errorMessage = "Failed to hide child: \(error.localizedDescription)"
                HapticManager.errorOccurred()
            }
        }
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
                            .background(Color.creamCard)
                            .cornerRadius(CornerRadius.md)
                    }

                    // URL Link
                    if let url = item.url, !url.isEmpty, let urlObj = URL(string: url) {
                        Link(destination: urlObj) {
                            HStack {
                                Image(systemName: "link")
                                Text("Visit Link")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                            }
                            .font(.bodyMedium)
                            .fontWeight(.medium)
                            .foregroundColor(.forestGreen)
                            .padding(Spacing.md)
                            .background(Color.creamCard)
                            .cornerRadius(CornerRadius.md)
                        }
                    }

                    // Purchase toggle button
                    Button(action: {
                        HapticManager.buttonTapped()
                        onTogglePurchase()
                        dismiss()
                    }) {
                        HStack {
                            Text("🎁")
                                .font(.system(size: 20))
                            Text(item.isPurchased ? "Mark as Not Purchased" : "Mark as Purchased")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
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
    let onTogglePurchase: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Checkmark circle on the left
            Button(action: onTogglePurchase) {
                Image(systemName: isPurchased ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28))
                    .foregroundColor(isPurchased ? .successGreen : .warmGrayLight)
            }
            .buttonStyle(PlainButtonStyle())

            // Item name
            Text(item.name)
                .font(.custom("Caveat", size: 32))
                .lineSpacing(-18)
                .foregroundColor(.warmBlack)
                .lineLimit(2)

            Spacer()

            // Chevron on the right
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.warmGrayLight)
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
            friend: CKFriend(
                from: {
                    let record = CKRecord(recordType: "Friend")
                    record["name"] = "Grace"
                    record["ownerID"] = "test"
                    record["friendUserRecordID"] = "testID"
                    record["addedAt"] = Date()
                    return record
                }(),
                children: []
            ),
            child: nil
        )
    }
}
