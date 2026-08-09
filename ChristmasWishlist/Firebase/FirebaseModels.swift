//
//  FirebaseModels.swift
//  ChristmasWishlist
//
//  Created by Claude Code on 12/10/24.
//

import Foundation
import FirebaseFirestore

// MARK: - Firestore Document Models

/// User document model (Firestore: users/{phoneNumber})
struct FirestoreUser: Codable {
    var displayName: String
    var createdAt: Timestamp
    var fcmTokens: [String]
    var settings: UserSettings

    struct UserSettings: Codable {
        var notificationsEnabled: Bool
        var showPurchasedItems: Bool
    }
}

/// Wishlist item document model (Firestore: wishlistItems/{itemId})
struct FirestoreWishlistItem: Codable {
    var name: String
    var url: String?
    var itemDescription: String?
    var imageUrl: String?
    var createdAt: Timestamp
    var ownerPhone: String
    var ownerType: String  // "user" or "child"
    var childId: String?
    var isPurchased: Bool
    /// True when the owner checked the item off themselves (friend claims never set this).
    var purchasedByOwner: Bool
}

/// Child document model (Firestore: children/{childId})
struct FirestoreChild: Codable {
    var name: String
    var parentPhone: String
    var createdAt: Timestamp
}

/// Purchase document model (Firestore: purchases/{purchaseId})
struct FirestorePurchase: Codable {
    var itemId: String
    var itemName: String
    var purchaserPhone: String
    var ownerPhone: String
    var purchasedAt: Timestamp
    var isActive: Bool
}

/// Friend document model (Firestore: friends/{friendshipId})
struct FirestoreFriend: Codable {
    var userPhone: String
    var friendPhone: String
    var friendName: String
    var addedAt: Timestamp
    var hiddenChildren: [String]
}

// MARK: - Helper Extensions

extension Timestamp {
    /// Convert Firestore Timestamp to Swift Date
    var toDate: Date {
        return Date(timeIntervalSince1970: TimeInterval(seconds))
    }

    /// Create Timestamp from Date
    static func from(_ date: Date) -> Timestamp {
        return Timestamp(date: date)
    }
}

// MARK: - Conversion Helpers

extension FirestoreWishlistItem {
    /// Convert to dictionary for Firestore
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "createdAt": createdAt,
            "ownerPhone": ownerPhone,
            "ownerType": ownerType,
            "isPurchased": isPurchased,
            "purchasedByOwner": purchasedByOwner
        ]

        if let url = url { dict["url"] = url }
        if let desc = itemDescription { dict["itemDescription"] = desc }
        if let image = imageUrl { dict["imageUrl"] = image }
        if let child = childId { dict["childId"] = child }

        return dict
    }

    /// Create from Firestore document
    static func from(document: DocumentSnapshot) -> FirestoreWishlistItem? {
        guard let data = document.data() else { return nil }

        return FirestoreWishlistItem(
            name: data["name"] as? String ?? "",
            url: data["url"] as? String,
            itemDescription: data["itemDescription"] as? String,
            imageUrl: data["imageUrl"] as? String,
            createdAt: data["createdAt"] as? Timestamp ?? Timestamp(),
            ownerPhone: data["ownerPhone"] as? String ?? "",
            ownerType: data["ownerType"] as? String ?? "user",
            childId: data["childId"] as? String,
            isPurchased: data["isPurchased"] as? Bool ?? false,
            purchasedByOwner: data["purchasedByOwner"] as? Bool ?? false
        )
    }
}

extension FirestoreChild {
    /// Convert to dictionary for Firestore
    func toDictionary() -> [String: Any] {
        return [
            "name": name,
            "parentPhone": parentPhone,
            "createdAt": createdAt
        ]
    }

    /// Create from Firestore document
    static func from(document: DocumentSnapshot) -> FirestoreChild? {
        guard let data = document.data() else { return nil }

        return FirestoreChild(
            name: data["name"] as? String ?? "",
            parentPhone: data["parentPhone"] as? String ?? "",
            createdAt: data["createdAt"] as? Timestamp ?? Timestamp()
        )
    }
}

extension FirestorePurchase {
    /// Convert to dictionary for Firestore
    func toDictionary() -> [String: Any] {
        return [
            "itemId": itemId,
            "itemName": itemName,
            "purchaserPhone": purchaserPhone,
            "ownerPhone": ownerPhone,
            "purchasedAt": purchasedAt,
            "isActive": isActive
        ]
    }

    /// Create from Firestore document
    static func from(document: DocumentSnapshot) -> FirestorePurchase? {
        guard let data = document.data() else { return nil }

        return FirestorePurchase(
            itemId: data["itemId"] as? String ?? "",
            itemName: data["itemName"] as? String ?? "",
            purchaserPhone: data["purchaserPhone"] as? String ?? "",
            ownerPhone: data["ownerPhone"] as? String ?? "",
            purchasedAt: data["purchasedAt"] as? Timestamp ?? Timestamp(),
            isActive: data["isActive"] as? Bool ?? true
        )
    }
}

extension FirestoreFriend {
    /// Convert to dictionary for Firestore
    func toDictionary() -> [String: Any] {
        return [
            "userPhone": userPhone,
            "friendPhone": friendPhone,
            "friendName": friendName,
            "addedAt": addedAt,
            "hiddenChildren": hiddenChildren
        ]
    }

    /// Create from Firestore document
    static func from(document: DocumentSnapshot) -> FirestoreFriend? {
        guard let data = document.data() else { return nil }

        return FirestoreFriend(
            userPhone: data["userPhone"] as? String ?? "",
            friendPhone: data["friendPhone"] as? String ?? "",
            friendName: data["friendName"] as? String ?? "",
            addedAt: data["addedAt"] as? Timestamp ?? Timestamp(),
            hiddenChildren: data["hiddenChildren"] as? [String] ?? []
        )
    }
}
