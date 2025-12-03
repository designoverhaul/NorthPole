//
//  Friend.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import Foundation
import SwiftData

@Model
final class Friend {
    var id: UUID = UUID()
    var name: String = ""
    var phoneNumber: String?
    var email: String?
    var hasApp: Bool = false
    var friendUserRecordID: String? // The friend's CloudKit user record ID (for viewing their wishlist)
    var cloudKitRecordID: String? // THIS friend record's CloudKit record ID (for syncing)
    var addedAt: Date = Date()
    @Attribute(.externalStorage) var imageData: Data?
    var hiddenChildRecordIDs: [String] = []

    init(
        id: UUID = UUID(),
        name: String,
        phoneNumber: String? = nil,
        email: String? = nil,
        hasApp: Bool = false,
        friendUserRecordID: String? = nil,
        cloudKitRecordID: String? = nil,
        addedAt: Date = Date(),
        imageData: Data? = nil,
        hiddenChildRecordIDs: [String] = []
    ) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.email = email
        self.hasApp = hasApp
        self.friendUserRecordID = friendUserRecordID
        self.cloudKitRecordID = cloudKitRecordID
        self.addedAt = addedAt
        self.imageData = imageData
        self.hiddenChildRecordIDs = hiddenChildRecordIDs
    }
}
