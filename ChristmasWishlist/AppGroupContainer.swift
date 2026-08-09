//
//  AppGroupContainer.swift
//  ChristmasWishlist
//

import Foundation
import SwiftData

enum AppGroupContainer {
    static let identifier = "group.com.designoverhaul.ChristmasWishlist"

    static var modelContainer: ModelContainer = {
        let schema = Schema([
            WishlistItem.self,
            Friend.self,
            Child.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier(identifier)
        )

        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            container.mainContext.autosaveEnabled = true
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }
}
