//
//  MainTabView.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            AskSantaView(isActive: .constant(selectedTab == 0))
                .tabItem {
                    Label("Ask Santa", systemImage: "sparkles")
                }
                .tag(0)

            CloudKitWishlistView(isActive: selectedTab == 1)
                .tabItem {
                    Label("My Wishlist", systemImage: "gift")
                }
                .tag(1)

            FriendsListView(isActive: selectedTab == 2)
                .tabItem {
                    Label("Friends", systemImage: "person.2")
                }
                .tag(2)

            SettingsView(isActive: selectedTab == 3)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(3)
        }
        .tint(.forestGreen)
        .onChange(of: selectedTab) { _, _ in
            HapticManager.selection()
        }
    }
}

#Preview {
    MainTabView()
}
