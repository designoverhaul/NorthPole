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

    private var wishlistTabLabel: LocalizedStringKey {
        children.isEmpty ? "My Wishlist" : "Our Wishlists"
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            MyWishlistView()
                .tabItem {
                    tabIcon("tabWishlist", selected: selectedTab == 0)
                    Text(wishlistTabLabel)
                }
                .tag(0)

            FriendsListView()
                .tabItem {
                    tabIcon("tabFriends", selected: selectedTab == 1)
                    Text("Friends")
                }
                .tag(1)

            AskSantaView(isActive: .constant(selectedTab == 2))
                .tabItem {
                    tabIcon("tabSanta", selected: selectedTab == 2)
                    Text("Ask Santa")
                }
                .tag(2)

            SettingsView(isActive: selectedTab == 3)
                .tabItem {
                    tabIcon("tabSettings", selected: selectedTab == 3)
                    Text("Settings")
                }
                .tag(3)
        }
        .id("tabview-\(children.count)") // Force TabView to recreate when children count changes
        .tint(.forestGreen)
        .onChange(of: selectedTab) { _, _ in
            HapticManager.selection()
        }
    }

    /// Phosphor tab icons (bundled, MIT). Filled variant when selected — like
    /// native SF Symbol tab items, but with our own custom icon set.
    private func tabIcon(_ base: String, selected: Bool) -> Image {
        Image(selected ? "\(base)Fill" : base)
            .renderingMode(.template)
    }
}

#Preview {
    MainTabView()
}
