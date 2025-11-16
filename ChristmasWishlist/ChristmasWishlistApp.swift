//
//  ChristmasWishlistApp.swift
//  ChristmasWishlist
//
//  Created by Aaron Heine on 11/16/25.
//

import SwiftUI
import SwiftData

@main
struct ChristmasWishlistApp: App {
    init() {
        // Debug: Print all available fonts
        printAllAvailableFonts()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.light) // Force light mode only
        }
        .modelContainer(AppGroupContainer.modelContainer)
    }
}
