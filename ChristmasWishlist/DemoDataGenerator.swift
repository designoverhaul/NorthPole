//
//  DemoDataGenerator.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import Foundation
import SwiftData

/// Helper to generate demo data for testing and previews
enum DemoDataGenerator {
    static let currentUserId = UUID()

    static func generateDemoData(in context: ModelContext) {
        // Create current user
        let user = User(
            id: currentUserId,
            name: "Me",
            phoneNumber: "555-0100",
            email: "me@example.com"
        )
        context.insert(user)

        // Create user's wishlist items
        let myItems = [
            WishlistItem(
                name: "Coffee Maker",
                url: "https://www.example.com/coffee-maker",
                itemDescription: "Preferably with a timer feature",
                ownerId: currentUserId
            ),
            WishlistItem(
                name: "Camping Tent",
                url: nil,
                itemDescription: "4-person capacity for family trips",
                ownerId: currentUserId
            ),
            WishlistItem(
                name: "Wireless Headphones",
                url: "https://www.example.com/headphones",
                itemDescription: nil,
                ownerId: currentUserId
            ),
            WishlistItem(
                name: "Cookbook - Italian Cuisine",
                url: nil,
                itemDescription: nil,
                ownerId: currentUserId
            )
        ]

        for item in myItems {
            context.insert(item)
        }

        // Create friends
        let davidId = UUID()
        let lisaId = UUID()
        _ = UUID() // connorId - reserved for future use

        let friends = [
            Friend(
                name: "David",
                phoneNumber: "555-0101",
                email: "david@example.com",
                hasApp: true,
                userId: davidId
            ),
            Friend(
                name: "Lisa",
                phoneNumber: "555-0102",
                email: "lisa@example.com",
                hasApp: true,
                userId: lisaId
            ),
            Friend(
                name: "Connor",
                phoneNumber: "555-0103",
                email: "connor@example.com",
                hasApp: false,
                userId: nil
            )
        ]

        for friend in friends {
            context.insert(friend)
        }

        // Create David's wishlist items
        let davidItems = [
            WishlistItem(
                name: "Computer",
                url: "https://www.example.com/computer",
                itemDescription: "MacBook Pro 14-inch",
                ownerId: davidId
            ),
            WishlistItem(
                name: "Camping Tent",
                url: nil,
                itemDescription: "2-person lightweight",
                ownerId: davidId
            ),
            WishlistItem(
                name: "Coffee Maker",
                url: "https://www.example.com/espresso",
                itemDescription: "Espresso machine preferred",
                isPurchased: true,
                purchasedByUserId: currentUserId,
                ownerId: davidId
            )
        ]

        for item in davidItems {
            context.insert(item)
        }

        // Create Lisa's wishlist items
        let lisaItems = [
            WishlistItem(
                name: "Yoga Mat",
                url: "https://www.example.com/yoga-mat",
                itemDescription: "Extra thick, purple color",
                ownerId: lisaId
            ),
            WishlistItem(
                name: "Plant Stand",
                url: nil,
                itemDescription: "Wood, mid-century modern style",
                ownerId: lisaId
            ),
            WishlistItem(
                name: "Running Shoes",
                url: "https://www.example.com/shoes",
                itemDescription: "Size 8, neutral colors",
                ownerId: lisaId
            )
        ]

        for item in lisaItems {
            context.insert(item)
        }

        // Save context
        try? context.save()
    }

    static func clearAllData(in context: ModelContext) {
        // Delete all items
        try? context.delete(model: WishlistItem.self)
        try? context.delete(model: Friend.self)
        try? context.delete(model: User.self)

        try? context.save()
    }
}
