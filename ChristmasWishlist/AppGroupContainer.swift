//
//  AppGroupContainer.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import Foundation
import SwiftData

enum AppGroupContainer {
    static let identifier = "group.com.designoverhaul.ChristmasWishlist"

    static var modelContainer: ModelContainer = {
        let schema = Schema([
            WishlistItem.self,
            Friend.self,
            User.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier(identifier)
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }

    // Save current user ID for share extension access
    // Note: These functions are legacy and may not be used with Firebase migration
    static func saveCurrentUserId(_ userId: UUID, forCloudKitUser cloudKitRecordID: String) {
        let key = "currentUserId_\(cloudKitRecordID)"
        sharedDefaults?.set(userId.uuidString, forKey: key)
    }

    static func getCurrentUserId(forCloudKitUser cloudKitRecordID: String) -> UUID? {
        let key = "currentUserId_\(cloudKitRecordID)"
        guard let userIdString = sharedDefaults?.string(forKey: key) else {
            return nil
        }
        return UUID(uuidString: userIdString)
    }
}
