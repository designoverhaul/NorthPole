//
//  MainTabView.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData
import CloudKit

struct MainTabView: View {
    @State private var selectedTab = 0
    @ObservedObject private var cloudKit = CloudKitManager.shared
    @State private var children: [CKChild] = []

    private var wishlistTabLabel: String {
        children.isEmpty ? "My Wishlist" : "Our Wishlists"
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            MyWishlistView()
                .tabItem {
                    Label(wishlistTabLabel, systemImage: "gift")
                }
                .tag(0)

            FriendsListView(isActive: selectedTab == 1)
                .tabItem {
                    Label("Friends", systemImage: "person.2")
                }
                .tag(1)

            AskSantaView(isActive: .constant(selectedTab == 2))
                .tabItem {
                    Label("Ask Santa", systemImage: "sparkles")
                }
                .tag(2)

            SettingsView(isActive: selectedTab == 3)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(3)
        }
        .id("tabview-\(children.count)") // Force TabView to recreate when children count changes
        .tint(.forestGreen)
        .task {
            // Load children from CloudKit
            if cloudKit.isSignedInToiCloud {
                await loadChildren()
            }
        }
        .onChange(of: cloudKit.shouldRefreshChildren) { _, _ in
            Task {
                await loadChildren()
            }
        }
        .onChange(of: selectedTab) { _, _ in
            HapticManager.selection()
        }
    }
    
    private func loadChildren() async {
        guard cloudKit.isSignedInToiCloud else { return }
        
        do {
            let records = try await cloudKit.fetchMyChildren()
            await MainActor.run {
                children = records.map { CKChild(from: $0) }
            }
        } catch {
            // Silently fail - tab label will just show "My Wishlist"
        }
    }
}

#Preview {
    MainTabView()
}
