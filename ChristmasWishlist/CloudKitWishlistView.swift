//
//  CloudKitWishlistView.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI
import CloudKit

struct CloudKitWishlistView: View {
    @ObservedObject private var cloudKit = CloudKitManager.shared
    @State private var items: [CKWishlistItem] = []
    @State private var purchases: [String: CKPurchase] = [:]
    @State private var showingAddGift = false
    @State private var itemToEdit: CKWishlistItem?
    @State private var showSuccessSparkle = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasLoadedOnce = false
    @State private var children: [CKChild] = []
    @State private var selectedOwnerID: String?  // nil = current user, non-nil = child recordID
    @State private var refreshTask: Task<Void, Never>?
    @AppStorage("showPurchasedItems") private var showPurchasedItems = true
    @AppStorage("userName") private var userName = ""
    @State private var showingNamePrompt = false
    @State private var showingShareConfirmation = false
    @State private var tempName = ""

    var isActive: Bool = true

    private var selectedOwnerName: String {
        if let selectedOwnerID = selectedOwnerID,
           let child = children.first(where: { $0.id == selectedOwnerID }) {
            return child.name
        }
        return "Me"
    }

    private var displayedItems: [CKWishlistItem] {
        // Filter items based on selected owner (Me or a Child)
        if let selectedOwnerID = selectedOwnerID {
            return items.filter { $0.ownerID == selectedOwnerID }
        } else {
            // Show current user's items when "Me" is selected
            guard let userRecordID = cloudKit.currentUserRecordID else {
                return []
            }
            return items.filter { $0.ownerID == userRecordID.recordName }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Owner selector (Me + Children)
                    if cloudKit.isSignedInToiCloud && !children.isEmpty {
                        Picker("Wishlist For", selection: $selectedOwnerID) {
                            Text("Me").tag(nil as String?)
                            ForEach(children) { child in
                                Text(child.name).tag(child.id as String?)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.creamBackground)
                    }

                    // Content area - always takes full space below picker
                    ZStack {
                        if !cloudKit.isSignedInToiCloud {
                            notSignedInView
                        } else if displayedItems.isEmpty && isLoading {
                            // Only show full screen loader if we have NO items
                            VStack {
                                Spacer()
                                SnowflakeLoadingView("Loading wishlist...")
                                Spacer()
                            }
                        } else if displayedItems.isEmpty {
                            emptyStateView
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 2) {
                                    ForEach(displayedItems) { item in
                                        NavigationLink {
                                            CloudKitItemDetailView(
                                                item: item,
                                                purchase: purchases[item.id],
                                                onEdit: {
                                                    itemToEdit = item
                                                },
                                                onDelete: {
                                                    deleteItem(item)
                                                }
                                            )
                                        } label: {
                                            CloudKitItemRow(item: item, purchase: purchases[item.id])
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
                        }
                        
                        // Non-blocking loading indicator at the bottom
                        if isLoading && !displayedItems.isEmpty {
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

                // Floating Action Button
                if cloudKit.isSignedInToiCloud {
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

                // Success sparkle
                if showSuccessSparkle {
                    SuccessSparkle {
                        showSuccessSparkle = false
                    }
                    .allowsHitTesting(false)
                }
            }
            .navigationTitle("")
            .goldTitleWithMenu(children.isEmpty ? "My Wishlist" : "Our Wishlists") {
                Button(action: {
                    HapticManager.buttonTapped()
                    // Check if we have a name set
                    if userName.isEmpty {
                        tempName = ""
                        showingNamePrompt = true
                    } else {
                        showingShareConfirmation = true
                    }
                }) {
                    Label("Your list missing for others?", systemImage: "square.and.arrow.up")
                }
            }
            .sheet(isPresented: $showingAddGift) {
                CloudKitAddGiftView(
                    ownerRecordID: selectedOwnerID,
                    ownerName: selectedOwnerName,
                    onItemAdded: { newItem in
                        // Optimistically add to UI immediately
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            items.insert(newItem, at: 0)
                        }
                        showSuccessSparkle = true

                        // Reload in background to sync with CloudKit
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                            await loadItems()
                        }
                    }
                )
            }
            .sheet(item: $itemToEdit) { item in
                CloudKitEditGiftView(
                    item: item,
                    onItemUpdated: { updatedItem in
                        // Optimistically update in UI immediately
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if let index = items.firstIndex(where: { $0.id == updatedItem.id }) {
                                items[index] = updatedItem
                            }
                        }

                        // Reload in background to sync with CloudKit
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                            await loadItems()
                        }
                    },
                    onItemDeleted: { deletedItemId in
                        // Optimistically remove from UI immediately
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            items.removeAll { $0.id == deletedItemId }
                        }

                        // Reload in background to sync with CloudKit
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                            await loadItems()
                        }
                    }
                )
            }
            .task {
                // Load on first appear
                if cloudKit.isSignedInToiCloud && !hasLoadedOnce {
                    await loadChildren()
                    await loadItems()
                    hasLoadedOnce = true
                }
            }
            .onDisappear {
                stopPeriodicRefresh()
            }
            .onChange(of: isActive) { _, active in
                if active {
                    // Refresh immediately when tab becomes active
                    Task {
                        await loadChildren()
                        await loadItems()
                    }
                    
                    // Start periodic refresh (background updates every 30s)
                    startPeriodicRefresh()
                } else {
                    // Stop periodic refresh when tab becomes inactive
                    stopPeriodicRefresh()
                }
            }
            .refreshable {
                print("🔄 [REFRESH] Pull-to-refresh triggered")
                await loadChildren()
                await loadItems()
                print("✅ [REFRESH] Pull-to-refresh completed with \(items.count) items")
            }
            .onChange(of: cloudKit.isSignedInToiCloud) { _, isSignedIn in
                // Load data immediately when CloudKit is ready, regardless of tab visibility
                // This ensures data is prefetched and ready when user switches tabs
                if isSignedIn {
                    Task {
                        await loadChildren()
                        await loadItems()
                        if !hasLoadedOnce {
                            hasLoadedOnce = true
                        }
                    }
                }
            }
            .onChange(of: cloudKit.shouldRefreshChildren) { oldValue, newValue in
                print("🔄 [WISHLIST] shouldRefreshChildren changed from \(oldValue) to \(newValue)")
                print("🔄 [WISHLIST] Current children count: \(children.count)")
                print("🔄 [WISHLIST] isActive: \(isActive), isSignedIn: \(cloudKit.isSignedInToiCloud)")
                
                Task { @MainActor in
                    print("🔄 [WISHLIST] Starting children refresh...")
                    let beforeCount = children.count
                    
                    await loadChildren()
                    
                    let afterCount = children.count
                    print("🔄 [WISHLIST] Children refresh complete: \(beforeCount) → \(afterCount)")
                    
                    // Log the children we have now
                    for child in children {
                        print("   - Child: \(child.name) (ID: \(child.id))")
                    }
                    
                    // If the selected child was deleted, switch back to "Me"
                    if let selectedId = selectedOwnerID, !children.contains(where: { $0.id == selectedId }) {
                        print("🔄 [WISHLIST] Selected child was deleted, switching to Me")
                        selectedOwnerID = nil
                    }
                    
                    // Always reload items when children change to show new child's items or remove deleted child's items
                    await loadItems()
                    print("🔄 [WISHLIST] Full refresh complete")
                }
            }
            .alert("Share Wishlist", isPresented: $showingShareConfirmation) {
                Button("Share as \(userName)") {
                    shareProfile()
                }
                Button("Change Name") {
                    tempName = userName
                    showingNamePrompt = true
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Friends will see this name when they view your wishlist.")
            }
            .alert("What's your name?", isPresented: $showingNamePrompt) {
                TextField("Enter your name", text: $tempName)
                Button("Cancel", role: .cancel) { }
                Button("Share") {
                    if !tempName.isEmpty {
                        userName = tempName
                        shareProfile()
                    }
                }
            } message: {
                Text("Your name will be shown when friends view your wishlist")
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

    private var notSignedInView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "icloud.slash")
                .font(.system(size: 72))
                .foregroundColor(.warmGrayLight)

            Text("Not signed in to iCloud")
                .font(.headingMedium)
                .foregroundColor(.warmGray)

            Text("Please sign in to iCloud in Settings\nto use ChristmasWishlist")
                .font(.bodyMedium)
                .foregroundColor(.warmGray)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task {
                    await cloudKit.checkiCloudStatus()
                    await loadItems()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top)

            Spacer()
        }
        .padding()
    }

