//
//  CloudKitModels.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import CloudKit
import Foundation
import UIKit

// MARK: - CloudKit Wishlist Item

struct CKWishlistItem: Identifiable {
    let id: String
    let record: CKRecord
    var name: String
    var url: String?
    var itemDescription: String?
    var isPurchased: Bool
    var createdAt: Date
    var ownerID: String
    var imageData: Data?

    init(from record: CKRecord) {
        self.record = record
        self.id = record.recordID.recordName
        self.name = record["name"] as? String ?? ""
        self.url = record["url"] as? String
        self.itemDescription = record["itemDescription"] as? String
        self.isPurchased = record["isPurchased"] as? Bool ?? false
        self.createdAt = record["createdAt"] as? Date ?? Date()
        self.ownerID = record["ownerID"] as? String ?? ""

        // Load image from CKAsset
        if let asset = record["image"] as? CKAsset,
           let fileURL = asset.fileURL,
           let data = try? Data(contentsOf: fileURL) {
            self.imageData = data
        }
    }

    mutating func updateRecord() {
        record["name"] = name as CKRecordValue
        record["url"] = (url ?? "") as CKRecordValue
        record["itemDescription"] = (itemDescription ?? "") as CKRecordValue
        record["isPurchased"] = isPurchased as CKRecordValue
    }
}

// MARK: - CloudKit Friend

struct CKFriend: Identifiable {
    let id: String
    let record: CKRecord
    var name: String
    var phoneNumber: String?
    var email: String?
    var ownerID: String
    var friendUserRecordID: String?
    var addedAt: Date
    var imageData: Data?

    var hasApp: Bool {
        friendUserRecordID != nil && !friendUserRecordID!.isEmpty
    }

    init(from record: CKRecord) {
        self.record = record
        self.id = record.recordID.recordName
        self.name = record["name"] as? String ?? ""
        self.phoneNumber = record["phoneNumber"] as? String
        self.email = record["email"] as? String
        self.ownerID = record["ownerID"] as? String ?? ""
        self.friendUserRecordID = record["friendUserRecordID"] as? String
        self.addedAt = record["addedAt"] as? Date ?? Date()

        // Load photo from CKAsset
        if let asset = record["photo"] as? CKAsset,
           let fileURL = asset.fileURL,
           let data = try? Data(contentsOf: fileURL) {
            self.imageData = data
        }
    }
}

// MARK: - CloudKit User

struct CKUser: Identifiable {
    let id: String
    let record: CKRecord
    var name: String

    init(from record: CKRecord) {
        self.record = record
        self.id = record.recordID.recordName
        self.name = record["name"] as? String ?? ""
    }
}
