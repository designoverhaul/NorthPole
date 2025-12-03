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
                friendUserRecordID: davidId.uuidString
            ),
            Friend(
                name: "Lisa",
                phoneNumber: "555-0102",
                email: "lisa@example.com",
                hasApp: true,
                friendUserRecordID: lisaId.uuidString
            ),
            Friend(
                name: "Connor",
                phoneNumber: "555-0103",
                email: "connor@example.com",
                hasApp: false,
                friendUserRecordID: nil
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

        // Create Sarah (friend with children)
        let sarahId = UUID()
        let sarah = Friend(
            name: "Sarah",
            phoneNumber: "555-0104",
            email: "sarah@example.com",
            hasApp: true,
            friendUserRecordID: sarahId.uuidString
        )
        context.insert(sarah)

        // Create Sarah's children
        let emmaId = UUID()
        let oliverId = UUID()

        let emma = Child(
            id: emmaId,
            name: "Emma",
            parentId: sarahId
        )
        context.insert(emma)

        let oliver = Child(
            id: oliverId,
            name: "Oliver",
            parentId: sarahId
        )
        context.insert(oliver)

        // Create Sarah's wishlist items
        let sarahItems = [
            WishlistItem(
                name: "Kitchen Stand Mixer",
                url: "https://www.example.com/mixer",
                itemDescription: "KitchenAid, any color",
                ownerId: sarahId
            ),
            WishlistItem(
                name: "Gardening Tools Set",
                url: nil,
                itemDescription: "Complete set with trowel, pruners, and gloves",
                ownerId: sarahId
            )
        ]

        for item in sarahItems {
            context.insert(item)
        }

        // Create Emma's wishlist items
        let emmaItems = [
            WishlistItem(
                name: "Art Supply Kit",
                url: "https://www.example.com/art-kit",
                itemDescription: "Watercolors, brushes, and sketch pad",
                ownerId: emmaId
            ),
            WishlistItem(
                name: "Unicorn Backpack",
                url: nil,
                itemDescription: "Purple or pink with sparkles",
                ownerId: emmaId
            ),
            WishlistItem(
                name: "Chapter Books Set",
                url: "https://www.example.com/books",
                itemDescription: "Age 8-10, fantasy or adventure",
                ownerId: emmaId
            )
        ]

        for item in emmaItems {
            context.insert(item)
        }

        // Create Oliver's wishlist items
        let oliverItems = [
            WishlistItem(
                name: "LEGO Star Wars Set",
                url: "https://www.example.com/lego",
                itemDescription: "Millennium Falcon or X-Wing",
                ownerId: oliverId
            ),
            WishlistItem(
                name: "Soccer Ball",
                url: nil,
                itemDescription: "Size 4, official match ball",
                ownerId: oliverId
            ),
            WishlistItem(
                name: "Remote Control Car",
                url: "https://www.example.com/rc-car",
                itemDescription: "Fast, durable for outdoor use",
                ownerId: oliverId
            )
        ]

        for item in oliverItems {
            context.insert(item)
        }

        // Save context
        try? context.save()
    }

    static func clearAllData(in context: ModelContext) {
        // Delete all items
        try? context.delete(model: WishlistItem.self)
        try? context.delete(model: Child.self)
        try? context.delete(model: Friend.self)
        try? context.delete(model: User.self)

        try? context.save()
    }
}