    private func shareProfile() {
        if let url = DeepLinkManager.shared.generateInviteLink(name: userName) {
            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        }
    }

    private func loadChildren() async {
        guard cloudKit.isSignedInToiCloud else {
            print("⚠️ [WISHLIST] Cannot load children - not signed in")
            return
        }

        let startTime = Date()
        print("📥 [WISHLIST] Loading children...")
        
        do {
            let records = try await cloudKit.fetchMyChildren()
            await MainActor.run {
                children = records.map { CKChild(from: $0) }
                print("⏱️ [WISHLIST] Loaded \(children.count) children in \(Date().timeIntervalSince(startTime).formatted())s")
                for child in children {
                    print("   - \(child.name) (ID: \(child.id))")
                }
            }
        } catch let error as CKError where error.code == .unknownItem {
            // Record type doesn't exist yet - normal on first run
            print("☁️ [WISHLIST] Child record type not created yet")
            await MainActor.run {
                children = []
            }
        } catch {
            print("❌ [WISHLIST] Error loading children: \(error)")
            print("❌ [WISHLIST] Error type: \(type(of: error))")
        }
    }

    private func loadItems() async {
        // Wait for CloudKit to sign in first
        guard cloudKit.isSignedInToiCloud else {
            print("⚠️ [WISHLIST] Cannot load items - not signed in to iCloud")
            return
        }

        let startTime = Date()
        print("📥 [WISHLIST] Starting to load ALL items (current count: \(items.count))")
        print("📥 [WISHLIST] Current children count: \(children.count)")
        isLoading = true
        errorMessage = nil

        do {
            // Fetch items for current user
            print("👤 [WISHLIST] Fetching items for current user")
            guard let userRecordID = cloudKit.currentUserRecordID else {
                print("⚠️ [WISHLIST] No user record ID available")
                isLoading = false
                return
            }
            print("👤 [WISHLIST] User record ID: \(userRecordID.recordName)")
            let myRecords = try await cloudKit.fetchMyWishlistItems()

            // Fetch items for all children in parallel
            var allRecords = myRecords
            print("👶 [WISHLIST] Fetching items for \(children.count) children")
            await withTaskGroup(of: [CKRecord].self) { group in
                for child in children {
                    group.addTask {
                        do {
                            return try await self.cloudKit.fetchFriendWishlistItems(friendRecordID: child.id)
                        } catch {
                            print("⚠️ Error loading items for child \(child.name): \(error)")
                            return []
                        }
                    }
                }

                for await childRecords in group {
                    allRecords.append(contentsOf: childRecords)
                }
            }

            var loadedItems = allRecords.map { CKWishlistItem(from: $0) }
            print("📦 [WISHLIST] Fetched \(loadedItems.count) total items from CloudKit (user + children)")

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

            // Update UI with animation to ensure view refreshes
            await MainActor.run {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    items = loadedItems
                    purchases = purchaseDict
                }
                isLoading = false
            }
            print("⏱️ [WISHLIST] Loaded \(items.count) items in \(Date().timeIntervalSince(startTime).formatted())s")
            print("✅ [WISHLIST] UI updated with \(items.count) items, \(purchases.count) purchases")
        } catch {
            print("❌ [WISHLIST] Error loading items: \(error)")
            print("❌ [WISHLIST] Error type: \(type(of: error))")
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func deleteItem(_ item: CKWishlistItem) {
        // Optimistically remove from UI immediately
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            HapticManager.itemDeleted()
            items.removeAll { $0.id == item.id }
        }

        // Delete from CloudKit in background
        Task {
            do {
                try await cloudKit.deleteWishlistItem(item.record.recordID)
                print("✅ Item deleted successfully")
            } catch {
                print("❌ Error deleting item: \(error)")
                // Re-add item to UI on error
                await MainActor.run {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        items.append(item)
                        items.sort { $0.createdAt > $1.createdAt }
                    }
                }
                errorMessage = "Failed to delete item: \(error.localizedDescription)"
            }
        }
    }

    private func startPeriodicRefresh() {
        // Cancel existing task if any
        stopPeriodicRefresh()

        // Start new periodic refresh task
        refreshTask = Task {
            while !Task.isCancelled {
                // Wait 30 seconds
                try? await Task.sleep(nanoseconds: 30_000_000_000)

                // Check if still active and not cancelled
                guard !Task.isCancelled, isActive, cloudKit.isSignedInToiCloud else {
                    break
                }

                // Refresh wishlist and children
                await loadChildren()
                await loadItems()
            }
        }
    }

    private func stopPeriodicRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}

