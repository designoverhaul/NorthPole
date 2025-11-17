//
//  CloudKitWishlistView.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI
import CloudKit

struct CloudKitWishlistView: View {
    @StateObject private var cloudKit = CloudKitManager.shared
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

    var isActive: Bool = true

    private var selectedOwnerName: String {
        if let selectedOwnerID = selectedOwnerID,
           let child = children.first(where: { $0.id == selectedOwnerID }) {
            return child.name
        }
        return "Me"
    }

    private var displayedItems: [CKWishlistItem] {
        if showPurchasedItems {
            return items
        } else {
            return items.filter { purchases[$0.id] == nil }
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
                        .onChange(of: selectedOwnerID) { _, _ in
                            Task {
                                await loadItems()
                            }
                        }
                    }

                    // Content area - always takes full space below picker
                    ZStack {
                        if !cloudKit.isSignedInToiCloud {
                            notSignedInView
                        } else if isLoading {
                            VStack {
                                Spacer()
                                ProgressView("Loading wishlist...")
                                    .tint(.forestGreen)
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
            .goldTitle("My Wishlist")
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
                    if cloudKit.isSignedInToiCloud {
                        Task {
                            await loadChildren()
                            await loadItems()
                        }
                    }
                    // Start periodic refresh when tab becomes active
                    startPeriodicRefresh()
                } else {
                    // Stop periodic refresh when tab becomes inactive
                    stopPeriodicRefresh()
                }
            }
            .refreshable {
                await loadChildren()
                await loadItems()
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
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "gift")
                .font(.system(size: 72))
                .foregroundColor(.warmGrayLight)

            if items.isEmpty {
                Text("No items yet")
                    .font(.headingMedium)
                    .foregroundColor(.warmGray)

                Text("Tap the + button to add items\nto your wishlist")
                    .font(.bodyMedium)
                    .foregroundColor(.warmGray)
                    .multilineTextAlignment(.center)
            } else {
                Text("All items checked off!")
                    .font(.headingMedium)
                    .foregroundColor(.warmGray)

                Text("Looks like your friends are on it!\nYou've hidden purchased items in Settings.")
                    .font(.bodyMedium)
                    .foregroundColor(.warmGray)
                    .multilineTextAlignment(.center)
            }

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

    private func loadChildren() async {
        guard cloudKit.isSignedInToiCloud else {
            return
        }

        let startTime = Date()
        do {
            let records = try await cloudKit.fetchMyChildren()
            children = records.map { CKChild(from: $0) }
            print("⏱️ [WISHLIST] Loaded \(children.count) children in \(Date().timeIntervalSince(startTime).formatted())s")
        } catch let error as CKError where error.code == .unknownItem {
            // Record type doesn't exist yet - normal on first run
            print("☁️ CloudKit: Child record type not created yet")
            children = []
        } catch {
            print("❌ Error loading children: \(error)")
        }
    }

    private func loadItems() async {
        // Wait for CloudKit to sign in first
        guard cloudKit.isSignedInToiCloud else {
            return
        }

        let startTime = Date()
        isLoading = true
        errorMessage = nil

        do {
            let records: [CKRecord]
            if let selectedOwnerID = selectedOwnerID {
                // Fetch items for selected child
                records = try await cloudKit.fetchFriendWishlistItems(friendRecordID: selectedOwnerID)
            } else {
                // Fetch items for current user
                records = try await cloudKit.fetchMyWishlistItems()
            }
            var loadedItems = records.map { CKWishlistItem(from: $0) }

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

            items = loadedItems
            purchases = purchaseDict
            isLoading = false
            print("⏱️ [WISHLIST] Loaded \(items.count) items in \(Date().timeIntervalSince(startTime).formatted())s")
        } catch {
            print("❌ Error loading items: \(error)")
            errorMessage = error.localizedDescription
            isLoading = false
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

                // Reload in background to sync
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                await loadItems()
            } catch {
                print("❌ Error deleting item: \(error)")
                // TODO: Re-add item to UI on error
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

    private var isPurchased: Bool {
        purchase != nil
    }

    var body: some View {
        ZStack {
            Color.creamBackground
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
                                .clipped()
                        }

                        // Item name
                        Button(action: {
                            HapticManager.buttonTapped()
                            onEdit()
                            dismiss()
                        }) {
                            Text(item.name)
                                .font(.custom("Caveat", size: 42))
                                .foregroundColor(.warmGray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .strikethrough(showPurchasedItems && isPurchased, color: .warmGray)
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
                                    .background(Color.creamCard)
                                    .cornerRadius(CornerRadius.md)
                            }
                            .buttonStyle(PlainButtonStyle())
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
                    }
                    .padding(Spacing.lg)
                    .padding(.bottom, 80)
                }

                // Delete button at bottom
                VStack {
                    Button(action: {
                        HapticManager.buttonTapped()
                        onDelete()
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete")
                        }
                        .foregroundColor(.warmGray)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                        .background(Color.creamCard)
                        .cornerRadius(CornerRadius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .stroke(Color.warmGrayLight, lineWidth: 1.5)
                        )
                    }
                    .padding(Spacing.lg)
                }
                .background(Color.creamBackground)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
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
            Text(item.name)
                .font(.custom("Caveat", size: 32))
                .lineSpacing(-18)
                .foregroundColor((showPurchasedItems && isPurchased) ? .warmGray : .warmBlack)
                .strikethrough(showPurchasedItems && isPurchased, color: .warmGray)
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
