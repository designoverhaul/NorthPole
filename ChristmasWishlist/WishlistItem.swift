//
//  WishlistItem.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import Foundation
import SwiftData

@Model
final class WishlistItem {
    var id: UUID = UUID()
    var name: String = ""
    var url: String?
    var itemDescription: String?
    var isPurchased: Bool = false
    /// True when the owner checked the item off themselves. Friend claims only
    /// set isPurchased, so the owner's own list can show self-marks while
    /// keeping friends' claims secret (see showPurchasedItems setting).
    var purchasedByOwner: Bool = false
    var purchasedByUserId: UUID?
    var createdAt: Date = Date()
    var ownerId: UUID = UUID()
    var imageData: Data?
    var imageUrl: String?  // Firebase Storage URL for the image

    // Friend caching / sync support
    var ownerPhone: String = ""  // Canonical digits-only phone
    var isOwnedByCurrentUser: Bool = true
    var lastSyncedAt: Date?
    /// Firestore child document id when this item belongs to a child; empty for adult items.
    var childId: String = ""

    init(
        id: UUID = UUID(),
        name: String,
        url: String? = nil,
        itemDescription: String? = nil,
        isPurchased: Bool = false,
        purchasedByOwner: Bool = false,
        purchasedByUserId: UUID? = nil,
        createdAt: Date = Date(),
        ownerId: UUID,
        imageData: Data? = nil,
        imageUrl: String? = nil,
        ownerPhone: String = "",
        isOwnedByCurrentUser: Bool = true,
        lastSyncedAt: Date? = nil,
        childId: String = ""
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.itemDescription = itemDescription
        self.isPurchased = isPurchased
        self.purchasedByOwner = purchasedByOwner
        self.purchasedByUserId = purchasedByUserId
        self.createdAt = createdAt
        self.ownerId = ownerId
        self.imageData = imageData
        self.imageUrl = imageUrl
        self.ownerPhone = ownerPhone
        self.isOwnedByCurrentUser = isOwnedByCurrentUser
        self.lastSyncedAt = lastSyncedAt
        self.childId = childId
    }
}