// MARK: - CloudKit Item Detail View

struct CloudKitItemDetailView: View {
    let item: CKWishlistItem
    let purchase: CKPurchase?
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage("showPurchasedItems") private var showPurchasedItems = true
    @State private var showingDeleteConfirmation = false

    private var isPurchased: Bool {
        purchase != nil
    }

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 0) {
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
                        Button(action: {
                            HapticManager.buttonTapped()
                            onEdit()
                            dismiss()
                        }) {
                            Text(item.name)
                                .font(.custom("Caveat", size: 35))
                                .foregroundColor(.warmBlack)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .buttonStyle(PlainButtonStyle())

                        // Purchase status badge (only show if user has enabled showing purchased items)
                        if showPurchasedItems && isPurchased, let purchase = purchase {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.successGreen)
                                Text("Checked off \(purchase.purchasedAt.formatted(date: .abbreviated, time: .omitted))")
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
                            Button(action: {
                                HapticManager.buttonTapped()
                                onEdit()
                                dismiss()
                            }) {
                                Text(description)
                                    .font(.bodyMedium)
                                    .foregroundColor(.warmGray)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(Spacing.md)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        // Visit Link button
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
                                .padding(.vertical, Spacing.md)
                                .padding(.horizontal, Spacing.lg)
                                .background(Color.forestGreen.opacity(0.1))
                                .cornerRadius(CornerRadius.md)
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.md)
                                        .stroke(Color.forestGreen.opacity(0.3), lineWidth: 1.5)
                                )
                            }
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
                            .foregroundColor(.warmGray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(Color.creamCard)
                            .cornerRadius(CornerRadius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .stroke(Color.warmGrayLight, lineWidth: 1.5)
                            )
                        }
                    }
                    .padding(Spacing.lg)
                    .padding(.bottom, 80)
                }
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

// MARK: - CloudKit Item Row

struct CloudKitItemRow: View {
    let item: CKWishlistItem
    let purchase: CKPurchase?
    @AppStorage("showPurchasedItems") private var showPurchasedItems = true

    private var isPurchased: Bool {
        purchase != nil
    }

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
    CloudKitWishlistView()
}
