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
    @Published var shouldRefreshFriends = false

    // Polling for purchase notifications (fallback when push doesn't work)
    private var purchasePollingTask: Task<Void, Never>?
    private var lastCheckedPurchaseDate: Date?
    private var notifiedPurchaseIDs: Set<String> = []  // Track which purchases we've already notified about

    // Record Types
    enum RecordType: String {
        case wishlistItem = "WishlistItem"
        case friend = "Friend"
        case child = "Child"
        case purchase = "Purchase"
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
        let startTime = Date()
        print("⏱️ [CLOUDKIT] Checking iCloud status...")

        do {
            let status = try await container.accountStatus()
            print("⏱️ [CLOUDKIT] Account status checked in \(Date().timeIntervalSince(startTime).formatted())s")

            if status == .available {
                // Fetch user record ID BEFORE setting isSignedInToiCloud
                // This prevents race conditions where views try to load data
                // before currentUserRecordID is set
                let recordFetchStart = Date()
                currentUserRecordID = try await container.userRecordID()
                print("⏱️ [CLOUDKIT] User record ID fetched in \(Date().timeIntervalSince(recordFetchStart).formatted())s")
                print("☁️ CloudKit: Signed in with record ID: \(currentUserRecordID?.recordName ?? "unknown")")

                // Only now is it safe to notify observers that CloudKit is ready
                isSignedInToiCloud = true
                print("⏱️ [CLOUDKIT] TOTAL sign-in time: \(Date().timeIntervalSince(startTime).formatted())s")
            } else {
                print("❌ CloudKit: Not signed in to iCloud")
                isSignedInToiCloud = false
            }
        } catch {
            print("❌ CloudKit: Error checking status: \(error)")
            isSignedInToiCloud = false
        }
    }

    // MARK: - Wishlist Items

    func saveWishlistItem(name: String, url: String?, description: String?, imageData: Data?, ownerRecordID: String? = nil) async throws -> CKRecord {
        guard let userRecordID = currentUserRecordID else {
            throw CloudKitError.notSignedIn
        }

        // Use provided ownerRecordID (for children) or default to current user
        let finalOwnerID = ownerRecordID ?? userRecordID.recordName

        let record = CKRecord(recordType: RecordType.wishlistItem.rawValue)
        record["name"] = name as CKRecordValue
        record["url"] = (url ?? "") as CKRecordValue
        record["itemDescription"] = (description ?? "") as CKRecordValue
        record["isPurchased"] = false as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        record["ownerID"] = finalOwnerID as CKRecordValue
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

    func deleteFriend(_ recordID: CKRecord.ID) async throws {
        try await privateDatabase.deleteRecord(withID: recordID)
        print("☁️ CloudKit: Deleted friend")
    }

    func hideChildFromFriend(friendRecordID: CKRecord.ID, childRecordID: String) async throws {
        // Fetch the friend record
        let friendRecord = try await privateDatabase.record(for: friendRecordID)

        // Get existing hidden children or create new array
        var hiddenChildren = (friendRecord["hiddenChildRecordIDs"] as? [String]) ?? []

        // Add child to hidden list if not already there
        if !hiddenChildren.contains(childRecordID) {
            hiddenChildren.append(childRecordID)
            friendRecord["hiddenChildRecordIDs"] = hiddenChildren as CKRecordValue

            try await privateDatabase.save(friendRecord)
            print("☁️ CloudKit: Hid child \(childRecordID) from friend")
        }
    }

    func unhideChildFromFriend(friendRecordID: CKRecord.ID, childRecordID: String) async throws {
        // Fetch the friend record
        let friendRecord = try await privateDatabase.record(for: friendRecordID)

        // Get existing hidden children
        var hiddenChildren = (friendRecord["hiddenChildRecordIDs"] as? [String]) ?? []

        // Remove child from hidden list
        hiddenChildren.removeAll { $0 == childRecordID }
        friendRecord["hiddenChildRecordIDs"] = hiddenChildren as CKRecordValue

        try await privateDatabase.save(friendRecord)
        print("☁️ CloudKit: Unhid child \(childRecordID) from friend")
    }

    // MARK: - Children

    func saveChild(name: String, parentUserRecordID: String? = nil) async throws -> CKRecord {
        guard let userRecordID = currentUserRecordID else {
            throw CloudKitError.notSignedIn
        }

        // Use provided parent ID or default to current user
        let parentID = parentUserRecordID ?? userRecordID.recordName

        let record = CKRecord(recordType: RecordType.child.rawValue)
        record["name"] = name as CKRecordValue
        record["parentUserRecordID"] = parentID as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue

        // Save to PUBLIC database so friends can see children
        let savedRecord = try await publicDatabase.save(record)
        print("☁️ CloudKit: Saved child to PUBLIC database: \(name)")
        return savedRecord
    }

    func fetchMyChildren() async throws -> [CKRecord] {
        guard let userRecordID = currentUserRecordID else {
            throw CloudKitError.notSignedIn
        }

        return try await fetchChildrenForUser(userRecordID: userRecordID.recordName)
    }

    func fetchChildrenForUser(userRecordID: String) async throws -> [CKRecord] {
        let predicate = NSPredicate(format: "parentUserRecordID == %@", userRecordID)
        let query = CKQuery(recordType: RecordType.child.rawValue, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

        // Fetch from PUBLIC database
        let (results, _) = try await publicDatabase.records(matching: query)
        let records = results.compactMap { try? $0.1.get() }

        print("☁️ CloudKit: Fetched \(records.count) children for user \(userRecordID)")
        return records
    }

    func deleteChild(_ childRecordID: CKRecord.ID) async throws {
        // First, delete all wishlist items owned by this child
        let predicate = NSPredicate(format: "ownerID == %@", childRecordID.recordName)
        let query = CKQuery(recordType: RecordType.wishlistItem.rawValue, predicate: predicate)

        let (results, _) = try await publicDatabase.records(matching: query)
        let itemRecords = results.compactMap { try? $0.1.get() }

        // Delete all items
        for item in itemRecords {
            try await publicDatabase.deleteRecord(withID: item.recordID)
        }
        print("☁️ CloudKit: Deleted \(itemRecords.count) wishlist items for child")

        // Then delete the child record itself
        try await publicDatabase.deleteRecord(withID: childRecordID)
        print("☁️ CloudKit: Deleted child")
    }

    // MARK: - Purchases

    func savePurchase(itemRecordID: String) async throws -> CKRecord {
        guard let userRecordID = currentUserRecordID else {
            throw CloudKitError.notSignedIn
        }

        let record = CKRecord(recordType: RecordType.purchase.rawValue)
        record["itemRecordID"] = itemRecordID as CKRecordValue
        record["purchaserUserRecordID"] = userRecordID.recordName as CKRecordValue
        record["purchasedAt"] = Date() as CKRecordValue

        // Save to PUBLIC database so the item owner can see who purchased
        let savedRecord = try await publicDatabase.save(record)
        print("☁️ CloudKit: Saved purchase for item: \(itemRecordID)")
        return savedRecord
    }

    func fetchPurchasesForItem(itemRecordID: String) async throws -> [CKRecord] {
        let predicate = NSPredicate(format: "itemRecordID == %@", itemRecordID)
        let query = CKQuery(recordType: RecordType.purchase.rawValue, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "purchasedAt", ascending: false)]

        do {
            let (results, _) = try await publicDatabase.records(matching: query)
            let records = results.compactMap { try? $0.1.get() }

            print("☁️ CloudKit: Fetched \(records.count) purchases for item \(itemRecordID)")
            return records
        } catch let error as CKError where error.code == .unknownItem {
            // Record type doesn't exist yet - this is fine, just means no purchases exist
            print("ℹ️ CloudKit: Purchase record type doesn't exist yet (will be created on first save)")
            return []
        }
    }

    func fetchMyPurchases() async throws -> [CKRecord] {
        guard let userRecordID = currentUserRecordID else {
            throw CloudKitError.notSignedIn
        }

        let predicate = NSPredicate(format: "purchaserUserRecordID == %@", userRecordID.recordName)
        let query = CKQuery(recordType: RecordType.purchase.rawValue, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "purchasedAt", ascending: false)]

        do {
            let (results, _) = try await publicDatabase.records(matching: query)
            let records = results.compactMap { try? $0.1.get() }

            print("☁️ CloudKit: Fetched \(records.count) my purchases")
            return records
        } catch let error as CKError where error.code == .unknownItem {
            // Record type doesn't exist yet - this is fine, just means no purchases exist
            print("ℹ️ CloudKit: Purchase record type doesn't exist yet (will be created on first save)")
            return []
        }
    }

    func deletePurchase(_ recordID: CKRecord.ID) async throws {
        try await publicDatabase.deleteRecord(withID: recordID)
        print("☁️ CloudKit: Deleted purchase")
    }

    // MARK: - User Discovery

    func requestDiscoverabilityPermission() async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            container.status(forApplicationPermission: .userDiscoverability) { status, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                switch status {
                case .granted:
                    print("☁️ CloudKit: User discoverability permission already granted")
                    continuation.resume(returning: true)

                case .denied:
                    print("❌ CloudKit: User discoverability permission denied")
                    continuation.resume(returning: false)

                case .couldNotComplete:
                    print("❌ CloudKit: Could not determine discoverability permission status")
                    continuation.resume(returning: false)

                case .initialState:
                    // Request permission
                    print("☁️ CloudKit: Requesting user discoverability permission...")
                    self.container.requestApplicationPermission(.userDiscoverability) { newStatus, requestError in
                        if let requestError = requestError {
                            print("❌ CloudKit: Error requesting permission: \(requestError.localizedDescription)")
                            continuation.resume(returning: false)
                        } else {
                            let granted = newStatus == .granted
                            print(granted ? "✅ CloudKit: User discoverability permission granted" : "❌ CloudKit: User discoverability permission denied")
                            continuation.resume(returning: granted)
                        }
                    }

                @unknown default:
                    continuation.resume(returning: false)
                }
            }
        }
    }

    func discoverUserByPhoneNumber(_ phoneNumber: String) async throws -> CKRecord.ID? {
        print("🔍 Attempting to discover user by phone: \(phoneNumber)")

        // First check/request permission for user discoverability
        let hasPermission = try await requestDiscoverabilityPermission()
        guard hasPermission else {
            print("❌ Cannot discover users: permission not granted")
            return nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            container.discoverUserIdentity(withPhoneNumber: phoneNumber) { userIdentity, error in
                if let error = error {
                    let ckError = error as? CKError
                    switch ckError?.code {
                    case .unknownItem:
                        print("ℹ️ No user found with phone: \(phoneNumber)")
                        continuation.resume(returning: nil)
                    case .networkFailure, .networkUnavailable:
                        print("❌ Network error during user discovery: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    default:
                        print("❌ CloudKit error during user discovery: \(error.localizedDescription)")
                        continuation.resume(returning: nil)
                    }
                    return
                }

                if let userIdentity = userIdentity, let recordID = userIdentity.userRecordID {
                    print("✅ Found user with phone record ID: \(recordID.recordName)")
                    continuation.resume(returning: recordID)
                } else {
                    print("ℹ️ User identity found but no record ID available")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    func discoverUserByEmail(_ email: String) async throws -> CKRecord.ID? {
        print("🔍 Attempting to discover user by email: \(email)")

        // First check/request permission for user discoverability
        let hasPermission = try await requestDiscoverabilityPermission()
        guard hasPermission else {
            print("❌ Cannot discover users: permission not granted")
            return nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            container.discoverUserIdentity(withEmailAddress: email) { userIdentity, error in
                if let error = error {
                    let ckError = error as? CKError
                    switch ckError?.code {
                    case .unknownItem:
                        print("ℹ️ No user found with email: \(email)")
                        continuation.resume(returning: nil)
                    case .networkFailure, .networkUnavailable:
                        print("❌ Network error during user discovery: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    default:
                        print("❌ CloudKit error during user discovery: \(error.localizedDescription)")
                        continuation.resume(returning: nil)
                    }
                    return
                }

                if let userIdentity = userIdentity, let recordID = userIdentity.userRecordID {
                    print("✅ Found user with email record ID: \(recordID.recordName)")
                    continuation.resume(returning: recordID)
                } else {
                    print("ℹ️ User identity found but no record ID available")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Discover a user by trying both phone number and email
    func discoverUser(phoneNumber: String?, email: String?) async throws -> CKRecord.ID? {
        // First check if we're trying to discover ourselves
        // CloudKit discovery doesn't work for your own account, so check directly
        if let myRecordID = currentUserRecordID {
            // Try to get our own contact info to compare
            let myUserIdentity = try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKUserIdentity?, Error>) in
                container.fetchUserRecordID { recordID, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }

                    if let recordID = recordID {
                        self.container.discoverUserIdentity(withUserRecordID: recordID) { identity, error in
                            if let error = error {
                                continuation.resume(returning: nil)
                            } else {
                                continuation.resume(returning: identity)
                            }
                        }
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }

            // Note: We can't reliably compare contact info due to API limitations
            // Just log that we tried
            if myUserIdentity != nil {
                print("ℹ️ Checked current user identity for self-match")
            }
        }

        // Try phone number first (more reliable)
        if let phoneNumber = phoneNumber, !phoneNumber.isEmpty {
            if let recordID = try await discoverUserByPhoneNumber(phoneNumber) {
                return recordID
            }
        }

        // Fall back to email
        if let email = email, !email.isEmpty {
            if let recordID = try await discoverUserByEmail(email) {
                return recordID
            }
        }

        return nil
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

    /// Fetch all active subscriptions to help debug
    func fetchAllSubscriptions() async throws -> [CKSubscription] {
        print("🔍 [SUBSCRIPTION] Fetching all active subscriptions...")
        let subscriptions = try await publicDatabase.allSubscriptions()
        print("📋 [SUBSCRIPTION] Found \(subscriptions.count) active subscriptions:")
        for subscription in subscriptions {
            print("   - \(subscription.subscriptionID)")
        }
        return subscriptions
    }

    /// Delete a specific subscription by ID
    func deleteSubscription(withID subscriptionID: String) async throws {
        print("🗑️ [SUBSCRIPTION] Deleting subscription: \(subscriptionID)")
        try await publicDatabase.deleteSubscription(withID: subscriptionID)
        print("✅ [SUBSCRIPTION] Successfully deleted subscription: \(subscriptionID)")
    }

    /// Delete all subscriptions (useful for debugging)
    func deleteAllSubscriptions() async throws {
        print("🗑️ [SUBSCRIPTION] Deleting all subscriptions...")
        let subscriptions = try await fetchAllSubscriptions()
        for subscription in subscriptions {
            try await deleteSubscription(withID: subscription.subscriptionID)
        }
        print("✅ [SUBSCRIPTION] All subscriptions deleted")
    }

    /// Re-subscribe to all notifications (useful after debugging)
    func resubscribeToAll() async throws {
        print("🔄 [SUBSCRIPTION] Re-subscribing to all notifications...")

        // Delete existing subscriptions first
        do {
            try await deleteAllSubscriptions()
        } catch {
            print("⚠️ [SUBSCRIPTION] Error deleting existing subscriptions (might not exist): \(error)")
        }

        // Subscribe fresh
        try await subscribeToMyWishlistChanges()
        try await subscribeToPurchases()

        print("✅ [SUBSCRIPTION] Successfully re-subscribed to all notifications")
    }

    func subscribeToMyWishlistChanges() async throws {
        guard let userRecordID = currentUserRecordID else {
            throw CloudKitError.notSignedIn
        }

        // Subscribe to changes on MY wishlist items only
        let subscriptionID = "my-wishlist-changes"
        let predicate = NSPredicate(format: "ownerID == %@", userRecordID.recordName)
        let subscription = CKQuerySubscription(
            recordType: RecordType.wishlistItem.rawValue,
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordUpdate]  // Only fire on updates (not creation/deletion)
        )

        // Set up notification
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        notificationInfo.alertBody = "Someone updated an item on your wishlist"
        notificationInfo.soundName = "default"
        subscription.notificationInfo = notificationInfo

        do {
            try await publicDatabase.save(subscription)  // Save to PUBLIC database
            print("☁️ CloudKit: Subscribed to my wishlist changes")
        } catch {
            // Subscription might already exist, that's ok
            print("☁️ CloudKit: Subscription already exists or error: \(error)")
        }
    }

    func subscribeToPurchases() async throws {
        guard let userRecordID = currentUserRecordID else {
            throw CloudKitError.notSignedIn
        }

        // Subscribe to Purchase records created for ANY items
        // We filter in the notification handler to only process purchases for our items
        let subscriptionID = "my-items-purchases"

        print("📢 [SUBSCRIPTION] Attempting to subscribe to purchases for user: \(userRecordID.recordName)")

        // Create predicate that fires when ANY Purchase is created
        // We'll check ownership in handlePurchaseNotification
        let predicate = NSPredicate(value: true)
        let subscription = CKQuerySubscription(
            recordType: RecordType.purchase.rawValue,
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation]
        )

        // Set up SILENT notification - we'll create the alert in the handler
        // This way we can include the actual item name in the notification
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true  // Silent push to wake app
        // DON'T set alertBody or soundName - we'll send the local notification from the handler

        // Add these to help with debugging
        notificationInfo.desiredKeys = ["itemRecordID", "purchaserUserRecordID", "purchasedAt"]

        subscription.notificationInfo = notificationInfo

        do {
            let savedSubscription = try await publicDatabase.save(subscription)
            print("✅ [SUBSCRIPTION] Successfully subscribed to purchase notifications")
            print("📋 [SUBSCRIPTION] Subscription ID: \(savedSubscription.subscriptionID)")
            print("📋 [SUBSCRIPTION] Notification config: alert=\(notificationInfo.alertBody ?? "none"), contentAvailable=\(notificationInfo.shouldSendContentAvailable)")
        } catch let error as CKError {
            // Check if subscription already exists
            if error.code == .serverRecordChanged {
                print("ℹ️ [SUBSCRIPTION] Subscription already exists (this is normal)")
            } else {
                print("❌ [SUBSCRIPTION] Failed to subscribe: \(error.localizedDescription)")
                print("❌ [SUBSCRIPTION] Error code: \(error.code)")
                print("❌ [SUBSCRIPTION] Error details: \(error)")
                throw error
            }
        } catch {
            print("❌ [SUBSCRIPTION] Unexpected error: \(error)")
            throw error
        }
    }

    func handlePurchaseNotification(recordID: CKRecord.ID) async throws {
        print("🔔 [NOTIFICATION] Handling notification for record: \(recordID.recordName)")

        // Fetch the record to determine if it's a Purchase or WishlistItem
        let record = try await publicDatabase.record(for: recordID)
        print("📋 [NOTIFICATION] Fetched record type: \(record.recordType)")

        if record.recordType == RecordType.purchase.rawValue {
            // This is a Purchase record notification
            guard let itemRecordID = record["itemRecordID"] as? String else {
                print("⚠️ [NOTIFICATION] Purchase record missing itemRecordID")
                return
            }

            print("🔍 [NOTIFICATION] Fetching item details for: \(itemRecordID)")

            // Fetch the item to get its name and check if it's mine
            do {
                let itemRecord = try await publicDatabase.record(for: CKRecord.ID(recordName: itemRecordID))

                // Check if this item belongs to me
                guard let ownerID = itemRecord["ownerID"] as? String else {
                    print("⚠️ [NOTIFICATION] Item missing ownerID")
                    return
                }

                guard let itemName = itemRecord["name"] as? String else {
                    print("⚠️ [NOTIFICATION] Item missing name")
                    return
                }

                print("👤 [NOTIFICATION] Item owner: \(ownerID)")
                print("👤 [NOTIFICATION] Current user: \(currentUserRecordID?.recordName ?? "unknown")")

                if ownerID == currentUserRecordID?.recordName {
                    print("✅ [NOTIFICATION] Item belongs to me! Sending local notification...")

                    // Track this purchase to avoid duplicates from polling
                    notifiedPurchaseIDs.insert(recordID.recordName)

                    // Send local notification
                    await NotificationManager.shared.sendItemPurchasedNotification(
                        itemName: itemName,
                        friendName: "Someone"
                    )

                    print("✅ [NOTIFICATION] Local notification sent for '\(itemName)'")
                } else {
                    print("ℹ️ [NOTIFICATION] Item belongs to someone else, skipping notification")
                }
            } catch {
                print("❌ [NOTIFICATION] Failed to fetch item for purchase notification: \(error)")
            }
        } else if record.recordType == RecordType.wishlistItem.rawValue {
            // Legacy: WishlistItem update notification (old system)
            print("ℹ️ [NOTIFICATION] Received legacy WishlistItem update notification")
            guard let isPurchased = record["isPurchased"] as? Bool,
                  isPurchased,
                  let itemName = record["name"] as? String else {
                print("⚠️ [NOTIFICATION] Legacy notification missing required fields")
                return
            }

            print("✅ [NOTIFICATION] Sending notification for legacy item: \(itemName)")
            await NotificationManager.shared.sendItemPurchasedNotification(
                itemName: itemName,
                friendName: "Someone"
            )
        } else {
            print("⚠️ [NOTIFICATION] Unknown record type: \(record.recordType)")
        }
    }

    // MARK: - Purchase Polling (Fallback)

    /// Start polling for new purchases (fallback when CloudKit push doesn't work)
    func startPurchasePolling(interval: TimeInterval = 30) {
        // Stop any existing polling
        stopPurchasePolling()

        print("🔄 [POLLING] Starting purchase polling (checking every \(Int(interval))s)")

        // Initialize last checked date to now
        if lastCheckedPurchaseDate == nil {
            lastCheckedPurchaseDate = Date()
        }

        purchasePollingTask = Task {
            while !Task.isCancelled {
                do {
                    // Wait for the interval
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))

                    // Check for new purchases
                    await checkForNewPurchases()
                } catch {
                    // Task was cancelled or sleep failed
                    break
                }
            }
        }
    }

    /// Stop purchase polling
    func stopPurchasePolling() {
        purchasePollingTask?.cancel()
        purchasePollingTask = nil
        print("⏹️ [POLLING] Stopped purchase polling")
    }

    /// Check for new purchases since last check
    private func checkForNewPurchases() async {
        guard let userRecordID = currentUserRecordID else { return }
        guard let lastChecked = lastCheckedPurchaseDate else { return }

        do {
            // Fetch all my items
            let myItems = try await fetchMyWishlistItems()

            // Check purchases for each item
            for item in myItems {
                let purchases = try await fetchPurchasesForItem(itemRecordID: item.recordID.recordName)

                // Find purchases created after last check
                for purchase in purchases {
                    let purchaseID = purchase.recordID.recordName

                    // Skip if we already notified about this purchase (from CloudKit push)
                    if notifiedPurchaseIDs.contains(purchaseID) {
                        print("⏭️ [POLLING] Skipping purchase \(purchaseID) - already notified")
                        continue
                    }

                    guard let purchasedAt = purchase["purchasedAt"] as? Date else { continue }
                    guard let purchaserID = purchase["purchaserUserRecordID"] as? String else { continue }

                    // Skip if this purchase is from before our last check
                    if purchasedAt <= lastChecked { continue }

                    // Skip if I purchased it myself
                    if purchaserID == userRecordID.recordName { continue }

                    // This is a new purchase from someone else!
                    guard let itemName = item["name"] as? String else { continue }

                    print("🆕 [POLLING] Found new purchase for '\(itemName)' at \(purchasedAt)")

                    // Track this purchase to avoid duplicates
                    notifiedPurchaseIDs.insert(purchaseID)

                    // Send notification
                    await NotificationManager.shared.sendItemPurchasedNotification(
                        itemName: itemName,
                        friendName: "Someone"
                    )
                }
            }

            // Update last checked time
            lastCheckedPurchaseDate = Date()

        } catch {
            print("❌ [POLLING] Error checking for purchases: \(error)")
        }
    }
}

// MARK: - Errors

enum CloudKitError: LocalizedError {
    case notSignedIn
    case imageConversionFailed
    case quotaExceeded(retryAfterSeconds: TimeInterval)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Not signed in to iCloud"
        case .imageConversionFailed:
            return "Failed to convert image"
        case .quotaExceeded(let seconds):
            let minutes = Int(seconds / 60)
            if minutes > 0 {
                return "CloudKit quota exceeded. Please wait \(minutes) minute\(minutes == 1 ? "" : "s") and try again."
            } else {
                return "CloudKit quota exceeded. Please wait a moment and try again."
            }
        }
    }
}

// MARK: - CKError Extension

extension CKError {
    /// User-friendly error message for display
    var userFriendlyMessage: String {
        switch self.code {
        case .quotaExceeded:
            if let retryAfter = self.retryAfterSeconds {
                let minutes = Int(retryAfter / 60)
                if minutes > 0 {
                    return "CloudKit quota exceeded. Please wait about \(minutes) minute\(minutes == 1 ? "" : "s") and try again.\n\nThis happens during testing with frequent operations."
                } else {
                    return "CloudKit quota exceeded. Please wait a moment and try again."
                }
            }
            return "CloudKit quota exceeded. Please try again in a few minutes."

        case .networkFailure, .networkUnavailable:
            return "Network connection issue. Please check your internet connection."

        case .notAuthenticated:
            return "Please sign in to iCloud in Settings."

        case .serverRejectedRequest:
            return "Server rejected the request. Please try again later."

        case .serviceUnavailable:
            return "CloudKit service is temporarily unavailable. Please try again later."

        default:
            return self.localizedDescription
        }
    }

    /// Returns retry time in seconds if this is a quota exceeded error
    var retryAfterSeconds: TimeInterval? {
        guard code == .quotaExceeded else { return nil }
        return userInfo[CKErrorRetryAfterKey] as? TimeInterval
    }

    /// Whether this error suggests the user should retry
    var shouldRetry: Bool {
        switch code {
        case .quotaExceeded, .networkFailure, .networkUnavailable, .serviceUnavailable:
            return true
        default:
            return false
        }
    }
}
