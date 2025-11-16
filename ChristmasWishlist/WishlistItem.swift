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
    var id: UUID
    var name: String
    var url: String?
    var itemDescription: String?
    var isPurchased: Bool
    var purchasedByUserId: UUID?
    var createdAt: Date
    var ownerId: UUID

    init(
        id: UUID = UUID(),
        name: String,
        url: String? = nil,
        itemDescription: String? = nil,
        isPurchased: Bool = false,
        purchasedByUserId: UUID? = nil,
        createdAt: Date = Date(),
        ownerId: UUID
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.itemDescription = itemDescription
        self.isPurchased = isPurchased
        self.purchasedByUserId = purchasedByUserId
        self.createdAt = createdAt
        self.ownerId = ownerId
    }
}
