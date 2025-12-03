//
//  MyWishlistView.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData
import CloudKit

struct MyWishlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WishlistItem.createdAt, order: .reverse) private var items: [WishlistItem]
    @State private var children: [CKChild] = []
    @ObservedObject private var cloudKit = CloudKitManager.shared

    @State private var showingAddGift = false
    @State private var itemToEdit: WishlistItem?
    @State private var currentUserId: UUID = {
        // Try to load existing user ID, or create new one
        if let existingId = AppGroupContainer.getCurrentUserId() {
            return existingId
        } else {
            let newId = UUID()
            AppGroupContainer.saveCurrentUserId(newId)
            return newId
        }
    }()
    @State private var selectedProfileId: UUID?
    @State private var showSuccessSparkle = false

    // Share wishlist state
    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
    @State private var showingError = false
    @State private var errorMessage: String?

    var myItems: [WishlistItem] {
        let targetId = selectedProfileId ?? currentUserId
        let filtered = items.filter { $0.ownerId == targetId }
        return filtered
    }

    var titleText: String {
        if let selectedId = selectedProfileId, selectedId != currentUserId {
            // selectedProfileId is a UUID, but CKChild.id is a CloudKit record ID string
            // Try to match by converting
            if let child = children.first(where: { UUID(uuidString: $0.id) == selectedId }) {
                return "\(child.name)'s Wishlist"
            }
        }
        return "My Wishlist"
    }

    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: shareWishlist) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.forestGreen)
                        }
                    }
                }
                .sheet(isPresented: $showingAddGift) {
                    AddGiftView(userId: selectedProfileId ?? currentUserId, onItemAdded: {
                        showSuccessSparkle = true
                    })
                }
                .sheet(item: $itemToEdit) { item in
                    AddGiftView(userId: selectedProfileId ?? currentUserId, onItemAdded: {
                        showSuccessSparkle = true
                    }, itemToEdit: item)
                }
                .sheet(isPresented: $showingShareSheet) {
                    ShareSheet(activityItems: shareItems)
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
            // Load children from CloudKit
            await loadChildren()
        }
        .onChange(of: cloudKit.shouldRefreshChildren) { _, _ in
            Task {
                await loadChildren()
            }
        }
        .onChange(of: cloudKit.isSignedInToiCloud) { _, newValue in
            if newValue {
                Task {
                    await loadChildren()
                }
            }
        }
        .onAppear {
            // Ensure selection is valid
            if selectedProfileId == nil {
                selectedProfileId = currentUserId
            }
            
            // Load children on appear as well (in case task hasn't run yet)
            Task {
                await loadChildren()
            }
        }
    }

    private var mainContent: some View {
        ZStack {
            // Background
            Color.creamBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Headline
                Text(titleText)
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.gold, Color.goldShimmer, Color.gold],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color.gold.opacity(0.3), radius: 2, x: 0, y: 1)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.sm)
                
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

            // Success sparkle overlay
            if showSuccessSparkle {
                SuccessSparkle {
                    showSuccessSparkle = false
                }
                .allowsHitTesting(false)
            }
        }
    }

    private var profilePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "Me" pill
                ProfilePill(
                    name: "Me",
                    isSelected: selectedProfileId == nil || selectedProfileId == currentUserId,
                    action: {
                        HapticManager.buttonTapped()
                        selectedProfileId = currentUserId
                    }
                )

                // Children pills
                ForEach(children) { child in
                    ProfilePill(
                        name: child.name,
                        isSelected: selectedProfileId == UUID(uuidString: child.id),
                        action: {
                            HapticManager.buttonTapped()
                            selectedProfileId = UUID(uuidString: child.id)
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
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(myItems) { item in
                    WishlistItemRow(
                        item: item,
                        showPurchaseButton: false,
                        onDelete: {
                            deleteItem(item)
                        },
                        onTogglePurchase: nil
                    )
                    .onTapGesture {
                        HapticManager.buttonTapped()
                        itemToEdit = item
                    }
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                }
            }
            .padding(Spacing.md)
            .padding(.bottom, 80) // Space for FAB
        }
    }

    private var floatingActionButton: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                FloatingActionButton(
                    action: {
                        HapticManager.buttonTapped()
                        showingAddGift = true
                    },
                    icon: "plus"
                )
                .sparkle(isActive: true)
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
    }

    private func deleteItem(_ item: WishlistItem) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            HapticManager.itemDeleted()
            modelContext.delete(item)
        }
    }

    // Sync from CloudKit
    private func syncFromCloudKit() {
        print("⚡ [MANUAL SYNC] User triggered manual sync from CloudKit")
        HapticManager.buttonTapped()

        Task {
            await downloadAllItemsFromCloudKit()
        }
    }

    @MainActor
    private func downloadAllItemsFromCloudKit() async {
        print("📥 [MANUAL SYNC] Downloading all items from CloudKit...")

        guard cloudKit.isSignedInToiCloud else {
            print("⚠️ [MANUAL SYNC] Not signed in to iCloud")
            errorMessage = "Please sign in to iCloud to sync your wishlist"
            showingError = true
            return
        }

        do {
            // Fetch MY items from CloudKit
            let myRecords = try await cloudKit.fetchMyWishlistItems()
            print("📥 [MANUAL SYNC] Fetched \(myRecords.count) items from CloudKit")

            // Fetch children from CloudKit
            let childRecords = try await cloudKit.fetchMyChildren()
            print("📥 [MANUAL SYNC] Fetched \(childRecords.count) children from CloudKit")

            // Create/update children in SwiftData
            for childRecord in childRecords {
                let childName = childRecord["name"] as? String ?? "Unknown"
                let cloudKitRecordID = childRecord.recordID.recordName

                // Check if child already exists
                let childDescriptor = FetchDescriptor<Child>(
                    predicate: #Predicate { $0.cloudKitRecordID == cloudKitRecordID }
                )
                let existingChildren = try modelContext.fetch(childDescriptor)

                if existingChildren.isEmpty {
                    // Create new child
                    let newChild = Child(
                        name: childName,
                        parentId: currentUserId,
                        cloudKitRecordID: cloudKitRecordID
                    )
                    modelContext.insert(newChild)
                    print("📥 [MANUAL SYNC] Created child '\(childName)'")
                }
            }

            try modelContext.save()

            // Re-fetch children to get IDs
            let updatedChildDescriptor = FetchDescriptor<Child>()
            let allChildren = try modelContext.fetch(updatedChildDescriptor)

            // Create/update items in SwiftData
            for record in myRecords {
                let itemName = record["name"] as? String ?? "Unknown"
                let itemURL = record["url"] as? String
                let itemDescription = record["itemDescription"] as? String
                let ownerRef = record["ownerID"] as? CKRecord.Reference
                let ownerRecordID = ownerRef?.recordID.recordName

                // Determine local owner (user or child)
                var localOwnerID = currentUserId // Default to current user

                // If this item has an owner that's NOT the current user, it must be a child
                if let ownerRecordID = ownerRecordID,
                   ownerRecordID != cloudKit.currentUserRecordID?.recordName {
                    // Find the child with this CloudKit record ID
                    if let child = allChildren.first(where: { $0.cloudKitRecordID == ownerRecordID }) {
                        localOwnerID = child.id
                        print("📥 [MANUAL SYNC] Item '\(itemName)' belongs to child '\(child.name)'")
                    }
                }

                // Check if item already exists by name (simple deduplication)
                let itemDescriptor = FetchDescriptor<WishlistItem>(
                    predicate: #Predicate { $0.name == itemName && $0.ownerId == localOwnerID }
                )
                let existingItems = try modelContext.fetch(itemDescriptor)

                if existingItems.isEmpty {
                    // Create new item
                    let newItem = WishlistItem(
                        name: itemName,
                        url: itemURL,
                        itemDescription: itemDescription,
                        ownerId: localOwnerID
                    )
                    modelContext.insert(newItem)
                    print("📥 [MANUAL SYNC] Created item '\(itemName)' for owner \(localOwnerID)")
                }
            }

            try modelContext.save()
            print("✅ [MANUAL SYNC] Synced \(myRecords.count) items from CloudKit")

            HapticManager.notification(.success)
        } catch {
            print("❌ [MANUAL SYNC] Failed: \(error)")
            errorMessage = "Sync failed: \(error.localizedDescription)"
            showingError = true
            HapticManager.errorOccurred()
        }
    }

    // Share wishlist function
    private func shareWishlist() {
        HapticManager.buttonTapped()
        
        // Check if there are items to share
        guard !myItems.isEmpty else {
            errorMessage = "Add some items to your wishlist before sharing!"
            showingError = true
            HapticManager.errorOccurred()
            return
        }
        
        // Format the wishlist as text
        var shareText = "\(titleText)\n\n"
        
        for (index, item) in myItems.enumerated() {
            shareText += "\(index + 1). \(item.name)\n"
            
            // Add URL if available
            if let url = item.url {
                shareText += "   \(url)\n"
            }
            
            shareText += "\n"
        }
        
        // Add app promotion
        shareText += "━━━━━━━━━━━━━━━━━━━━\n\n"
        shareText += "🎄 Create your own wishlist!\n"
        shareText += "Download North Pole Wishlist app\n"
        shareText += "https://apps.apple.com/us/app/north-pole-christmas-lists/id6755366177\n"
        
        // Prepare share items
        shareItems = [shareText]
        showingShareSheet = true
    }
    
    private func loadChildren() async {
        guard cloudKit.isSignedInToiCloud else { return }
        
        do {
            let records = try await cloudKit.fetchMyChildren()
            await MainActor.run {
                children = records.map { CKChild(from: $0) }
                print("✅ [MYWISHLIST] Loaded \(children.count) children from CloudKit")
            }
        } catch {
            print("❌ [MYWISHLIST] Error loading children: \(error)")
        }
    }
}

#Preview {
    MyWishlistView()
        .modelContainer(for: [WishlistItem.self])
}
