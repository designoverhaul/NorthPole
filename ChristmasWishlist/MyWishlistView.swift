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
    @State private var showSuccessSparkle = false

    var myItems: [WishlistItem] {
        items.filter { $0.ownerId == currentUserId }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.creamBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if myItems.isEmpty {
                        emptyStateView
                    } else {
                        ScrollView {
                            LazyVStack(spacing: Spacing.md) {
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
                }

                // Floating Action Button
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

                // Success sparkle overlay
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
                AddGiftView(userId: currentUserId, onItemAdded: {
                    showSuccessSparkle = true
                })
            }
            .sheet(item: $itemToEdit) { item in
                AddGiftView(userId: currentUserId, onItemAdded: {
                    showSuccessSparkle = true
                }, itemToEdit: item)
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
}

#Preview {
    MyWishlistView()
        .modelContainer(for: [WishlistItem.self])
}
