//
//  CloudKitManager.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import CloudKit
import Foundation
import UIKit
import Combine

@MainActor
class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()

    private let container: CKContainer
    private let publicDatabase: CKDatabase
    private let privateDatabase: CKDatabase

    @Published var currentUserRecordID: CKRecord.ID?
    @Published var isSignedInToiCloud = false

    // Record Types
    enum RecordType: String {
        case wishlistItem = "WishlistItem"
        case friend = "Friend"
        case user = "User"
    }

    private init() {
        container = CKContainer(identifier: "iCloud.com.designoverhaul.ChristmasWishlist")
        publicDatabase = container.publicCloudDatabase
        privateDatabase = container.privateCloudDatabase

        Task {
            await checkiCloudStatus()
        }
    }

    // MARK: - iCloud Status

    func checkiCloudStatus() async {
        do {
            let status = try await container.accountStatus()
            isSignedInToiCloud = (status == .available)

            if isSignedInToiCloud {
                currentUserRecordID = try await container.userRecordID()
                print("☁️ CloudKit: Signed in with record ID: \(currentUserRecordID?.recordName ?? "unknown")")
            } else {
                print("❌ CloudKit: Not signed in to iCloud")
            }
        } catch {
            print("❌ CloudKit: Error checking status: \(error)")
            isSignedInToiCloud = false
        }
    }

    // MARK: - Wishlist Items

    func saveWishlistItem(name: String, url: String?, description: String?, imageData: Data?) async throws -> CKRecord {
        guard let userRecordID = currentUserRecordID else {
            throw CloudKitError.notSignedIn
        }

        let record = CKRecord(recordType: RecordType.wishlistItem.rawValue)
        record["name"] = name as CKRecordValue
        record["url"] = (url ?? "") as CKRecordValue
        record["itemDescription"] = (description ?? "") as CKRecordValue
        record["isPurchased"] = false as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        record["ownerID"] = userRecordID.recordName as CKRecordValue
        record["ownerReference"] = CKRecord.Reference(recordID: userRecordID, action: .none)

        // Handle image
        if let imageData = imageData, let image = UIImage(data: imageData) {
            if let asset = try? createImageAsset(from: image) {
                record["image"] = asset
            }
        }

        // Save to PUBLIC database so friends can see it
        let savedRecord = try await publicDatabase.save(record)
        print("☁️ CloudKit: Saved wishlist item to PUBLIC database: \(name)")
        return savedRecord
    }

    func fetchMyWishlistItems() async throws -> [CKRecord] {
        guard let userRecordID = currentUserRecordID else {
            throw CloudKitError.notSignedIn
        }

        let predicate = NSPredicate(format: "ownerID == %@", userRecordID.recordName)
        let query = CKQuery(recordType: RecordType.wishlistItem.rawValue, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        // Fetch from PUBLIC database
        let (results, _) = try await publicDatabase.records(matching: query)
        let records = results.compactMap { try? $0.1.get() }

        print("☁️ CloudKit: Fetched \(records.count) MY wishlist items from PUBLIC database")
        return records
    }

    func fetchFriendWishlistItems(friendRecordID: String) async throws -> [CKRecord] {
        let predicate = NSPredicate(format: "ownerID == %@", friendRecordID)
        let query = CKQuery(recordType: RecordType.wishlistItem.rawValue, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        // Fetch from PUBLIC database
        let (results, _) = try await publicDatabase.records(matching: query)
        let records = results.compactMap { try? $0.1.get() }

        print("☁️ CloudKit: Fetched \(records.count) items for friend \(friendRecordID)")
        return records
    }

    func deleteWishlistItem(_ recordID: CKRecord.ID) async throws {
        try await publicDatabase.deleteRecord(withID: recordID)
        print("☁️ CloudKit: Deleted wishlist item")
    }

    func updateWishlistItem(_ record: CKRecord) async throws {
        try await publicDatabase.save(record)
        print("☁️ CloudKit: Updated wishlist item")
    }

    // MARK: - Friends

    func saveFriend(name: String, phoneNumber: String?, email: String?, imageData: Data?, friendUserRecordID: String?) async throws -> CKRecord {
        guard let userRecordID = currentUserRecordID else {
            throw CloudKitError.notSignedIn
        }

        let record = CKRecord(recordType: RecordType.friend.rawValue)
        record["name"] = name as CKRecordValue
        record["phoneNumber"] = (phoneNumber ?? "") as CKRecordValue
        record["email"] = (email ?? "") as CKRecordValue
        record["ownerID"] = userRecordID.recordName as CKRecordValue
        record["friendUserRecordID"] = (friendUserRecordID ?? "") as CKRecordValue
        record["addedAt"] = Date() as CKRecordValue

        // Handle image
        if let imageData = imageData, let image = UIImage(data: imageData) {
            if let asset = try? createImageAsset(from: image) {
                record["photo"] = asset
            }
        }

        let savedRecord = try await privateDatabase.save(record)
        print("☁️ CloudKit: Saved friend: \(name)")
        return savedRecord
    }

    func fetchMyFriends() async throws -> [CKRecord] {
        guard let userRecordID = currentUserRecordID else {
            throw CloudKitError.notSignedIn
        }

        let predicate = NSPredicate(format: "ownerID == %@", userRecordID.recordName)
        let query = CKQuery(recordType: RecordType.friend.rawValue, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

        let (results, _) = try await privateDatabase.records(matching: query)
        let records = results.compactMap { try? $0.1.get() }

        print("☁️ CloudKit: Fetched \(records.count) friends")
        return records
    }

    // MARK: - User Discovery

    func discoverUserByEmail(_ email: String) async throws -> CKRecord.ID? {
        // CloudKit user discovery by email
        // For now, return nil - will implement full discovery later
        // TODO: Implement using container.discoverUserIdentity(forEmailAddress:)
        return nil
    }

    // MARK: - User Profile

    func saveUserProfile(name: String) async throws -> CKRecord {
        guard let userRecordID = currentUserRecordID else {
            throw CloudKitError.notSignedIn
        }

        // Check if user profile already exists
        let predicate = NSPredicate(format: "recordID == %@", userRecordID)
        let query = CKQuery(recordType: RecordType.user.rawValue, predicate: predicate)

        let (results, _) = try await privateDatabase.records(matching: query)

        let record: CKRecord
        if let existingRecord = results.first?.1, case .success(let existing) = existingRecord {
            record = existing
        } else {
            record = CKRecord(recordType: RecordType.user.rawValue, recordID: userRecordID)
        }

        record["name"] = name as CKRecordValue

        let savedRecord = try await privateDatabase.save(record)
        print("☁️ CloudKit: Saved user profile")
        return savedRecord
    }

    // MARK: - Helper Methods

    private func createImageAsset(from image: UIImage) throws -> CKAsset {
        guard let data = image.jpegData(compressionQuality: 0.7) else {
            throw CloudKitError.imageConversionFailed
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")

        try data.write(to: tempURL)
        return CKAsset(fileURL: tempURL)
    }

    // MARK: - Subscriptions (for real-time updates)

    func subscribeToChanges() async throws {
        // Subscribe to wishlist item changes
        let subscriptionID = "wishlist-changes"
        let subscription = CKQuerySubscription(
            recordType: RecordType.wishlistItem.rawValue,
            predicate: NSPredicate(value: true),
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )

        let notification = CKSubscription.NotificationInfo()
        notification.shouldSendContentAvailable = true
        subscription.notificationInfo = notification

        do {
            try await privateDatabase.save(subscription)
            print("☁️ CloudKit: Subscribed to changes")
        } catch {
            // Subscription might already exist, that's ok
            print("☁️ CloudKit: Subscription already exists or error: \(error)")
        }
    }
}

// MARK: - Errors

enum CloudKitError: LocalizedError {
    case notSignedIn
    case imageConversionFailed

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Not signed in to iCloud"
        case .imageConversionFailed:
            return "Failed to convert image"
        }
    }
}
