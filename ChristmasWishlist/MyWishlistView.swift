//
//  MyWishlistView.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData

struct MyWishlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WishlistItem.createdAt, order: .reverse) private var items: [WishlistItem]
    @Query(sort: \Child.name) private var children: [Child]
    @ObservedObject private var firebase = FirebaseManager.shared

    @State private var showingAddGift = false
    @State private var itemToEdit: WishlistItem?
    @State private var selectedChild: Child? = nil // Selected child for viewing their wishlist
    @State private var purchasedItemIdForSparkle: UUID? = nil
    @State private var showFallingSnow: Bool = false

    // Share wishlist state
    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
    @State private var showingError = false
    @State private var errorMessage: String?

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

    var titleText: String {
        if let child = selectedChild {
            return "\(child.name)'s Wishlist"
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
            // Load children from Firebase (returns local immediately, syncs in background)
            await loadChildren()
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
                }
            }
        }
        .onAppear {
            // Load children and items from Firebase
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
                    name: "Me",
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
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(Array(myItems.enumerated()), id: \.element.id) { index, item in
                    NavigationLink {
                        MyItemDetailView(
                            item: item,
                            onEdit: {
                                itemToEdit = item
                            },
                            onDelete: {
                                deleteItem(item)
                            },
                            onTogglePurchase: {
                                togglePurchase(item)
                            }
                        )
                    } label: {
                        WishlistItemRow(
                            item: item,
                            showPurchaseButton: false,
                            onDelete: nil,
                            onTogglePurchase: nil,
                            giftIndex: computeGiftIndex(for: item, in: myItems),
                            showSparkle: purchasedItemIdForSparkle == item.id,
                            onSparkleComplete: {
                                purchasedItemIdForSparkle = nil
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
            .padding(.bottom, 80) // Space for FAB
        }
        .refreshable {
            print("🔄 [PULL-TO-REFRESH] User pulled to refresh")
            HapticManager.buttonTapped()
            await downloadAllItemsFromFirebase()
        }
    }
    
    // Compute gift index for an item based on its position among purchased items
    private func computeGiftIndex(for item: WishlistItem, in allItems: [WishlistItem]) -> Int? {
        guard item.isPurchased else { return nil } // Not purchased
        
        // Find all purchased items and sort them by creation date (or ID for consistency)
        let purchasedItems = allItems
            .filter { $0.isPurchased }
            .sorted { $0.createdAt < $1.createdAt } // Sort by creation date
        
        // Find this item's index in the sorted purchased items list
        if let index = purchasedItems.firstIndex(where: { $0.id == item.id }) {
            return index
        }
        return nil
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
        withAnimation {
            HapticManager.buttonTapped()
            item.isPurchased.toggle()
            try? modelContext.save()
            
            if item.isPurchased {
                HapticManager.itemMarkedPurchased()
                purchasedItemIdForSparkle = item.id
                
                // Trigger snow effect - temporarily disabled
                // showFallingSnow = false // Reset first
                // DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                //     showFallingSnow = true
                //     
                //     // Hide snow after animation completes (shorter for quick fall)
                //     DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
                //         showFallingSnow = false
                //     }
                // }
            } else {
                HapticManager.impact(.medium)
            }
        }
    }

    @MainActor
    private func downloadAllItemsFromFirebase() async {
        print("📥 [FIREBASE SYNC] Starting sync from Firebase")

        guard firebase.isAuthenticated else {
            print("⚠️ [FIREBASE] Not authenticated")
            errorMessage = "Please sign in to continue"
            showingError = true
            return
        }

        do {
            // Fetch items and children from Firebase (returns local immediately, syncs in background)
            _ = try await firebase.fetchMyWishlistItems(context: modelContext)
            _ = try await firebase.fetchMyChildren(context: modelContext)

            print("✅ [FIREBASE SYNC] Sync completed successfully")
        } catch {
            print("❌ [FIREBASE SYNC] Failed: \(error.localizedDescription)")
            errorMessage = "Failed to sync: \(error.localizedDescription)"
            showingError = true
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
        shareText += "🎄 Create your own wishlist!\n"
        
        // Prepare share items
        shareItems = [shareText]
        showingShareSheet = true
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
    @AppStorage("showPurchasedItems") private var showPurchasedItems = true
    @State private var showingDeleteConfirmation = false

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
                    if showPurchasedItems && item.isPurchased {
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

                    // Mark as Purchased button
                    Button(action: {
                        HapticManager.buttonTapped()
                        onTogglePurchase()
                    }) {
                        if item.isPurchased {
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
                    .padding(.top, Spacing.xs)

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
                        .padding(.top, Spacing.xs)
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
                        .foregroundColor(.forestGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                        .background(Color.creamCard)
                        .cornerRadius(CornerRadius.md)
                    }
                    .padding(.top, Spacing.xs)

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
                        .foregroundColor(.warmGray)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                        .background(Color.creamCard)
                        .cornerRadius(CornerRadius.md)
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
