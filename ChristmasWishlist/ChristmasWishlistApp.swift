//
//  ChristmasWishlistApp.swift
//  ChristmasWishlist
//
//  Created by Aaron Heine on 11/16/25.
//

import SwiftUI

@main
struct ChristmasWishlistApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.light) // Force light mode only
        }
    }
}
