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
    var purchasedAt: Date?
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
        self.purchasedAt = record["purchasedAt"] as? Date
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
        if let purchasedAt = purchasedAt {
            record["purchasedAt"] = purchasedAt as CKRecordValue
        }
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
    var children: [CKChild]
    var hiddenChildRecordIDs: [String]

    var hasApp: Bool {
        friendUserRecordID != nil && !friendUserRecordID!.isEmpty
    }

    var visibleChildren: [CKChild] {
        children.filter { !hiddenChildRecordIDs.contains($0.id) }
    }

    init(from record: CKRecord, children: [CKChild] = []) {
        self.record = record
        self.id = record.recordID.recordName
        self.name = record["name"] as? String ?? ""
        self.phoneNumber = record["phoneNumber"] as? String
        self.email = record["email"] as? String
        self.ownerID = record["ownerID"] as? String ?? ""
        self.friendUserRecordID = record["friendUserRecordID"] as? String
        self.addedAt = record["addedAt"] as? Date ?? Date()
        self.children = children
        self.hiddenChildRecordIDs = (record["hiddenChildRecordIDs"] as? [String]) ?? []

        // Load photo from CKAsset
        if let asset = record["photo"] as? CKAsset,
           let fileURL = asset.fileURL,
           let data = try? Data(contentsOf: fileURL) {
            self.imageData = data
        }
    }
}

// MARK: - CloudKit Child

struct CKChild: Identifiable {
    let id: String
    let record: CKRecord
    var name: String
    var parentUserRecordID: String
    var createdAt: Date

    init(from record: CKRecord) {
        self.record = record
        self.id = record.recordID.recordName
        self.name = record["name"] as? String ?? ""
        self.parentUserRecordID = record["parentUserRecordID"] as? String ?? ""
        self.createdAt = record["createdAt"] as? Date ?? Date()
    }
}

// MARK: - CloudKit Purchase

struct CKPurchase: Identifiable {
    let id: String
    let record: CKRecord
    var itemRecordID: String
    var purchaserUserRecordID: String
    var purchasedAt: Date

    init(from record: CKRecord) {
        self.record = record
        self.id = record.recordID.recordName
        self.itemRecordID = record["itemRecordID"] as? String ?? ""
        self.purchaserUserRecordID = record["purchaserUserRecordID"] as? String ?? ""
        self.purchasedAt = record["purchasedAt"] as? Date ?? Date()
    }
}
