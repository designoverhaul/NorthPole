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
    @State private var showingAddGift = false
    @State private var itemToEdit: CKWishlistItem?
    @State private var showSuccessSparkle = false
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if !cloudKit.isSignedInToiCloud {
                        notSignedInView
                    } else if isLoading {
                        ProgressView("Loading wishlist...")
                            .tint(.forestGreen)
                    } else if items.isEmpty {
                        emptyStateView
                    } else {
                        ScrollView {
                            LazyVStack(spacing: Spacing.md) {
                                ForEach(items) { item in
                                    CloudKitItemRow(item: item)
                                        .onTapGesture {
                                            HapticManager.buttonTapped()
                                            itemToEdit = item
                                        }
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                deleteItem(item)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
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
                CloudKitAddGiftView(onItemAdded: {
                    showSuccessSparkle = true
                    Task {
                        await loadItems()
                    }
                })
            }
            .sheet(item: $itemToEdit) { item in
                CloudKitEditGiftView(item: item, onItemUpdated: {
                    Task {
                        await loadItems()
                    }
                })
            }
            .task {
                await loadItems()
            }
            .refreshable {
                await loadItems()
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

    private func loadItems() async {
        isLoading = true
        errorMessage = nil

        do {
            let records = try await cloudKit.fetchMyWishlistItems()
            items = records.map { CKWishlistItem(from: $0) }
            isLoading = false
        } catch {
            print("❌ Error loading items: \(error)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func deleteItem(_ item: CKWishlistItem) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            HapticManager.itemDeleted()

            Task {
                do {
                    try await cloudKit.deleteWishlistItem(item.record.recordID)
                    await loadItems()
                } catch {
                    print("❌ Error deleting item: \(error)")
                }
            }
        }
    }
}

// MARK: - CloudKit Item Row

struct CloudKitItemRow: View {
    let item: CKWishlistItem

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Image if available
            if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .cornerRadius(CornerRadius.sm)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(item.name)
                    .font(.bodyLarge)
                    .fontWeight(.medium)
                    .foregroundColor(.warmBlack)

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
    CloudKitWishlistView()
}
