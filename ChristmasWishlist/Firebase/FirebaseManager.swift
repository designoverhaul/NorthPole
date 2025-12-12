//
//  FirebaseManager.swift
//  ChristmasWishlist
//
//  Created by Claude Code on 12/10/24.
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.designoverhaul.ChristmasWishlist", category: "Firebase")

@MainActor
class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()

    private let db = Firestore.firestore()
    private let storage = FirebaseStorageManager.shared
    private let auth = FirebaseAuthManager.shared

    @Published var shouldRefreshChildren = false
    @Published var shouldRefreshFriends = false
    @Published var isAuthenticated = false

    private init() {
        logger.info("✅ [FIREBASE] FirebaseManager initialized")

        // Listen to auth state changes
        Task {
            for await isAuth in auth.$isAuthenticated.values {
                self.isAuthenticated = isAuth
                logger.info("🔄 [FIREBASE] Auth state changed: \(isAuth)")
            }
        }
    }

    // MARK: - Helper Methods

    /// Normalize phone number to digits only
    private func normalizePhone(_ phone: String) -> String {
        return phone.filter { $0.isNumber }
    }

    /// Get current user's normalized phone number
    private var currentUserPhone: String? {
        return auth.currentUserPhone
    }

    // MARK: - Wishlist Items

    /// Save wishlist item to Firestore (local-first: save to SwiftData before calling this)
    func saveWishlistItem(
        id: UUID,
        name: String,
        url: String?,
        description: String?,
        imageData: Data?,
        ownerId: UUID,
        ownerType: String,  // "user" or "child"
        childId: String?,
        context: ModelContext
    ) async throws -> String {
        guard let userPhone = currentUserPhone else {
            throw FirebaseError.notAuthenticated
        }

        logger.info("💾 [FIREBASE] Saving wishlist item: \(name)")

        // Upload image if exists
        var imageUrl: String? = nil
        if let data = imageData {
            imageUrl = try? await storage.uploadWishlistItemImage(itemId: id.uuidString, imageData: data)
        }

        // Create Firestore document
        var itemData: [String: Any] = [
            "name": name,
            "url": url ?? "",
            "itemDescription": description ?? "",
            "imageUrl": imageUrl ?? "",
            "createdAt": Timestamp(),
            "ownerPhone": userPhone,
            "ownerType": ownerType,
            "isPurchased": false
        ]
        
        // Only include childId if it's not nil/empty (for child items)
        if let childId = childId, !childId.isEmpty {
            itemData["childId"] = childId
            logger.info("   Saving with childId: \(childId)")
        } else {
            logger.info("   Saving without childId (user item)")
        }

        let docRef = db.collection("wishlistItems").document(id.uuidString)
        try await docRef.setData(itemData)

        logger.info("✅ [FIREBASE] Wishlist item saved: \(id.uuidString)")
        return id.uuidString
    }

    /// Fetch current user's wishlist items from Firestore and merge with SwiftData
    func fetchMyWishlistItems(context: ModelContext) async throws -> [WishlistItem] {
        guard let userPhone = currentUserPhone else {
            throw FirebaseError.notAuthenticated
        }

        logger.info("📥 [FIREBASE] Fetching wishlist items for: \(userPhone)")

        // Return local items immediately
        let descriptor = FetchDescriptor<WishlistItem>()
        let localItems = try context.fetch(descriptor)
        logger.info("📱 [FIREBASE] Returning \(localItems.count) local items immediately")

        // Sync from Firestore in background
        Task.detached { @MainActor in
            await self.syncWishlistItemsFromFirestore(userPhone: userPhone, context: context)
        }

        return localItems
    }

    /// Background sync: Fetch items from Firestore and merge with local SwiftData
    private func syncWishlistItemsFromFirestore(userPhone: String, context: ModelContext) async {
        do {
            let snapshot = try await db.collection("wishlistItems")
                .whereField("ownerPhone", isEqualTo: userPhone)
                .order(by: "createdAt", descending: true)
                .getDocuments()

            logger.info("☁️ [FIREBASE] Fetched \(snapshot.documents.count) items from Firestore")

            for doc in snapshot.documents {
                guard let firestoreItem = FirestoreWishlistItem.from(document: doc) else { continue }

                // Check if exists locally
                let itemId = UUID(uuidString: doc.documentID) ?? UUID()
                let descriptor = FetchDescriptor<WishlistItem>(
                    predicate: #Predicate { $0.id == itemId }
                )

                let existing = try? context.fetch(descriptor).first

                if let existing = existing {
                    // Update existing
                    existing.name = firestoreItem.name
                    existing.url = firestoreItem.url
                    existing.itemDescription = firestoreItem.itemDescription
                    existing.isPurchased = firestoreItem.isPurchased
                } else {
                    // Create new
                    let newItem = WishlistItem(
                        id: itemId,
                        name: firestoreItem.name,
                        url: firestoreItem.url,
                        itemDescription: firestoreItem.itemDescription,
                        ownerId: UUID(),  // Will be set based on ownerType
                        imageData: nil    // Download image separately if needed
                    )
                    context.insert(newItem)
                }
            }

            try? context.save()
            logger.info("✅ [FIREBASE] Merged Firestore items with local SwiftData")

        } catch {
            logger.error("❌ [FIREBASE] Failed to sync items: \(error.localizedDescription)")
        }
    }

    /// Update wishlist item in Firestore
    func updateWishlistItem(id: UUID, name: String, url: String?, description: String?) async throws {
        logger.info("🔄 [FIREBASE] Updating wishlist item: \(id.uuidString)")

        let docRef = db.collection("wishlistItems").document(id.uuidString)

        let updateData: [String: Any] = [
            "name": name,
            "url": url ?? "",
            "itemDescription": description ?? ""
        ]

        try await docRef.updateData(updateData)
        logger.info("✅ [FIREBASE] Wishlist item updated")
    }

    /// Delete wishlist item from Firestore
    func deleteWishlistItem(id: UUID) async throws {
        logger.info("🗑️ [FIREBASE] Deleting wishlist item: \(id.uuidString)")

        // Delete image from Storage
        try? await storage.deleteWishlistItemImage(itemId: id.uuidString)

        // Delete document from Firestore
        let docRef = db.collection("wishlistItems").document(id.uuidString)
        try await docRef.delete()

        logger.info("✅ [FIREBASE] Wishlist item deleted")
    }

    // MARK: - Children

    /// Save child to Firestore
    func saveChild(name: String, parentPhone: String? = nil) async throws -> String {
        let phone = parentPhone ?? currentUserPhone
        guard let phone = phone else {
            throw FirebaseError.notAuthenticated
        }

        logger.info("👶 [FIREBASE] Saving child: \(name)")

        let childId = UUID().uuidString
        let childData: [String: Any] = [
            "name": name,
            "parentPhone": phone,
            "createdAt": Timestamp()
        ]

        let docRef = db.collection("children").document(childId)
        try await docRef.setData(childData)

        logger.info("✅ [FIREBASE] Child saved: \(childId)")
        return childId
    }

    /// Fetch children from Firestore
    func fetchMyChildren(context: ModelContext) async throws -> [Child] {
        guard let userPhone = currentUserPhone else {
            throw FirebaseError.notAuthenticated
        }

        logger.info("📥 [FIREBASE] Fetching children for: \(userPhone)")

        // Return local children immediately
        let descriptor = FetchDescriptor<Child>()
        let localChildren = try context.fetch(descriptor)
        logger.info("📱 [FIREBASE] Returning \(localChildren.count) local children immediately")

        // Sync from Firestore in background
        Task.detached { @MainActor in
            await self.syncChildrenFromFirestore(userPhone: userPhone, context: context)
        }

        return localChildren
    }

    /// Background sync: Fetch children from Firestore
    private func syncChildrenFromFirestore(userPhone: String, context: ModelContext) async {
        do {
            let snapshot = try await db.collection("children")
                .whereField("parentPhone", isEqualTo: userPhone)
                .order(by: "name")
                .getDocuments()

            logger.info("☁️ [FIREBASE] Fetched \(snapshot.documents.count) children from Firestore")

            for doc in snapshot.documents {
                guard let firestoreChild = FirestoreChild.from(document: doc) else { continue }

                // Check by Firestore document ID (cloudKitRecordID field)
                let childId = doc.documentID
                let descriptor = FetchDescriptor<Child>(
                    predicate: #Predicate { $0.cloudKitRecordID == childId }
                )

                let existing = try? context.fetch(descriptor).first

                if existing == nil {
                    // Create new child
                    let newChild = Child(
                        name: firestoreChild.name,
                        parentId: UUID(),  // Set to current user ID
                        cloudKitRecordID: childId
                    )
                    context.insert(newChild)
                }
            }

            try? context.save()
            logger.info("✅ [FIREBASE] Merged Firestore children with local SwiftData")
            // Note: Don't toggle shouldRefreshChildren here - it causes infinite loops
            // SwiftData will automatically update the UI when children are inserted

        } catch {
            logger.error("❌ [FIREBASE] Failed to sync children: \(error.localizedDescription)")
        }
    }

    /// Fetch children for a friend (by their phone number)
    func fetchChildrenForFriend(friendPhone: String) async throws -> [FirestoreChild] {
        let normalizedPhone = normalizePhone(friendPhone)
        logger.info("📥 [FIREBASE] Fetching children for friend: \(normalizedPhone)")

        let snapshot = try await db.collection("children")
            .whereField("parentPhone", isEqualTo: normalizedPhone)
            .order(by: "name")
            .getDocuments()

        let children = snapshot.documents.compactMap { FirestoreChild.from(document: $0) }
        logger.info("✅ [FIREBASE] Found \(children.count) children for friend")

        return children
    }

    /// Fetch children for a friend with their document IDs
    func fetchChildrenForFriendWithIds(friendPhone: String) async throws -> [(childId: String, child: FirestoreChild)] {
        let normalizedPhone = normalizePhone(friendPhone)
        logger.info("📥 [FIREBASE] Fetching children with IDs for friend: \(normalizedPhone)")

        let snapshot = try await db.collection("children")
            .whereField("parentPhone", isEqualTo: normalizedPhone)
            .order(by: "name")
            .getDocuments()

        var childrenWithIds: [(childId: String, child: FirestoreChild)] = []
        for doc in snapshot.documents {
            if let child = FirestoreChild.from(document: doc) {
                childrenWithIds.append((childId: doc.documentID, child: child))
            }
        }
        
        logger.info("✅ [FIREBASE] Found \(childrenWithIds.count) children for friend")
        return childrenWithIds
    }

    /// Delete child from Firestore
    func deleteChild(childId: String) async throws {
        logger.info("🗑️ [FIREBASE] Deleting child: \(childId)")

        // Delete all items owned by this child
        let itemsSnapshot = try await db.collection("wishlistItems")
            .whereField("childId", isEqualTo: childId)
            .getDocuments()

        for doc in itemsSnapshot.documents {
            try await doc.reference.delete()
        }

        // Delete child document
        let docRef = db.collection("children").document(childId)
        try await docRef.delete()

        logger.info("✅ [FIREBASE] Child deleted (and their items)")
        shouldRefreshChildren.toggle()
    }

    // MARK: - Friends

    /// Save friend to Firestore
    func saveFriend(friendPhone: String, friendName: String) async throws -> String {
        guard let userPhone = currentUserPhone else {
            throw FirebaseError.notAuthenticated
        }

        logger.info("👥 [FIREBASE] Saving friend: \(friendName) (\(friendPhone))")

        let normalizedFriendPhone = normalizePhone(friendPhone)
        let friendId = UUID().uuidString

        let friendData: [String: Any] = [
            "userPhone": userPhone,
            "friendPhone": normalizedFriendPhone,
            "friendName": friendName,
            "addedAt": Timestamp(),
            "hiddenChildren": []
        ]

        let docRef = db.collection("friends").document(friendId)
        try await docRef.setData(friendData)

        logger.info("✅ [FIREBASE] Friend saved: \(friendId)")
        return friendId
    }

    /// Fetch friends from Firestore
    func fetchMyFriends(context: ModelContext) async throws -> [Friend] {
        guard let userPhone = currentUserPhone else {
            throw FirebaseError.notAuthenticated
        }

        logger.info("📥 [FIREBASE] Fetching friends for: \(userPhone)")

        // Return local friends immediately
        let descriptor = FetchDescriptor<Friend>()
        let localFriends = try context.fetch(descriptor)
        logger.info("📱 [FIREBASE] Returning \(localFriends.count) local friends immediately")

        // Sync from Firestore in background
        Task.detached { @MainActor in
            await self.syncFriendsFromFirestore(userPhone: userPhone, context: context)
        }

        return localFriends
    }

    /// Background sync: Fetch friends from Firestore
    private func syncFriendsFromFirestore(userPhone: String, context: ModelContext) async {
        do {
            let snapshot = try await db.collection("friends")
                .whereField("userPhone", isEqualTo: userPhone)
                .order(by: "addedAt", descending: true)
                .getDocuments()

            logger.info("☁️ [FIREBASE] Fetched \(snapshot.documents.count) friends from Firestore")

            for doc in snapshot.documents {
                guard let firestoreFriend = FirestoreFriend.from(document: doc) else { continue }

                // Check if friend exists locally by phone number
                let friendPhone = firestoreFriend.friendPhone
                let descriptor = FetchDescriptor<Friend>(
                    predicate: #Predicate<Friend> { friend in
                        friend.phoneNumber == friendPhone
                    }
                )

                let existing = try? context.fetch(descriptor).first

                if existing == nil {
                    // Create new friend
                    let newFriend = Friend(
                        name: firestoreFriend.friendName,
                        phoneNumber: firestoreFriend.friendPhone,
                        cloudKitRecordID: doc.documentID
                    )
                    newFriend.hiddenChildRecordIDs = firestoreFriend.hiddenChildren
                    context.insert(newFriend)
                }
            }

            try? context.save()
            logger.info("✅ [FIREBASE] Merged Firestore friends with local SwiftData")
            self.shouldRefreshFriends.toggle()

        } catch {
            logger.error("❌ [FIREBASE] Failed to sync friends: \(error.localizedDescription)")
        }
    }

    /// Delete friend from Firestore
    func deleteFriend(friendId: String) async throws {
        logger.info("🗑️ [FIREBASE] Deleting friend: \(friendId)")

        let docRef = db.collection("friends").document(friendId)
        try await docRef.delete()

        logger.info("✅ [FIREBASE] Friend deleted")
        shouldRefreshFriends.toggle()
    }

    /// Check if a friend has the app by checking if their phone number exists in users collection
    func checkIfFriendHasApp(friendPhone: String) async throws -> Bool {
        let normalizedPhone = normalizePhone(friendPhone)
        logger.info("🔍 [FIREBASE] Checking if friend has app: \(normalizedPhone)")

        // Check with the normalized phone number first
        var docRef = db.collection("users").document(normalizedPhone)
        var snapshot = try await docRef.getDocument()
        
        if snapshot.exists {
            logger.info("✅ [FIREBASE] Friend has app: true (found at \(normalizedPhone))")
            return true
        }
        
        // If not found and it's a 10-digit US number, also check with country code prefix
        // Firebase Auth stores phone numbers as +1XXXXXXXXXX, which normalizes to 1XXXXXXXXXX
        if normalizedPhone.count == 10 {
            let withCountryCode = "1" + normalizedPhone
            logger.info("🔍 [FIREBASE] Also checking with country code: \(withCountryCode)")
            docRef = db.collection("users").document(withCountryCode)
            snapshot = try await docRef.getDocument()
            
            if snapshot.exists {
                logger.info("✅ [FIREBASE] Friend has app: true (found at \(withCountryCode))")
                return true
            }
        }
        
        // If not found and it starts with 1, also check without country code
        if normalizedPhone.count == 11 && normalizedPhone.hasPrefix("1") {
            let withoutCountryCode = String(normalizedPhone.dropFirst())
            logger.info("🔍 [FIREBASE] Also checking without country code: \(withoutCountryCode)")
            docRef = db.collection("users").document(withoutCountryCode)
            snapshot = try await docRef.getDocument()
            
            if snapshot.exists {
                logger.info("✅ [FIREBASE] Friend has app: true (found at \(withoutCountryCode))")
                return true
            }
        }

        logger.info("❌ [FIREBASE] Friend has app: false (checked \(normalizedPhone))")
        return false
    }

    /// Fetch wishlist items for a friend (by their phone number) or a child (by childId)
    func fetchFriendWishlistItems(ownerPhone: String?, childId: String? = nil) async throws -> [FirestoreWishlistItem] {
        let result = try await fetchFriendWishlistItemsWithIds(ownerPhone: ownerPhone, childId: childId)
        return result.map { $0.item }
    }
    
    /// Fetch wishlist items with their document IDs
    func fetchFriendWishlistItemsWithIds(ownerPhone: String?, childId: String? = nil) async throws -> [(itemId: String, item: FirestoreWishlistItem)] {
        logger.info("📥 [FIREBASE] Fetching wishlist items for friend")

        if let childId = childId, !childId.isEmpty {
            // Fetch items for a specific child
            logger.info("   Child ID: \(childId)")
            
            // Query by childId - this should find items saved with the Firebase document ID
            var query = db.collection("wishlistItems").whereField("childId", isEqualTo: childId)
            var snapshot = try await query.getDocuments()
            
            logger.info("   Query by childId returned \(snapshot.documents.count) documents")
            
            var itemsWithIds: [(itemId: String, item: FirestoreWishlistItem)] = []
            for doc in snapshot.documents {
                if let item = FirestoreWishlistItem.from(document: doc) {
                    itemsWithIds.append((itemId: doc.documentID, item: item))
                    logger.info("   ✅ Item: \(item.name), childId: \(item.childId ?? "nil")")
                }
            }
            
            // If no items found, check if items were saved with wrong childId format
            // (e.g., SwiftData UUID instead of Firebase document ID)
            // We need to get the parent phone from the child document to query
            if itemsWithIds.isEmpty {
                logger.warning("   ⚠️ No items found with childId \(childId)")
                logger.warning("   ⚠️ This suggests items may have been saved with wrong childId format")
                logger.warning("   ⚠️ Checking if we can find items by querying parent's items...")
                
                // Try to find the child document to get parent phone
                let childDoc = try? await db.collection("children").document(childId).getDocument()
                if let childData = childDoc?.data(),
                   let parentPhone = childData["parentPhone"] as? String {
                    logger.info("   Found parent phone: \(parentPhone)")
                    let allItemsQuery = try await db.collection("wishlistItems")
                        .whereField("ownerPhone", isEqualTo: normalizePhone(parentPhone))
                        .getDocuments()
                    
                    logger.info("   Found \(allItemsQuery.documents.count) total items for parentPhone")
                    var foundPotentialChildItems = false
                    for doc in allItemsQuery.documents {
                        let data = doc.data()
                        let itemChildId = data["childId"] as? String
                        let itemName = data["name"] as? String ?? "unknown"
                        let itemOwnerType = data["ownerType"] as? String ?? "unknown"
                        logger.info("   Item '\(itemName)': ownerType=\(itemOwnerType), childId=\(itemChildId ?? "nil")")
                        
                        // Check if this item might be a child item that was saved incorrectly
                        let hasEmptyChildId = itemChildId == nil || itemChildId?.isEmpty == true
                        if itemOwnerType == "user" && hasEmptyChildId {
                            logger.warning("   ⚠️ Item '\(itemName)' has ownerType=user but no childId")
                            logger.warning("   ⚠️ This item might belong to a child but was saved incorrectly!")
                            logger.warning("   ⚠️ SOLUTION: Delete and re-add this item to the child account")
                            foundPotentialChildItems = true
                        }
                    }
                    if foundPotentialChildItems {
                        logger.error("   ❌ Found items that may belong to children but were saved as user items")
                        logger.error("   ❌ These items need to be deleted and re-added to the correct child account")
                    }
                }
            }
            
            itemsWithIds.sort { $0.item.createdAt.toDate > $1.item.createdAt.toDate }
            logger.info("✅ [FIREBASE] Found \(itemsWithIds.count) wishlist items for child")
            return itemsWithIds
        } else if let ownerPhone = ownerPhone {
            // Fetch items for a user (not a child)
            // Need to check both formats: with and without country code
            let normalizedPhone = normalizePhone(ownerPhone)
            logger.info("   Owner phone: \(normalizedPhone)")
            
            var allItems: [(itemId: String, item: FirestoreWishlistItem)] = []
            var seenIds = Set<String>()
            
            // Check with the provided phone number format
            var query = db.collection("wishlistItems")
                .whereField("ownerPhone", isEqualTo: normalizedPhone)
                .whereField("ownerType", isEqualTo: "user")
            var snapshot = try await query.getDocuments()
            
            for doc in snapshot.documents {
                if let item = FirestoreWishlistItem.from(document: doc), 
                   !seenIds.contains(doc.documentID) {
                    // Only include user items (exclude child items)
                    // Child items have a non-empty childId, user items have nil or empty childId
                    let isUserItem = (item.childId == nil || item.childId?.isEmpty == true)
                    if isUserItem {
                        allItems.append((itemId: doc.documentID, item: item))
                        seenIds.insert(doc.documentID)
                    } else {
                        logger.info("   Excluding child item: \(item.name) (childId: \(item.childId ?? "nil"))")
                    }
                }
            }
            
            // If it's a 10-digit number, also check with country code
            if normalizedPhone.count == 10 {
                let withCountryCode = "1" + normalizedPhone
                logger.info("   Also checking with country code: \(withCountryCode)")
                query = db.collection("wishlistItems")
                    .whereField("ownerPhone", isEqualTo: withCountryCode)
                    .whereField("ownerType", isEqualTo: "user")
                snapshot = try await query.getDocuments()
                
                for doc in snapshot.documents {
                    if let item = FirestoreWishlistItem.from(document: doc), 
                       !seenIds.contains(doc.documentID) {
                        // Only include user items (exclude child items)
                        let isUserItem = (item.childId == nil || item.childId?.isEmpty == true)
                        if isUserItem {
                            allItems.append((itemId: doc.documentID, item: item))
                            seenIds.insert(doc.documentID)
                        }
                    }
                }
            }
            
            // If it's 11 digits starting with 1, also check without country code
            if normalizedPhone.count == 11 && normalizedPhone.hasPrefix("1") {
                let withoutCountryCode = String(normalizedPhone.dropFirst())
                logger.info("   Also checking without country code: \(withoutCountryCode)")
                query = db.collection("wishlistItems")
                    .whereField("ownerPhone", isEqualTo: withoutCountryCode)
                    .whereField("ownerType", isEqualTo: "user")
                snapshot = try await query.getDocuments()
                
                for doc in snapshot.documents {
                    if let item = FirestoreWishlistItem.from(document: doc), 
                       !seenIds.contains(doc.documentID) {
                        // Only include user items (exclude child items)
                        let isUserItem = (item.childId == nil || item.childId?.isEmpty == true)
                        if isUserItem {
                            allItems.append((itemId: doc.documentID, item: item))
                            seenIds.insert(doc.documentID)
                        }
                    }
                }
            }
            
            // Sort by createdAt descending
            allItems.sort { $0.item.createdAt.toDate > $1.item.createdAt.toDate }
            
            logger.info("✅ [FIREBASE] Found \(allItems.count) wishlist items")
            return allItems
        } else {
            logger.error("❌ [FIREBASE] Must provide either ownerPhone or childId")
            throw FirebaseError.invalidData
        }
    }

    // MARK: - Purchases

    /// Mark item as purchased
    func savePurchase(itemId: String, itemName: String, ownerPhone: String) async throws -> String {
        guard let userPhone = currentUserPhone else {
            throw FirebaseError.notAuthenticated
        }

        logger.info("🎁 [FIREBASE] Marking item as purchased: \(itemName)")

        let purchaseId = UUID().uuidString
        let purchaseData: [String: Any] = [
            "itemId": itemId,
            "itemName": itemName,
            "purchaserPhone": userPhone,
            "ownerPhone": ownerPhone,
            "purchasedAt": Timestamp(),
            "isActive": true
        ]

        let docRef = db.collection("purchases").document(purchaseId)
        try await docRef.setData(purchaseData)

        // Update item's isPurchased status
        let itemRef = db.collection("wishlistItems").document(itemId)
        try? await itemRef.updateData(["isPurchased": true])

        logger.info("✅ [FIREBASE] Purchase saved: \(purchaseId)")
        return purchaseId
    }

    /// Fetch purchases for an item
    func fetchPurchasesForItem(itemId: String) async throws -> [FirestorePurchase] {
        return try await fetchPurchasesForItemWithIds(itemId: itemId).map { $0.purchase }
    }
    
    /// Fetch purchases for an item with their document IDs
    func fetchPurchasesForItemWithIds(itemId: String) async throws -> [(purchaseId: String, purchase: FirestorePurchase)] {
        logger.info("📥 [FIREBASE] Fetching purchases for item: \(itemId)")

        let snapshot = try await db.collection("purchases")
            .whereField("itemId", isEqualTo: itemId)
            .whereField("isActive", isEqualTo: true)
            .order(by: "purchasedAt", descending: true)
            .getDocuments()

        var purchasesWithIds: [(purchaseId: String, purchase: FirestorePurchase)] = []
        for doc in snapshot.documents {
            if let purchase = FirestorePurchase.from(document: doc) {
                purchasesWithIds.append((purchaseId: doc.documentID, purchase: purchase))
            }
        }
        
        logger.info("✅ [FIREBASE] Found \(purchasesWithIds.count) purchases")
        return purchasesWithIds
    }

    /// Unmark item as purchased (delete purchase record)
    func deletePurchase(purchaseId: String, itemId: String) async throws {
        logger.info("🗑️ [FIREBASE] Deleting purchase: \(purchaseId)")

        let docRef = db.collection("purchases").document(purchaseId)
        try await docRef.delete()

        // Update item's isPurchased status
        let itemRef = db.collection("wishlistItems").document(itemId)
        try? await itemRef.updateData(["isPurchased": false])

        logger.info("✅ [FIREBASE] Purchase deleted")
    }

    // MARK: - User Management

    /// Create or update user document in Firestore
    func createOrUpdateUser(displayName: String) async throws {
        guard let userPhone = currentUserPhone else {
            throw FirebaseError.notAuthenticated
        }

        logger.info("👤 [FIREBASE] Creating/updating user: \(displayName)")
        logger.info("👤 [FIREBASE] User phone (normalized): \(userPhone)")

        let userData: [String: Any] = [
            "displayName": displayName,
            "createdAt": Timestamp(),
            "fcmTokens": [],
            "settings": [
                "notificationsEnabled": true,
                "showPurchasedItems": true
            ]
        ]

        // Create document with the normalized phone (which includes country code from Firebase Auth)
        let docRef = db.collection("users").document(userPhone)
        try await docRef.setData(userData, merge: true)
        
        // Also create a document without country code for US numbers (if it's 11 digits starting with 1)
        // This ensures discovery works whether friends add the number with or without country code
        if userPhone.count == 11 && userPhone.hasPrefix("1") {
            let withoutCountryCode = String(userPhone.dropFirst())
            logger.info("👤 [FIREBASE] Also creating document without country code: \(withoutCountryCode)")
            let altDocRef = db.collection("users").document(withoutCountryCode)
            try await altDocRef.setData(userData, merge: true)
        }

        logger.info("✅ [FIREBASE] User document created/updated at \(userPhone)")
    }

    /// Fetch user document from Firestore
    func fetchUser(phone: String) async throws -> FirestoreUser? {
        let normalizedPhone = normalizePhone(phone)
        logger.info("📥 [FIREBASE] Fetching user: \(normalizedPhone)")

        let docRef = db.collection("users").document(normalizedPhone)
        let snapshot = try await docRef.getDocument()

        guard snapshot.exists else {
            logger.warning("⚠️ [FIREBASE] User not found: \(normalizedPhone)")
            return nil
        }

        // Parse user data
        guard let data = snapshot.data() else { return nil }

        let user = FirestoreUser(
            displayName: data["displayName"] as? String ?? "",
            createdAt: data["createdAt"] as? Timestamp ?? Timestamp(),
            fcmTokens: data["fcmTokens"] as? [String] ?? [],
            settings: FirestoreUser.UserSettings(
                notificationsEnabled: (data["settings"] as? [String: Any])?["notificationsEnabled"] as? Bool ?? true,
                showPurchasedItems: (data["settings"] as? [String: Any])?["showPurchasedItems"] as? Bool ?? true
            )
        )

        logger.info("✅ [FIREBASE] User fetched: \(user.displayName)")
        return user
    }
}

// MARK: - Firebase Errors

enum FirebaseError: LocalizedError {
    case notAuthenticated
    case invalidData
    case networkError

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .invalidData:
            return "Invalid data format"
        case .networkError:
            return "Network error occurred"
        }
    }
}
