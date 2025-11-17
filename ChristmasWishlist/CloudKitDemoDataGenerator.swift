//
//  CloudKitDemoDataGenerator.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import Foundation
import CloudKit

/// Helper to generate demo CloudKit data for testing
enum CloudKitDemoDataGenerator {

    static func generateDemoData() async throws {
        let cloudKit = CloudKitManager.shared

        guard cloudKit.isSignedInToiCloud else {
            print("❌ CloudKit: Cannot generate demo data - not signed in")
            throw CloudKitError.notSignedIn
        }

        print("🎄 Starting demo data generation...")
        print("📊 Current user ID: \(cloudKit.currentUserRecordID?.recordName ?? "unknown")")

        // Create a fake friend user record ID for Sarah
        let sarahFakeUserRecordID = UUID().uuidString
        print("📝 Generated fake user ID for Sarah: \(sarahFakeUserRecordID.prefix(8))...")

        do {
            // 1. Create Sarah as a friend
            _ = try await cloudKit.saveFriend(
                name: "Sarah",
                phoneNumber: "555-0104",
                email: "sarah@example.com",
                imageData: nil,
                friendUserRecordID: sarahFakeUserRecordID
            )
            print("✅ Created friend: Sarah")
        } catch {
            print("❌ Failed to create friend Sarah: \(error.localizedDescription)")
            throw error
        }

        // Small delay for CloudKit consistency
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

        // 2. Create Sarah's children (using the fake user record ID as parent)
        let emmaRecord: CKRecord
        let oliverRecord: CKRecord

        do {
            emmaRecord = try await cloudKit.saveChild(
                name: "Emma",
                parentUserRecordID: sarahFakeUserRecordID
            )
            print("✅ Created child: Emma")
        } catch {
            print("❌ Failed to create child Emma: \(error.localizedDescription)")
            throw error
        }

        do {
            oliverRecord = try await cloudKit.saveChild(
                name: "Oliver",
                parentUserRecordID: sarahFakeUserRecordID
            )
            print("✅ Created child: Oliver")
        } catch {
            print("❌ Failed to create child Oliver: \(error.localizedDescription)")
            throw error
        }

        // Small delay for CloudKit consistency
        try? await Task.sleep(nanoseconds: 300_000_000)

        // 3. Create wishlist items for Sarah
        _ = try await cloudKit.saveWishlistItem(
            name: "Kitchen Stand Mixer",
            url: "https://www.example.com/mixer",
            description: "KitchenAid, any color",
            imageData: nil,
            ownerRecordID: sarahFakeUserRecordID
        )
        print("✅ Created wishlist item for Sarah")

        _ = try await cloudKit.saveWishlistItem(
            name: "Gardening Tools Set",
            url: nil,
            description: "Complete set with trowel, pruners, and gloves",
            imageData: nil,
            ownerRecordID: sarahFakeUserRecordID
        )
        print("✅ Created wishlist item for Sarah")

        // 4. Create wishlist items for Emma
        _ = try await cloudKit.saveWishlistItem(
            name: "Art Supply Kit",
            url: "https://www.example.com/art-kit",
            description: "Watercolors, brushes, and sketch pad",
            imageData: nil,
            ownerRecordID: emmaRecord.recordID.recordName
        )
        print("✅ Created wishlist item for Emma")

        _ = try await cloudKit.saveWishlistItem(
            name: "Unicorn Backpack",
            url: nil,
            description: "Purple or pink with sparkles",
            imageData: nil,
            ownerRecordID: emmaRecord.recordID.recordName
        )
        print("✅ Created wishlist item for Emma")

        _ = try await cloudKit.saveWishlistItem(
            name: "Chapter Books Set",
            url: "https://www.example.com/books",
            description: "Age 8-10, fantasy or adventure",
            imageData: nil,
            ownerRecordID: emmaRecord.recordID.recordName
        )
        print("✅ Created wishlist item for Emma")

        // 5. Create wishlist items for Oliver
        _ = try await cloudKit.saveWishlistItem(
            name: "LEGO Star Wars Set",
            url: "https://www.example.com/lego",
            description: "Millennium Falcon or X-Wing",
            imageData: nil,
            ownerRecordID: oliverRecord.recordID.recordName
        )
        print("✅ Created wishlist item for Oliver")

        _ = try await cloudKit.saveWishlistItem(
            name: "Soccer Ball",
            url: nil,
            description: "Size 4, official match ball",
            imageData: nil,
            ownerRecordID: oliverRecord.recordID.recordName
        )
        print("✅ Created wishlist item for Oliver")

        _ = try await cloudKit.saveWishlistItem(
            name: "Remote Control Car",
            url: "https://www.example.com/rc-car",
            description: "Fast, durable for outdoor use",
            imageData: nil,
            ownerRecordID: oliverRecord.recordID.recordName
        )
        print("✅ Created wishlist item for Oliver")

        print("🎉 Demo data generation complete!")

        // Trigger a refresh of the friends list
        await MainActor.run {
            cloudKit.shouldRefreshFriends.toggle()
        }
    }

    static func clearAllData() async throws {
        let cloudKit = CloudKitManager.shared

        guard cloudKit.isSignedInToiCloud else {
            print("❌ CloudKit: Cannot clear data - not signed in")
            throw CloudKitError.notSignedIn
        }

        print("🗑️ Starting to clear all data...")

        // 1. Delete all friends
        let friends = try await cloudKit.fetchMyFriends()
        for friend in friends {
            try await cloudKit.deleteFriend(friend.recordID)
        }
        print("✅ Deleted \(friends.count) friends")

        // 2. Delete all children
        let children = try await cloudKit.fetchMyChildren()
        for child in children {
            try await cloudKit.deleteChild(child.recordID)
        }
        print("✅ Deleted \(children.count) children")

        // 3. Delete all wishlist items
        let items = try await cloudKit.fetchMyWishlistItems()
        for item in items {
            try await cloudKit.deleteWishlistItem(item.recordID)
        }
        print("✅ Deleted \(items.count) wishlist items")

        print("🎉 All data cleared!")

        // Trigger a refresh of the friends list
        await MainActor.run {
            cloudKit.shouldRefreshFriends.toggle()
        }
    }
}
