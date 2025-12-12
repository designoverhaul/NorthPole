//
//  MainTabView.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab = 0
    @Query(sort: \Child.name) private var children: [Child]

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

            FriendsListView()
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
        .onChange(of: selectedTab) { _, _ in
            HapticManager.selection()
        }
    }
}

#Preview {
    MainTabView()
}
