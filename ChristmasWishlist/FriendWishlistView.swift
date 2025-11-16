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

    @StateObject private var cloudKit = CloudKitManager.shared
    @State private var items: [CKWishlistItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccessSparkle = false

    var body: some View {
        ZStack {
            Color.creamBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if !friend.hasApp {
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
                        LazyVStack(spacing: Spacing.md) {
                            ForEach(items) { item in
                                FriendWishlistItemRow(
                                    item: item,
                                    onTogglePurchase: {
                                        togglePurchase(item)
                                    }
                                )
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
        .friendNameTitle(friend.name)
        .onAppear {
            Task {
                await loadItems()
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

            Text("\(friend.name) hasn't joined\nChristmas Wishlist yet")
                .font(.bodyMedium)
                .foregroundColor(.warmGray)
                .multilineTextAlignment(.center)

            Button(action: {
                // In a real app, this would open share sheet to invite
                HapticManager.buttonTapped()
            }) {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text("Invite \(friend.name)")
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

            Text("\(friend.name) hasn't added\nanything to their wishlist")
                .font(.bodyMedium)
                .foregroundColor(.warmGray)
                .multilineTextAlignment(.center)

            Spacer()
        }
    }

    private func loadItems() async {
        // Only load if friend has the app (has a CloudKit record ID)
        guard friend.hasApp, let friendRecordID = friend.friendUserRecordID else {
            items = []
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let records = try await cloudKit.fetchFriendWishlistItems(friendRecordID: friendRecordID)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                items = records.map { CKWishlistItem(from: $0) }
            }
        } catch {
            errorMessage = "Failed to load wishlist: \(error.localizedDescription)"
        }
    }

    private func togglePurchase(_ item: CKWishlistItem) {
        HapticManager.buttonTapped()

        Task {
            do {
                var updatedItem = item
                updatedItem.isPurchased.toggle()
                updatedItem.updateRecord()

                try await cloudKit.updateWishlistItem(updatedItem.record)

                // Reload items
                await loadItems()

                if updatedItem.isPurchased {
                    HapticManager.itemMarkedPurchased()
                    showSuccessSparkle = true
                } else {
                    HapticManager.impact(.medium)
                }
            } catch {
                errorMessage = "Failed to update item: \(error.localizedDescription)"
                HapticManager.errorOccurred()
            }
        }
    }
}

// MARK: - Friend Wishlist Item Row
struct FriendWishlistItemRow: View {
    let item: CKWishlistItem
    let onTogglePurchase: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Image if available
            if let imageData = item.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .cornerRadius(CornerRadius.sm)
                    .clipped()
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(item.name)
                    .font(.bodyLarge)
                    .fontWeight(.medium)
                    .foregroundColor(item.isPurchased ? .warmGray : .warmBlack)
                    .strikethrough(item.isPurchased, color: .warmGray)

                if let url = item.url, !url.isEmpty {
                    Text(url)
                        .font(.caption)
                        .foregroundColor(.warmGray)
                        .lineLimit(1)
                }

                if let description = item.itemDescription, !description.isEmpty {
                    Text(description)
                        .font(.bodySmall)
                        .foregroundColor(.warmGray)
                        .lineLimit(2)
                }
            }

            Spacer()

            Button(action: onTogglePurchase) {
                Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28))
                    .foregroundColor(item.isPurchased ? .successGreen : .warmGrayLight)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(Spacing.md)
        .background(Color.creamCard)
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
                }()
            )
        )
    }
}
