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
    /// Legacy field — prefer phoneNumber for Firebase identity.
    var friendUserRecordID: String?
    /// Firestore friendship document id (field name kept for SwiftData stability).
    var cloudKitRecordID: String?
    var addedAt: Date = Date()
    @Attribute(.externalStorage) var imageData: Data?
    var hiddenChildRecordIDs: [String] = []

    /// Convenience alias for the Firestore friendship document id.
    var firebaseFriendshipId: String? {
        get { cloudKitRecordID }
        set { cloudKitRecordID = newValue }
    }

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
        self.phoneNumber = phoneNumber.map(PhoneNumber.normalize)
        self.email = email
        self.hasApp = hasApp
        self.friendUserRecordID = friendUserRecordID
        self.cloudKitRecordID = cloudKitRecordID
        self.addedAt = addedAt
        self.imageData = imageData
        self.hiddenChildRecordIDs = hiddenChildRecordIDs
    }
}
