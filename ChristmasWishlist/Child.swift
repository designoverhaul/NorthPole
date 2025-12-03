//
//  Child.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import Foundation
import SwiftData

@Model
final class Child {
    var id: UUID = UUID()
    var name: String = ""
    var parentId: UUID = UUID()
    var createdAt: Date = Date()
    var cloudKitRecordID: String? = nil // CloudKit Child record ID (for syncing wishlist items)

    init(
        id: UUID = UUID(),
        name: String,
        parentId: UUID,
        createdAt: Date = Date(),
        cloudKitRecordID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.parentId = parentId
        self.createdAt = createdAt
        self.cloudKitRecordID = cloudKitRecordID
    }
}
