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

    // Prevent concurrent syncs
    private var isSyncingItems = false
    private var isSyncingFriends = false

    // MARK: - Caching

    // Cache for friend wishlist items (key: "phone:childId" or "phone")
    private var wishlistCache: [String: (items: [(itemId: String, item: FirestoreWishlistItem)], timestamp: Date)] = [:]

    // Cache for purchases (key: itemId)
    private var purchaseCache: [String: (purchases: [(purchaseId: String, purchase: FirestorePurchase)], timestamp: Date)] = [:]

    private let cacheExpiration: TimeInterval = 600 // 10 minutes

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

    /// Normalize phone number to canonical digits-only US form
    private func normalizePhone(_ phone: String) -> String {
        PhoneNumber.normalize(phone)
    }

    /// Get current user's normalized phone number
    private var currentUserPhone: String? {
        return auth.currentUserPhone
    }

    /// Public static method to normalize phone numbers (used by views)
    static func normalizePhoneNumber(_ phone: String) -> String {
        PhoneNumber.normalize(phone)
    }

    /// Convert FirestoreWishlistItem to WishlistItem (SwiftData model)
    private func firestoreItemToWishlistItem(
        _ firestoreItem: FirestoreWishlistItem,
        itemId: String,
        ownerPhone: String,
        isOwnedByCurrentUser: Bool
    ) -> WishlistItem {
        let item = WishlistItem(
            id: UUID(uuidString: itemId) ?? UUID(),
            name: firestoreItem.name,
            url: firestoreItem.url,
            itemDescription: firestoreItem.itemDescription,
            isPurchased: firestoreItem.isPurchased,
            purchasedByOwner: firestoreItem.purchasedByOwner,
            purchasedByUserId: nil, // We don't store this in Firestore yet
            createdAt: firestoreItem.createdAt.toDate,
            ownerId: UUID(), // Legacy field, not used for friend items
            imageData: nil, // Images loaded separately on demand
            imageUrl: firestoreItem.imageUrl, // Store URL for on-demand loading
            ownerPhone: normalizePhone(ownerPhone),
            isOwnedByCurrentUser: isOwnedByCurrentUser,
            lastSyncedAt: Date(),
            childId: firestoreItem.childId ?? ""
        )
        return item
    }

    /// Sync friend items from Firestore to SwiftData
    private func syncFriendItemsToSwiftData(
        ownerPhone: String,
        childId: String?,
        context: ModelContext
    ) async throws {
        logger.info("🔄 [SYNC] Syncing friend items to SwiftData for \(ownerPhone)")

        // Fetch from Firestore (use the existing network logic)
        let itemsWithIds: [(itemId: String, item: FirestoreWishlistItem)]

        if let childId = childId {
            // Fetch child items from Firestore
            var query = db.collection("wishlistItems").whereField("childId", isEqualTo: childId)
            let snapshot = try await query.getDocuments()

            itemsWithIds = snapshot.documents.compactMap { doc in
                if let item = FirestoreWishlistItem.from(document: doc) {
                    return (itemId: doc.documentID, item: item)
                }
                return nil
            }
        } else {
            // Fetch user items from Firestore
            let normalizedPhone = normalizePhone(ownerPhone)
            var query = db.collection("wishlistItems")
                .whereField("ownerPhone", isEqualTo: normalizedPhone)
                .whereField("ownerType", isEqualTo: "user")
            var snapshot = try await query.getDocuments()

            var allItems: [(itemId: String, item: FirestoreWishlistItem)] = []
            var seenIds = Set<String>()

            for doc in snapshot.documents {
                if let item = FirestoreWishlistItem.from(document: doc),
                   !seenIds.contains(doc.documentID) {
                    let isUserItem = (item.childId == nil || item.childId?.isEmpty == true)
                    if isUserItem {
                        allItems.append((itemId: doc.documentID, item: item))
                        seenIds.insert(doc.documentID)
                    }
                }
            }

            // Also check with country code variations
            if normalizedPhone.count == 10 {
                let withCountryCode = "1" + normalizedPhone
                query = db.collection("wishlistItems")
                    .whereField("ownerPhone", isEqualTo: withCountryCode)
                    .whereField("ownerType", isEqualTo: "user")
                snapshot = try await query.getDocuments()

                for doc in snapshot.documents {
                    if let item = FirestoreWishlistItem.from(document: doc),
                       !seenIds.contains(doc.documentID) {
                        let isUserItem = (item.childId == nil || item.childId?.isEmpty == true)
                        if isUserItem {
                            allItems.append((itemId: doc.documentID, item: item))
                            seenIds.insert(doc.documentID)
                        }
                    }
                }
            }

            if normalizedPhone.count == 11 && normalizedPhone.hasPrefix("1") {
                let withoutCountryCode = String(normalizedPhone.dropFirst())
                query = db.collection("wishlistItems")
                    .whereField("ownerPhone", isEqualTo: withoutCountryCode)
                    .whereField("ownerType", isEqualTo: "user")
                snapshot = try await query.getDocuments()

                for doc in snapshot.documents {
                    if let item = FirestoreWishlistItem.from(document: doc),
                       !seenIds.contains(doc.documentID) {
                        let isUserItem = (item.childId == nil || item.childId?.isEmpty == true)
                        if isUserItem {
                            allItems.append((itemId: doc.documentID, item: item))
                            seenIds.insert(doc.documentID)
                        }
                    }
                }
            }

            itemsWithIds = allItems
        }

        logger.info("✅ [SYNC] Fetched \(itemsWithIds.count) items from Firestore")

        // Upsert into SwiftData
        for (itemId, firestoreItem) in itemsWithIds {
            // Try to find existing item by ID - convert string to UUID for comparison
            guard let itemUUID = UUID(uuidString: itemId) else {
                logger.warning("⚠️ [SYNC] Invalid UUID string: \(itemId), skipping")
                continue
            }

            let predicate = #Predicate<WishlistItem> { item in
                item.id == itemUUID
            }
            let descriptor = FetchDescriptor(predicate: predicate)
            let existing = try? context.fetch(descriptor).first

            if let existingItem = existing {
                // Update existing item
                existingItem.name = firestoreItem.name
                existingItem.url = firestoreItem.url
                existingItem.itemDescription = firestoreItem.itemDescription
                existingItem.isPurchased = firestoreItem.isPurchased
                existingItem.purchasedByOwner = firestoreItem.purchasedByOwner
                existingItem.childId = firestoreItem.childId ?? ""
                existingItem.createdAt = firestoreItem.createdAt.toDate
                existingItem.imageUrl = firestoreItem.imageUrl
                existingItem.lastSyncedAt = Date()
                logger.debug("📝 [SYNC] Updated existing item: \(firestoreItem.name)")
            } else {
                // Insert new item
                let newItem = firestoreItemToWishlistItem(
                    firestoreItem,
                    itemId: itemId,
                    ownerPhone: ownerPhone,
                    isOwnedByCurrentUser: false
                )
                context.insert(newItem)
                logger.debug("➕ [SYNC] Inserted new item: \(firestoreItem.name)")
            }
        }

        try context.save()
        logger.info("✅ [SYNC] Saved \(itemsWithIds.count) items to SwiftData")

        // Load images in background for items that have imageUrl but no imageData
        Task.detached { @MainActor in
            await self.loadImagesForCachedItems(ownerPhone: ownerPhone, context: context)
        }
    }

    /// Load images for cached friend items that have URLs but no data
    private func loadImagesForCachedItems(ownerPhone: String, context: ModelContext) async {
        let normalizedPhone = normalizePhone(ownerPhone)
        let predicate = #Predicate<WishlistItem> { item in
            item.ownerPhone == normalizedPhone &&
            item.isOwnedByCurrentUser == false
        }
        let descriptor = FetchDescriptor(predicate: predicate)

        guard let items = try? context.fetch(descriptor) else { return }

        logger.debug("🖼️ [IMAGE_LOAD] Checking \(items.count) items for images to download")

        for item in items {
            // Skip if already has imageData or no imageUrl
            guard item.imageData == nil,
                  let imageUrl = item.imageUrl,
                  !imageUrl.isEmpty else {
                continue
            }

            logger.debug("📥 [IMAGE_LOAD] Downloading image for '\(item.name)' from: \(imageUrl)")

            do {
                let imageData = try await storage.downloadImage(from: imageUrl)

                // Update the item with the downloaded image
                await MainActor.run {
                    item.imageData = imageData
                    try? context.save()
                    logger.debug("✅ [IMAGE_LOAD] Saved image for '\(item.name)' (\(imageData.count) bytes)")
                }
            } catch {
                logger.warning("⚠️ [IMAGE_LOAD] Failed to download image for '\(item.name)': \(error.localizedDescription)")
            }
        }

        logger.debug("✅ [IMAGE_LOAD] Finished loading images")
    }

    /// Public function to trigger friend wishlist sync (called by views)
    func syncFriendWishlist(
        ownerPhone: String,
        childId: String? = nil,
        forceRefresh: Bool = false,
        context: ModelContext
    ) async throws {
        // If not forcing refresh, check if we synced recently
        if !forceRefresh {
            // Query for existing items to check last sync time
            let normalizedPhone = normalizePhone(ownerPhone)
            let predicate = #Predicate<WishlistItem> { item in
                item.ownerPhone == normalizedPhone &&
                item.isOwnedByCurrentUser == false
            }
            let descriptor = FetchDescriptor(predicate: predicate)
            let cachedItems = try? context.fetch(descriptor)

            // If we have cached items and they were synced recently (within 5 minutes), skip sync
            if let items = cachedItems, !items.isEmpty,
               let lastSync = items.compactMap({ $0.lastSyncedAt }).max(),
               Date().timeIntervalSince(lastSync) < 300 {
                logger.debug("⏭️ [SYNC] Skipping sync - last synced \(Int(Date().timeIntervalSince(lastSync)))s ago")
                return
            }
        }

        // Trigger background sync
        try await syncFriendItemsToSwiftData(
            ownerPhone: ownerPhone,
            childId: childId,
            context: context
        )
    }

    // MARK: - Cache Helpers

    /// Generate cache key for wishlist items
    private func wishlistCacheKey(ownerPhone: String?, childId: String?) -> String {
        if let childId = childId, !childId.isEmpty {
            return "child:\(childId)"
        } else if let phone = ownerPhone {
            return "phone:\(normalizePhone(phone))"
        }
        return "unknown"
    }

    /// Check if cached data is still valid
    private func isCacheValid(timestamp: Date) -> Bool {
        return Date().timeIntervalSince(timestamp) < cacheExpiration
    }

    /// Clear wishlist cache for a specific key
    func clearWishlistCache(ownerPhone: String?, childId: String?) {
        let key = wishlistCacheKey(ownerPhone: ownerPhone, childId: childId)
        wishlistCache.removeValue(forKey: key)
        logger.debug("🗑️ [CACHE] Cleared wishlist cache for key: \(key)")
    }

    /// Clear all caches
    func clearAllCaches() {
        wishlistCache.removeAll()
        purchaseCache.removeAll()
        storage.clearImageCache()
        logger.debug("🗑️ [CACHE] Cleared all caches")
    }

    /// Clear purchase cache for a specific item
    func clearPurchaseCache(itemId: String) {
        purchaseCache.removeValue(forKey: itemId)
        logger.debug("🗑️ [CACHE] Cleared purchase cache for item: \(itemId)")
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

        // Fetch the local item up front so we can preserve its original createdAt
        // and update its sync bookkeeping after the upload.
        let localPredicate = #Predicate<WishlistItem> { item in
            item.id == id
        }
        let localItem = try? context.fetch(FetchDescriptor(predicate: localPredicate)).first

        // Upload image if exists
        var imageUrl: String? = nil
        if let data = imageData {
            logger.info("📤 [FIREBASE] Uploading image (\(data.count) bytes) for item: \(id.uuidString)")
            do {
                imageUrl = try await storage.uploadWishlistItemImage(itemId: id.uuidString, imageData: data)
                if let url = imageUrl {
                    logger.info("✅ [FIREBASE] Image uploaded successfully: \(url)")
                } else {
                    logger.error("❌ [FIREBASE] Image upload returned nil URL!")
                }
            } catch {
                logger.error("❌ [FIREBASE] Failed to upload image: \(error.localizedDescription)")
                logger.error("   ⚠️ Item will be saved WITHOUT image - friends won't be able to see the photo")
                // Continue saving item without image - user can see the item but image won't be available
                // This is better than failing the entire save operation
            }
        } else {
            logger.info("ℹ️ [FIREBASE] No image data provided for item")
        }

        // Upsert Firestore document. merge: true preserves fields the app doesn't
        // own here — most importantly isPurchased, which friends set when claiming.
        var itemData: [String: Any] = [
            "name": name,
            "url": url ?? "",
            "itemDescription": description ?? "",
            "imageUrl": imageUrl ?? "",
            "ownerPhone": userPhone,
            "ownerType": ownerType
        ]

        // Only include childId if it's not nil/empty (for child items)
        if let childId = childId, !childId.isEmpty {
            itemData["childId"] = childId
            logger.info("   Saving with childId: \(childId)")
        } else {
            logger.info("   Saving without childId (user item)")
        }

        let docRef = db.collection("wishlistItems").document(id.uuidString)
        let existingDoc = try? await docRef.getDocument()
        if existingDoc?.exists != true {
            // Brand-new document: initialize claim flags and creation date.
            // On existing documents these are intentionally left untouched.
            itemData["isPurchased"] = localItem?.isPurchased ?? false
            itemData["purchasedByOwner"] = localItem?.purchasedByOwner ?? false
            itemData["createdAt"] = Timestamp.from(localItem?.createdAt ?? Date())
        }
        try await docRef.setData(itemData, merge: true)

        logger.info("✅ [FIREBASE] Wishlist item saved: \(id.uuidString)")
        logger.info("   Image URL saved: \(imageUrl ?? "nil")")
        logger.info("   Has imageData: \(imageData != nil), bytes: \(imageData?.count ?? 0)")

        // Verify the saved data
        let verifyDoc = try? await docRef.getDocument()
        if let verifyData = verifyDoc?.data(), let savedImageUrl = verifyData["imageUrl"] as? String {
            logger.info("   ✅ Verified imageUrl in Firestore: \(savedImageUrl.isEmpty ? "EMPTY" : savedImageUrl)")
        } else {
            logger.warning("   ⚠️ Could not verify imageUrl in Firestore")
        }

        // Update the local SwiftData item with imageUrl and lastSyncedAt
        if let localItem {
            localItem.imageUrl = imageUrl
            localItem.lastSyncedAt = Date()
            try? context.save()
            logger.debug("📱 [FIREBASE] Updated local item with imageUrl and lastSyncedAt")
        }

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
        // Prevent concurrent syncs
        guard !isSyncingItems else {
            logger.info("⏸️ [SYNC] Sync already in progress, skipping duplicate sync request")
            return
        }
        
        isSyncingItems = true
        defer {
            isSyncingItems = false
        }
        
        do {
            // Fetch all children first to map childId to local Child UUIDs
            let childrenDescriptor = FetchDescriptor<Child>()
            let allChildren = (try? context.fetch(childrenDescriptor)) ?? []
            let childIdToLocalId: [String: UUID] = Dictionary(uniqueKeysWithValues: allChildren.compactMap { child in
                guard let firebaseId = child.cloudKitRecordID else { return nil }
                return (firebaseId, child.id)
            })
            logger.info("📋 [SYNC] Mapped \(childIdToLocalId.count) children for ownerId lookup")

            // Query for USER items only (exclude child items)
            // User items have ownerType="user" and no childId (or empty childId)
            let snapshot = try await db.collection("wishlistItems")
                .whereField("ownerPhone", isEqualTo: userPhone)
                .whereField("ownerType", isEqualTo: "user")
                .order(by: "createdAt", descending: true)
                .getDocuments()

            logger.info("☁️ [FIREBASE] Fetched \(snapshot.documents.count) user items from Firestore")

            // Also fetch child items separately to sync them with correct ownerId
            let childItemsSnapshot = try await db.collection("wishlistItems")
                .whereField("ownerPhone", isEqualTo: userPhone)
                .whereField("ownerType", isEqualTo: "child")
                .order(by: "createdAt", descending: true)
                .getDocuments()

            logger.info("☁️ [FIREBASE] Fetched \(childItemsSnapshot.documents.count) child items from Firestore")

            // Process user items
            let localChildIds = Set(allChildren.map { $0.id })
            for doc in snapshot.documents {
                guard let firestoreItem = FirestoreWishlistItem.from(document: doc) else { continue }
                
                // Skip if this item has a childId (shouldn't happen with our query, but double-check)
                if let childId = firestoreItem.childId, !childId.isEmpty {
                    logger.warning("⚠️ [SYNC] User item '\(firestoreItem.name)' has childId - skipping")
                    continue
                }

                // Self-heal legacy docs: if the local copy belongs to a child but the Firestore doc
                // says ownerType "user" (old upload bug), fix the doc instead of treating it as the parent's.
                if let itemId = UUID(uuidString: doc.documentID) {
                    let localDescriptor = FetchDescriptor<WishlistItem>(
                        predicate: #Predicate<WishlistItem> { $0.id == itemId }
                    )
                    if let localItem = try? context.fetch(localDescriptor).first,
                       localChildIds.contains(localItem.ownerId),
                       let child = allChildren.first(where: { $0.id == localItem.ownerId }),
                       let firebaseChildId = child.cloudKitRecordID, !firebaseChildId.isEmpty {
                        logger.warning("🩹 [SYNC] '\(firestoreItem.name)' is \(child.name)'s item but Firestore says ownerType=user - repairing doc")
                        try? await doc.reference.updateData([
                            "ownerType": "child",
                            "childId": firebaseChildId
                        ])
                        continue // It will sync as a child item on the next pass
                    }
                }

                await processSyncItem(
                    doc: doc,
                    firestoreItem: firestoreItem,
                    ownerId: nil, // User items - ownerId will be determined by MyWishlistView filtering
                    childIdToLocalId: childIdToLocalId,
                    context: context
                )
            }

            // Process child items
            for doc in childItemsSnapshot.documents {
                guard let firestoreItem = FirestoreWishlistItem.from(document: doc) else { continue }
                
                // Get the local Child UUID from the Firebase childId
                guard let firebaseChildId = firestoreItem.childId, !firebaseChildId.isEmpty else {
                    logger.warning("⚠️ [SYNC] Child item '\(firestoreItem.name)' has no childId - skipping")
                    continue
                }
                
                guard let localChildId = childIdToLocalId[firebaseChildId] else {
                    logger.warning("⚠️ [SYNC] Child item '\(firestoreItem.name)' references unknown childId '\(firebaseChildId)' - skipping")
                    continue
                }

                await processSyncItem(
                    doc: doc,
                    firestoreItem: firestoreItem,
                    ownerId: localChildId,
                    childIdToLocalId: childIdToLocalId,
                    context: context
                )
            }

            try? context.save()
            logger.info("✅ [FIREBASE] Merged Firestore items with local SwiftData")

        } catch {
            logger.error("❌ [FIREBASE] Failed to sync items: \(error.localizedDescription)")
        }
    }
    
    /// Helper to process a single item during sync
    private func processSyncItem(
        doc: DocumentSnapshot,
        firestoreItem: FirestoreWishlistItem,
        ownerId: UUID?,
        childIdToLocalId: [String: UUID],
        context: ModelContext
    ) async {
        // Parse document ID as UUID - this should always work since we save items with UUID document IDs
        guard let itemId = UUID(uuidString: doc.documentID) else {
            logger.error("❌ [SYNC] Invalid document ID format (not a UUID): \(doc.documentID) - skipping item '\(firestoreItem.name)'")
            return
        }
        
        // Check if exists locally by ID (primary check)
        let descriptor = FetchDescriptor<WishlistItem>(
            predicate: #Predicate { $0.id == itemId }
        )

        var existing = try? context.fetch(descriptor).first
        
        // Also check for duplicates by name and ownerId as a safety measure
        // This handles cases where items were created with wrong IDs
        if existing == nil {
            let finalOwnerId: UUID
            if let ownerId = ownerId {
                finalOwnerId = ownerId
            } else {
                // For user items, check against all items not belonging to children
                let childrenDescriptor = FetchDescriptor<Child>()
                let allChildren = (try? context.fetch(childrenDescriptor)) ?? []
                let childIds = Set(allChildren.map { $0.id })
                
                // Look for items with same name that don't belong to children
                let allItemsDescriptor = FetchDescriptor<WishlistItem>(
                    predicate: #Predicate { item in
                        item.name == firestoreItem.name && !childIds.contains(item.ownerId)
                    }
                )
                if let duplicate = try? context.fetch(allItemsDescriptor).first {
                    logger.warning("⚠️ [SYNC] Found duplicate user item '\(firestoreItem.name)' with ID \(duplicate.id.uuidString) - updating to correct ID \(itemId.uuidString)")
                    // Delete the duplicate and we'll create a new one with correct ID
                    context.delete(duplicate)
                    try? context.save()
                }
            }
        }
        
        // Log image status
        let hasImageUrl = firestoreItem.imageUrl != nil && !firestoreItem.imageUrl!.isEmpty
        let hasLocalImage = existing?.imageData != nil
        logger.info("🖼️ [SYNC] Item '\(firestoreItem.name)': imageUrl=\(hasImageUrl ? "yes" : "no"), localImage=\(hasLocalImage ? "yes" : "no")")
        if hasImageUrl {
            logger.info("   imageUrl: \(firestoreItem.imageUrl ?? "nil")")
        }

        // Download image if URL exists and we don't have local imageData
        var imageData: Data? = nil
        if let imageUrl = firestoreItem.imageUrl, !imageUrl.isEmpty {
            // Only download if we don't already have the image locally
            if existing?.imageData == nil {
                logger.info("📥 [SYNC] Downloading image for '\(firestoreItem.name)' from: \(imageUrl)")
                do {
                    imageData = try await storage.downloadImage(from: imageUrl)
                    logger.info("✅ [SYNC] Downloaded image for '\(firestoreItem.name)' (\(imageData?.count ?? 0) bytes)")
                } catch {
                    logger.error("❌ [SYNC] Failed to download image for '\(firestoreItem.name)': \(error.localizedDescription)")
                }
            } else {
                logger.info("ℹ️ [SYNC] Image already exists locally for '\(firestoreItem.name)' - skipping download")
                imageData = existing?.imageData
            }
        } else {
            logger.info("ℹ️ [SYNC] No imageUrl for '\(firestoreItem.name)' - no image to download")
            
            // Check if local item has imageData that needs to be uploaded
            if let localImageData = existing?.imageData {
                logger.info("📤 [SYNC] Local item has image but Firestore doesn't - uploading image for '\(firestoreItem.name)'")
                do {
                    let uploadedUrl = try await storage.uploadWishlistItemImage(itemId: itemId.uuidString, imageData: localImageData)
                    // Update Firestore with the imageUrl
                    let docRef = db.collection("wishlistItems").document(itemId.uuidString)
                    try await docRef.updateData(["imageUrl": uploadedUrl])
                    logger.info("✅ [SYNC] Successfully uploaded and saved imageUrl for '\(firestoreItem.name)': \(uploadedUrl)")
                } catch {
                    logger.error("❌ [SYNC] Failed to upload image for '\(firestoreItem.name)': \(error.localizedDescription)")
                }
            } else if let itemUrl = firestoreItem.url, !itemUrl.isEmpty {
                // Item has a URL but no image - try to extract and upload image from URL
                logger.info("🔄 [SYNC] Item '\(firestoreItem.name)' has URL but no image - attempting to extract image from URL: \(itemUrl)")
                await backfillImageFromURL(itemId: itemId, itemName: firestoreItem.name, url: itemUrl, existing: existing, context: context)
            }
        }

        if let existing = existing {
            // Update existing
            existing.name = firestoreItem.name
            existing.url = firestoreItem.url
            existing.itemDescription = firestoreItem.itemDescription
            existing.isPurchased = firestoreItem.isPurchased
            existing.purchasedByOwner = firestoreItem.purchasedByOwner
            existing.imageUrl = firestoreItem.imageUrl
            existing.ownerPhone = normalizePhone(firestoreItem.ownerPhone)
            // Mark as synced so uploadUnsyncedLocalItems never re-uploads it
            // (re-uploading would clobber isPurchased set by friends).
            existing.lastSyncedAt = Date()
            // Update ownerId if this is a child item and it changed
            if let ownerId = ownerId {
                existing.ownerId = ownerId
            }
            // Update imageData if we downloaded it
            if let imageData = imageData {
                existing.imageData = imageData
            }
        } else {
            // Create new - need to determine ownerId
            let finalOwnerId: UUID
            if let ownerId = ownerId {
                // This is a child item
                finalOwnerId = ownerId
                logger.info("👶 [SYNC] Creating child item '\(firestoreItem.name)' with ownerId: \(ownerId.uuidString)")
            } else {
                // This is a user item - we'll use a placeholder UUID
                // MyWishlistView will filter these correctly by excluding child ownerIds
                finalOwnerId = UUID()
                logger.info("👤 [SYNC] Creating user item '\(firestoreItem.name)'")
            }
            
            let newItem = WishlistItem(
                id: itemId,
                name: firestoreItem.name,
                url: firestoreItem.url,
                itemDescription: firestoreItem.itemDescription,
                isPurchased: firestoreItem.isPurchased,
                purchasedByOwner: firestoreItem.purchasedByOwner,
                createdAt: firestoreItem.createdAt.toDate,
                ownerId: finalOwnerId,
                imageData: imageData,
                imageUrl: firestoreItem.imageUrl,
                ownerPhone: normalizePhone(firestoreItem.ownerPhone),
                isOwnedByCurrentUser: true,
                // Mark as synced so uploadUnsyncedLocalItems never re-uploads it.
                lastSyncedAt: Date(),
                childId: firestoreItem.childId ?? ""
            )
            context.insert(newItem)
        }
    }
    
    /// Backfill image from product URL for items that don't have images
    private func backfillImageFromURL(
        itemId: UUID,
        itemName: String,
        url: String,
        existing: WishlistItem?,
        context: ModelContext
    ) async {
        do {
            // Extract product data from URL
            let productData = await URLProductExtractor.extract(from: url)
            
            guard let imageURL = productData.imageURL else {
                logger.info("ℹ️ [BACKFILL] No image found for '\(itemName)' at URL: \(url)")
                return
            }
            
            logger.info("🖼️ [BACKFILL] Found image URL for '\(itemName)': \(imageURL)")
            
            // Download the image
            guard let imageData = await ProductImageDownloader.shared.downloadImage(from: imageURL) else {
                logger.error("❌ [BACKFILL] Failed to download image for '\(itemName)' from: \(imageURL)")
                return
            }
            
            logger.info("✅ [BACKFILL] Downloaded image for '\(itemName)' (\(imageData.count) bytes)")
            
            // Upload to Firebase Storage
            let uploadedUrl = try await storage.uploadWishlistItemImage(itemId: itemId.uuidString, imageData: imageData)
            logger.info("✅ [BACKFILL] Uploaded image to Firebase Storage: \(uploadedUrl)")
            
            // Update Firestore with the imageUrl
            let docRef = db.collection("wishlistItems").document(itemId.uuidString)
            try await docRef.updateData(["imageUrl": uploadedUrl])
            logger.info("✅ [BACKFILL] Updated Firestore with imageUrl for '\(itemName)'")
            
            // Update local SwiftData if item exists
            if let existing = existing {
                existing.imageData = imageData
                try? context.save()
                logger.info("✅ [BACKFILL] Updated local SwiftData with image for '\(itemName)'")
            }
            
        } catch {
            logger.error("❌ [BACKFILL] Failed to backfill image for '\(itemName)': \(error.localizedDescription)")
        }
    }

    /// Update wishlist item in Firestore
    func updateWishlistItem(id: UUID, name: String, url: String?, description: String?, imageData: Data?) async throws {
        logger.info("🔄 [FIREBASE] Updating wishlist item: \(id.uuidString)")

        let docRef = db.collection("wishlistItems").document(id.uuidString)

        var updateData: [String: Any] = [
            "name": name,
            "url": url ?? "",
            "itemDescription": description ?? ""
        ]
        
        // Upload new image if provided
        if let data = imageData {
            do {
                let imageUrl = try await storage.uploadWishlistItemImage(itemId: id.uuidString, imageData: data)
                updateData["imageUrl"] = imageUrl
                logger.info("✅ [FIREBASE] Image updated successfully: \(imageUrl)")
            } catch {
                logger.error("❌ [FIREBASE] Failed to upload image during update: \(error.localizedDescription)")
                // Continue with update - don't fail the entire operation
            }
        }

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
        let friendId = PhoneNumber.friendshipDocumentId(userPhone: userPhone, friendPhone: normalizedFriendPhone)
        let docRef = db.collection("friends").document(friendId)
        let existing = try await docRef.getDocument()

        var friendData: [String: Any] = [
            "userPhone": userPhone,
            "friendPhone": normalizedFriendPhone,
            "friendName": friendName
        ]

        if existing.exists {
            try await docRef.setData(friendData, merge: true)
        } else {
            friendData["addedAt"] = Timestamp()
            friendData["hiddenChildren"] = []
            try await docRef.setData(friendData)
        }

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

    /// Background sync: mirror Firestore friends into the local SwiftData cache.
    /// Everything is keyed on the canonical phone number, so a person can only ever
    /// have one local row no matter how their number was formatted when it was stored.
    private func syncFriendsFromFirestore(userPhone: String, context: ModelContext) async {
        guard !isSyncingFriends else {
            logger.info("⏭️ [FIREBASE] Friend sync already running, skipping")
            return
        }
        isSyncingFriends = true
        defer { isSyncingFriends = false }

        do {
            let snapshot = try await db.collection("friends")
                .whereField("userPhone", isEqualTo: userPhone)
                .order(by: "addedAt", descending: true)
                .getDocuments()

            logger.info("☁️ [FIREBASE] Fetched \(snapshot.documents.count) friends from Firestore")

            // Collapse legacy duplicate documents down to one entry per person.
            var remote: [String: (name: String, docId: String, hiddenChildren: [String])] = [:]
            for doc in snapshot.documents {
                guard let firestoreFriend = FirestoreFriend.from(document: doc) else { continue }
                let phone = PhoneNumber.normalize(firestoreFriend.friendPhone)
                guard !phone.isEmpty else { continue }

                let canonicalId = PhoneNumber.friendshipDocumentId(userPhone: userPhone, friendPhone: phone)
                if let seen = remote[phone], seen.docId == canonicalId { continue }
                remote[phone] = (firestoreFriend.friendName, doc.documentID, firestoreFriend.hiddenChildren)
            }

            let locals = ((try? context.fetch(FetchDescriptor<Friend>())) ?? [])
                .sorted { $0.addedAt < $1.addedAt }

            var kept: [String: Friend] = [:]
            for friend in locals {
                let phone = friend.phoneNumber.map(PhoneNumber.normalize) ?? ""

                // Drop rows we can't key, rows the server no longer has, and extra copies.
                guard !phone.isEmpty, remote[phone] != nil else {
                    context.delete(friend)
                    continue
                }
                if let original = kept[phone] {
                    if original.imageData == nil { original.imageData = friend.imageData }
                    if original.email == nil { original.email = friend.email }
                    original.hasApp = original.hasApp || friend.hasApp
                    context.delete(friend)
                    continue
                }

                friend.phoneNumber = phone
                kept[phone] = friend
            }

            for (phone, entry) in remote {
                let friend: Friend
                if let existing = kept[phone] {
                    friend = existing
                } else {
                    friend = Friend(name: entry.name, phoneNumber: phone)
                    context.insert(friend)
                }
                friend.name = entry.name
                friend.cloudKitRecordID = entry.docId
                friend.hiddenChildRecordIDs = entry.hiddenChildren
            }

            try? context.save()
            logger.info("✅ [FIREBASE] Synced \(remote.count) friends into SwiftData (was \(locals.count) local rows)")
            self.shouldRefreshFriends.toggle()

        } catch {
            logger.error("❌ [FIREBASE] Failed to sync friends: \(error.localizedDescription)")
        }
    }

    func updateFriendHiddenChildren(friendshipId: String, hiddenChildren: [String]) async throws {
        try await db.collection("friends").document(friendshipId).updateData([
            "hiddenChildren": hiddenChildren
        ])
    }

    /// Saves friendship to Firestore and upserts local SwiftData Friend. Returns the local Friend.
    func addFriend(
        name: String,
        phone: String,
        email: String? = nil,
        imageData: Data? = nil,
        context: ModelContext
    ) async throws -> Friend {
        let normalized = PhoneNumber.normalize(phone)
        guard !normalized.isEmpty else { throw FirebaseError.invalidData }

        let hasApp = (try? await checkIfFriendHasApp(friendPhone: normalized)) ?? false
        let friendId = try await saveFriend(friendPhone: normalized, friendName: name)

        // Upsert local by phone
        let descriptor = FetchDescriptor<Friend>()
        let all = try context.fetch(descriptor)
        let existing = all.first { friend in
            guard let p = friend.phoneNumber else { return false }
            return PhoneNumber.matches(p, normalized)
        }

        if let existing {
            existing.name = name
            existing.phoneNumber = normalized
            existing.hasApp = hasApp
            existing.cloudKitRecordID = friendId
            if let email { existing.email = email }
            if let imageData { existing.imageData = imageData }
            try context.save()
            return existing
        } else {
            let friend = Friend(
                name: name,
                phoneNumber: normalized,
                email: email,
                hasApp: hasApp,
                cloudKitRecordID: friendId,
                imageData: imageData
            )
            context.insert(friend)
            try context.save()
            return friend
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
        let variants = PhoneNumber.variants(friendPhone)
        logger.info("🔍 [FIREBASE] Checking if friend has app: \(variants.joined(separator: ", "))")

        for variant in variants {
            let snapshot = try await db.collection("users").document(variant).getDocument()
            if snapshot.exists {
                logger.info("✅ [FIREBASE] Friend has app: true (found at \(variant))")
                return true
            }
        }

        logger.info("❌ [FIREBASE] Friend has app: false")
        return false
    }

    /// Fetch wishlist items for a friend (by their phone number) or a child (by childId)
    func fetchFriendWishlistItems(ownerPhone: String?, childId: String? = nil) async throws -> [FirestoreWishlistItem] {
        let result = try await fetchFriendWishlistItemsWithIds(ownerPhone: ownerPhone, childId: childId)
        return result.map { $0.item }
    }
    
    /// Fetch wishlist items with their document IDs
    func fetchFriendWishlistItemsWithIds(ownerPhone: String?, childId: String? = nil, forceRefresh: Bool = false) async throws -> [(itemId: String, item: FirestoreWishlistItem)] {
        // Check cache first (unless force refresh)
        let cacheKey = wishlistCacheKey(ownerPhone: ownerPhone, childId: childId)
        if !forceRefresh, let cached = wishlistCache[cacheKey], isCacheValid(timestamp: cached.timestamp) {
            logger.info("💾 [CACHE] Returning cached wishlist items (\(cached.items.count) items) for key: \(cacheKey)")
            return cached.items
        }

        logger.info("📥 [FIREBASE] Fetching wishlist items for friend from network")

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

            // Cache the results
            wishlistCache[cacheKey] = (items: itemsWithIds, timestamp: Date())
            logger.debug("💾 [CACHE] Cached \(itemsWithIds.count) items for key: \(cacheKey)")

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

            // Cache the results
            wishlistCache[cacheKey] = (items: allItems, timestamp: Date())
            logger.debug("💾 [CACHE] Cached \(allItems.count) items for key: \(cacheKey)")

            return allItems
        } else {
            logger.error("❌ [FIREBASE] Must provide either ownerPhone or childId")
            throw FirebaseError.invalidData
        }
    }

    // MARK: - Purchases

    /// Owner checked their own item off (or un-checked it).
    /// Sets purchasedByOwner and keeps the shared isPurchased claim flag consistent:
    /// when unmarking, isPurchased stays true if a friend still has an active claim
    /// so the item keeps showing as taken on friends' lists.
    /// Returns the resulting isPurchased value.
    func setOwnerPurchased(id: UUID, purchased: Bool) async throws -> Bool {
        let docRef = db.collection("wishlistItems").document(id.uuidString)
        if purchased {
            try await docRef.updateData(["isPurchased": true, "purchasedByOwner": true])
            return true
        } else {
            let friendClaim = (try? await hasActiveFriendClaim(itemId: id.uuidString)) ?? false
            try await docRef.updateData(["isPurchased": friendClaim, "purchasedByOwner": false])
            return friendClaim
        }
    }

    /// Whether any friend currently has an active claim on this item.
    /// Query is scoped to ownerPhone == current user so firestore.rules allow it.
    func hasActiveFriendClaim(itemId: String) async throws -> Bool {
        guard let userPhone = currentUserPhone else {
            throw FirebaseError.notAuthenticated
        }

        let snapshot = try await db.collection("purchases")
            .whereField("itemId", isEqualTo: itemId)
            .whereField("ownerPhone", isEqualTo: userPhone)
            .whereField("isActive", isEqualTo: true)
            .limit(to: 1)
            .getDocuments()

        return !snapshot.documents.isEmpty
    }

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
            "isActive": true,
            "notificationSent": false  // Will be set to true by either local notification or Cloud Function
        ]

        let docRef = db.collection("purchases").document(purchaseId)
        try await docRef.setData(purchaseData)

        // Update item's isPurchased status — this flag is what friends' and the
        // owner's UI use to render the wrapped-gift state.
        let itemRef = db.collection("wishlistItems").document(itemId)
        do {
            try await itemRef.updateData(["isPurchased": true])
        } catch {
            logger.error("❌ [FIREBASE] Failed to set isPurchased=true on item \(itemId): \(error)")
        }

        // Clear purchase cache for this item so it will be refreshed next time
        clearPurchaseCache(itemId: itemId)

        logger.info("✅ [FIREBASE] Purchase saved: \(purchaseId)")
        return purchaseId
    }

    /// Fetch purchases for an item
    func fetchPurchasesForItem(itemId: String) async throws -> [FirestorePurchase] {
        return try await fetchPurchasesForItemWithIds(itemId: itemId).map { $0.purchase }
    }
    
    /// Fetch the current user's own active purchases for an item (used for unclaiming).
    func fetchPurchasesForItemWithIds(itemId: String, forceRefresh: Bool = false) async throws -> [(purchaseId: String, purchase: FirestorePurchase)] {
        // Check cache first (unless force refresh)
        if !forceRefresh, let cached = purchaseCache[itemId], isCacheValid(timestamp: cached.timestamp) {
            logger.debug("💾 [CACHE] Returning cached purchases (\(cached.purchases.count) purchases) for item: \(itemId)")
            return cached.purchases
        }

        logger.info("📥 [FIREBASE] Fetching purchases for item: \(itemId)")

        guard let userPhone = currentUserPhone else {
            throw FirebaseError.notAuthenticated
        }

        // Scoped to the current user's own purchases — firestore.rules deny
        // broader queries on the purchases collection (purchaserPhone is private).
        let snapshot = try await db.collection("purchases")
            .whereField("itemId", isEqualTo: itemId)
            .whereField("purchaserPhone", isEqualTo: userPhone)
            .whereField("isActive", isEqualTo: true)
            .getDocuments()

        var purchasesWithIds: [(purchaseId: String, purchase: FirestorePurchase)] = []
        for doc in snapshot.documents {
            if let purchase = FirestorePurchase.from(document: doc) {
                purchasesWithIds.append((purchaseId: doc.documentID, purchase: purchase))
            }
        }

        logger.info("✅ [FIREBASE] Found \(purchasesWithIds.count) purchases")

        // Cache the results
        purchaseCache[itemId] = (purchases: purchasesWithIds, timestamp: Date())
        logger.debug("💾 [CACHE] Cached \(purchasesWithIds.count) purchases for item: \(itemId)")

        return purchasesWithIds
    }

    /// Unmark item as purchased (delete purchase record)
    func deletePurchase(purchaseId: String, itemId: String) async throws {
        logger.info("🗑️ [FIREBASE] Deleting purchase: \(purchaseId)")

        let docRef = db.collection("purchases").document(purchaseId)
        try await docRef.delete()

        // Update item's isPurchased status — but keep it true if the owner
        // checked the item off themselves (purchasedByOwner).
        let itemRef = db.collection("wishlistItems").document(itemId)
        do {
            let itemDoc = try? await itemRef.getDocument()
            let ownerMarked = (itemDoc?.data()?["purchasedByOwner"] as? Bool) ?? false
            if !ownerMarked {
                try await itemRef.updateData(["isPurchased": false])
            }
        } catch {
            logger.error("❌ [FIREBASE] Failed to set isPurchased=false on item \(itemId): \(error)")
        }

        // Clear purchase cache for this item
        clearPurchaseCache(itemId: itemId)

        logger.info("✅ [FIREBASE] Purchase deleted")
    }

    // MARK: - Purchase Notifications

    // Real-time Firestore listener for purchase notifications
    private var purchaseListener: ListenerRegistration?
    private var lastPurchaseTimestamp: Timestamp?
    private var processedPurchaseIds: Set<String> = []

    /// Start listening for purchases where current user is the owner
    /// Uses real-time Firestore listener for instant notifications
    func startPurchaseListener(context: ModelContext) {
        guard let userPhone = currentUserPhone else {
            logger.warning("⚠️ [NOTIFICATIONS] Cannot start purchase listener: not authenticated")
            return
        }

        // Stop existing listener if any
        stopPurchaseListener()

        logger.info("🔔 [NOTIFICATIONS] Starting purchase listener for: \(userPhone)")

        // Normalize phone number
        let normalizedPhone = normalizePhone(userPhone)

        // Create main query for purchases where current user is owner
        let mainQuery = db.collection("purchases")
            .whereField("ownerPhone", isEqualTo: normalizedPhone)
            .whereField("isActive", isEqualTo: true)
            .order(by: "purchasedAt", descending: true)

        // Set up real-time listener
        purchaseListener = mainQuery.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                logger.error("❌ [NOTIFICATIONS] Purchase listener error: \(error.localizedDescription)")
                return
            }

            guard let snapshot = snapshot else {
                logger.warning("⚠️ [NOTIFICATIONS] Purchase listener returned nil snapshot")
                return
            }

            // Process document changes
            for docChange in snapshot.documentChanges {
                guard docChange.type == .added else { continue }

                let purchaseId = docChange.document.documentID
                
                // Skip if already processed
                if self.processedPurchaseIds.contains(purchaseId) {
                    continue
                }

                guard let purchase = FirestorePurchase.from(document: docChange.document) else {
                    continue
                }

                // Normalize phone numbers for comparison
                let normalizedOwnerPhone = self.normalizePhone(purchase.ownerPhone)
                let normalizedPurchaserPhone = self.normalizePhone(purchase.purchaserPhone)
                let normalizedCurrentPhone = self.normalizePhone(normalizedPhone)

                // Check if this purchase is for the current user (handle phone variations)
                let isForCurrentUser = normalizedOwnerPhone == normalizedCurrentPhone ||
                    (normalizedPhone.count == 10 && normalizedOwnerPhone == "1" + normalizedPhone) ||
                    (normalizedPhone.count == 11 && normalizedPhone.hasPrefix("1") && normalizedOwnerPhone == String(normalizedPhone.dropFirst()))

                guard isForCurrentUser else {
                    continue
                }

                // Don't notify if user purchased their own item
                let isSelfPurchase = normalizedPurchaserPhone == normalizedCurrentPhone ||
                    (normalizedPhone.count == 10 && normalizedPurchaserPhone == "1" + normalizedPhone) ||
                    (normalizedPhone.count == 11 && normalizedPhone.hasPrefix("1") && normalizedPurchaserPhone == String(normalizedPhone.dropFirst()))

                if isSelfPurchase {
                    logger.info("ℹ️ [NOTIFICATIONS] Skipping self-purchase notification for item: \(purchase.itemName)")
                    self.processedPurchaseIds.insert(purchaseId)
                    continue
                }

                // Check if notification already sent
                let data = docChange.document.data()
                if data["notificationSent"] as? Bool == true {
                    self.processedPurchaseIds.insert(purchaseId)
                    continue
                }

                // Check if this is a new purchase (after listener started)
                if let lastTimestamp = self.lastPurchaseTimestamp {
                    if purchase.purchasedAt.seconds <= lastTimestamp.seconds {
                        // This purchase was created before we started listening
                        self.processedPurchaseIds.insert(purchaseId)
                        continue
                    }
                }

                // Mark as processed
                self.processedPurchaseIds.insert(purchaseId)
                self.lastPurchaseTimestamp = purchase.purchasedAt

                // Fetch friend name and send notification
                Task { @MainActor in
                    await self.handleNewPurchase(purchase: purchase, purchaseId: purchaseId, context: context)
                }
            }
        }
    }
    
    /// Check for new purchases since last check
    private func checkForNewPurchases(userPhone: String, context: ModelContext) async {
        guard let normalizedPhone = currentUserPhone.map({ normalizePhone($0) }) else {
            return
        }
        
        logger.debug("🔍 [NOTIFICATIONS] Checking for new purchases...")
        
        // Build queries for all phone number variations
        var queries: [Query] = []
        
        // Main query with normalized phone
        queries.append(
            db.collection("purchases")
                .whereField("ownerPhone", isEqualTo: normalizedPhone)
                .whereField("isActive", isEqualTo: true)
                .order(by: "purchasedAt", descending: true)
        )
        
        // If 10 digits, also check with country code
        if normalizedPhone.count == 10 {
            queries.append(
                db.collection("purchases")
                    .whereField("ownerPhone", isEqualTo: "1" + normalizedPhone)
                    .whereField("isActive", isEqualTo: true)
                    .order(by: "purchasedAt", descending: true)
            )
        }
        
        // If 11 digits starting with 1, also check without country code
        if normalizedPhone.count == 11 && normalizedPhone.hasPrefix("1") {
            queries.append(
                db.collection("purchases")
                    .whereField("ownerPhone", isEqualTo: String(normalizedPhone.dropFirst()))
                    .whereField("isActive", isEqualTo: true)
                    .order(by: "purchasedAt", descending: true)
            )
        }
        
        // Query all variations and collect unique purchases
        var allPurchases: [(purchaseId: String, purchase: FirestorePurchase)] = []
        var seenIds = Set<String>()
        
        for query in queries {
            do {
                let snapshot = try await query.getDocuments()
                for doc in snapshot.documents {
                    let purchaseId = doc.documentID
                    guard !seenIds.contains(purchaseId),
                          let purchase = FirestorePurchase.from(document: doc) else {
                        continue
                    }
                    
                    // Skip if already processed
                    if processedPurchaseIds.contains(purchaseId) {
                        continue
                    }
                    
                    // Skip if notification already sent
                    let data = doc.data()
                    if data["notificationSent"] as? Bool == true {
                        processedPurchaseIds.insert(purchaseId)
                        continue
                    }
                    
                    // Check if this is a new purchase (after last check)
                    if let lastTimestamp = lastPurchaseTimestamp {
                        if purchase.purchasedAt.seconds <= lastTimestamp.seconds {
                            processedPurchaseIds.insert(purchaseId)
                            continue
                        }
                    }
                    
                    // Normalize phone numbers for comparison
                    let normalizedOwnerPhone = normalizePhone(purchase.ownerPhone)
                    let normalizedPurchaserPhone = normalizePhone(purchase.purchaserPhone)
                    let normalizedCurrentPhone = normalizePhone(normalizedPhone)
                    
                    // Check if this purchase is for the current user
                    let isForCurrentUser = normalizedOwnerPhone == normalizedCurrentPhone ||
                        (normalizedPhone.count == 10 && normalizedOwnerPhone == "1" + normalizedPhone) ||
                        (normalizedPhone.count == 11 && normalizedPhone.hasPrefix("1") && normalizedOwnerPhone == String(normalizedPhone.dropFirst()))
                    
                    guard isForCurrentUser else { continue }
                    
                    // Don't notify if user purchased their own item
                    let isSelfPurchase = normalizedPurchaserPhone == normalizedCurrentPhone ||
                        (normalizedPhone.count == 10 && normalizedPurchaserPhone == "1" + normalizedPhone) ||
                        (normalizedPhone.count == 11 && normalizedPhone.hasPrefix("1") && normalizedPurchaserPhone == String(normalizedPhone.dropFirst()))
                    
                    if isSelfPurchase {
                        logger.info("ℹ️ [NOTIFICATIONS] Skipping self-purchase notification for item: \(purchase.itemName)")
                        processedPurchaseIds.insert(purchaseId)
                        continue
                    }
                    
                    allPurchases.append((purchaseId: purchaseId, purchase: purchase))
                    seenIds.insert(purchaseId)
                }
            } catch {
                logger.error("❌ [NOTIFICATIONS] Error querying purchases: \(error.localizedDescription)")
            }
        }
        
        // Process new purchases
        if !allPurchases.isEmpty {
            logger.info("🔔 [NOTIFICATIONS] Found \(allPurchases.count) new purchase(s)")
            
            // Sort by purchase time (newest first)
            allPurchases.sort { $0.purchase.purchasedAt.seconds > $1.purchase.purchasedAt.seconds }
            
            // Process each purchase
            for (purchaseId, purchase) in allPurchases {
                await handleNewPurchase(purchase: purchase, purchaseId: purchaseId, context: context)
                processedPurchaseIds.insert(purchaseId)
                
                // Update last check timestamp
                if lastPurchaseTimestamp == nil || purchase.purchasedAt.seconds > lastPurchaseTimestamp!.seconds {
                    lastPurchaseTimestamp = purchase.purchasedAt
                }
            }
        }
    }

    /// Stop listening for purchases
    func stopPurchaseListener() {
        if let listener = purchaseListener {
            listener.remove()
            purchaseListener = nil
            logger.info("🔕 [NOTIFICATIONS] Stopped purchase listener")
        }
    }

    /// Handle a new purchase notification
    private func handleNewPurchase(purchase: FirestorePurchase, purchaseId: String, context: ModelContext) async {
        logger.info("🔔 [NOTIFICATIONS] Processing new purchase: \(purchase.itemName) by \(purchase.purchaserPhone)")

        // Try to get friend name from local SwiftData first
        var friendName: String? = nil
        let normalizedPurchaserPhone = normalizePhone(purchase.purchaserPhone)
        
        // Pre-compute phone number variations for predicate
        let purchaserPhoneVariations: [String] = {
            var variations = [normalizedPurchaserPhone]
            if normalizedPurchaserPhone.count == 10 {
                variations.append("1" + normalizedPurchaserPhone)
            } else if normalizedPurchaserPhone.count == 11 && normalizedPurchaserPhone.hasPrefix("1") {
                variations.append(String(normalizedPurchaserPhone.dropFirst()))
            }
            return variations
        }()

        // Fetch all friends and match manually (predicates can't use complex normalization)
        let allFriendsDescriptor = FetchDescriptor<Friend>()
        if let allFriends = try? context.fetch(allFriendsDescriptor) {
            for friend in allFriends {
                guard let friendPhone = friend.phoneNumber else { continue }
                let normalizedFriendPhone = normalizePhone(friendPhone)
                
                // Check if friend phone matches any variation of purchaser phone
                if purchaserPhoneVariations.contains(normalizedFriendPhone) ||
                   (normalizedFriendPhone.count == 10 && purchaserPhoneVariations.contains("1" + normalizedFriendPhone)) ||
                   (normalizedFriendPhone.count == 11 && normalizedFriendPhone.hasPrefix("1") && purchaserPhoneVariations.contains(String(normalizedFriendPhone.dropFirst()))) {
                    friendName = friend.name
                    logger.info("✅ [NOTIFICATIONS] Found friend name in SwiftData: \(friendName ?? "nil")")
                    break
                }
            }
        }

        if friendName == nil {
            // Try to fetch from Firestore
            logger.info("🔍 [NOTIFICATIONS] Friend not found in SwiftData, checking Firestore...")
            if let userPhone = currentUserPhone {
                do {
                    let snapshot = try await db.collection("friends")
                        .whereField("userPhone", isEqualTo: userPhone)
                        .whereField("friendPhone", isEqualTo: normalizedPurchaserPhone)
                        .limit(to: 1)
                        .getDocuments()

                    if let doc = snapshot.documents.first,
                       let friend = FirestoreFriend.from(document: doc) {
                        friendName = friend.friendName
                        logger.info("✅ [NOTIFICATIONS] Found friend name in Firestore: \(friendName ?? "nil")")
                    } else {
                        // Also try with country code variations
                        if normalizedPurchaserPhone.count == 10 {
                            let withCountryCode = "1" + normalizedPurchaserPhone
                            let altSnapshot = try await db.collection("friends")
                                .whereField("userPhone", isEqualTo: userPhone)
                                .whereField("friendPhone", isEqualTo: withCountryCode)
                                .limit(to: 1)
                                .getDocuments()

                            if let doc = altSnapshot.documents.first,
                               let friend = FirestoreFriend.from(document: doc) {
                                friendName = friend.friendName
                                logger.info("✅ [NOTIFICATIONS] Found friend name in Firestore (with country code): \(friendName ?? "nil")")
                            }
                        }
                    }
                } catch {
                    logger.error("❌ [NOTIFICATIONS] Failed to fetch friend from Firestore: \(error.localizedDescription)")
                }
            }
        }

        // Use friend name or fallback
        let displayName = friendName ?? "Someone"

        // Send notification
        await NotificationManager.shared.sendItemPurchasedNotification(
            itemName: purchase.itemName,
            friendName: displayName
        )

        logger.info("✅ [NOTIFICATIONS] Notification sent for purchase: \(purchase.itemName) by \(displayName)")

        // Mark notification as sent to prevent Cloud Function from sending duplicate
        let purchaseRef = db.collection("purchases").document(purchaseId)
        do {
            try await purchaseRef.updateData([
                "notificationSent": true,
                "notificationSentAt": FieldValue.serverTimestamp(),
                "sentBy": "local"
            ])
            logger.info("✅ [NOTIFICATIONS] Marked purchase notification as sent: \(purchaseId)")
        } catch {
            logger.error("⚠️ [NOTIFICATIONS] Failed to mark notification as sent: \(error.localizedDescription)")
        }
    }

    // MARK: - User Management

    /// Create or update user document in Firestore
    func createOrUpdateUser(displayName: String) async throws {
        guard let userPhone = currentUserPhone else {
            throw FirebaseError.notAuthenticated
        }

        logger.info("👤 [FIREBASE] Creating/updating user: \(displayName)")
        logger.info("👤 [FIREBASE] User phone (normalized): \(userPhone)")

        let docRef = db.collection("users").document(userPhone)

        // This runs at every launch, so `settings` and `createdAt` are seeded only when the
        // document is new — merging them in would reset the user's notification preference.
        guard try await docRef.getDocument().exists else {
            try await docRef.setData([
                "displayName": displayName,
                "createdAt": Timestamp(),
                "fcmTokens": [],
                "settings": [
                    "notificationsEnabled": false,
                    "showPurchasedItems": false
                ]
            ])
            logger.info("✅ [FIREBASE] User document created at \(userPhone)")
            return
        }

        try await docRef.setData(["displayName": displayName], merge: true)

        logger.info("✅ [FIREBASE] User document updated at \(userPhone)")
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
                notificationsEnabled: (data["settings"] as? [String: Any])?["notificationsEnabled"] as? Bool ?? false,
                showPurchasedItems: (data["settings"] as? [String: Any])?["showPurchasedItems"] as? Bool ?? false
            )
        )

        logger.info("✅ [FIREBASE] User fetched: \(user.displayName)")
        return user
    }

    // MARK: - FCM Token Management

    /// Upload FCM token to Firestore user document
    func uploadFCMToken(_ token: String) async throws {
        guard let userPhone = currentUserPhone else {
            throw FirebaseError.notAuthenticated
        }

        let normalizedPhone = normalizePhone(userPhone)
        let userRef = db.collection("users").document(normalizedPhone)

        // Add token to fcmTokens array (using arrayUnion to avoid duplicates)
        try await userRef.updateData([
            "fcmTokens": FieldValue.arrayUnion([token])
        ])

        logger.info("📱 [FCM] Uploaded FCM token to Firestore for user: \(normalizedPhone)")
    }

    /// Remove FCM token from Firestore (on logout)
    func removeFCMToken(_ token: String) async throws {
        guard let userPhone = currentUserPhone else { return }

        let normalizedPhone = normalizePhone(userPhone)
        let userRef = db.collection("users").document(normalizedPhone)

        try await userRef.updateData([
            "fcmTokens": FieldValue.arrayRemove([token])
        ])

        logger.info("🗑️ [FCM] Removed FCM token from Firestore for user: \(normalizedPhone)")
    }

    /// Update notification preference in Firestore
    func updateNotificationSetting(_ enabled: Bool) async throws {
        guard let userPhone = currentUserPhone else {
            throw FirebaseError.notAuthenticated
        }

        let normalizedPhone = normalizePhone(userPhone)
        let userRef = db.collection("users").document(normalizedPhone)

        try await userRef.updateData([
            "settings.notificationsEnabled": enabled
        ])

        logger.info("⚙️ [SETTINGS] Updated notification preference: \(enabled) for user: \(normalizedPhone)")
    }

    /// Deletes all Firestore data for the current user, then deletes the Auth account and local SwiftData.
    func deleteAllAccountData(context: ModelContext) async throws {
        guard let userPhone = currentUserPhone else {
            throw FirebaseError.notAuthenticated
        }

        logger.info("🗑️ [FIREBASE] Deleting all account data for: \(userPhone)")

        let wishlistSnapshot = try await db.collection("wishlistItems")
            .whereField("ownerPhone", isEqualTo: userPhone)
            .getDocuments()
        for doc in wishlistSnapshot.documents {
            try await doc.reference.delete()
        }

        let childrenSnapshot = try await db.collection("children")
            .whereField("parentPhone", isEqualTo: userPhone)
            .getDocuments()
        for doc in childrenSnapshot.documents {
            try await doc.reference.delete()
        }

        let friendsSnapshot = try await db.collection("friends")
            .whereField("userPhone", isEqualTo: userPhone)
            .getDocuments()
        for doc in friendsSnapshot.documents {
            try await doc.reference.delete()
        }

        let ownerPurchasesSnapshot = try await db.collection("purchases")
            .whereField("ownerPhone", isEqualTo: userPhone)
            .getDocuments()
        for doc in ownerPurchasesSnapshot.documents {
            try await doc.reference.delete()
        }

        let purchaserPurchasesSnapshot = try await db.collection("purchases")
            .whereField("purchaserPhone", isEqualTo: userPhone)
            .getDocuments()
        for doc in purchaserPurchasesSnapshot.documents {
            try await doc.reference.delete()
        }

        try await db.collection("users").document(userPhone).delete()

        let allFriends = try context.fetch(FetchDescriptor<Friend>())
        for friend in allFriends {
            context.delete(friend)
        }

        let allChildren = try context.fetch(FetchDescriptor<Child>())
        for child in allChildren {
            context.delete(child)
        }

        let allItems = try context.fetch(FetchDescriptor<WishlistItem>())
        for item in allItems {
            context.delete(item)
        }

        try context.save()

        try await Auth.auth().currentUser?.delete()

        logger.info("✅ [FIREBASE] All account data deleted")
    }

    /// Uploads local wishlist items that have not yet been synced to Firestore (e.g. share-extension imports).
    func uploadUnsyncedLocalItems(context: ModelContext) async throws {
        guard currentUserPhone != nil else {
            throw FirebaseError.notAuthenticated
        }

        let predicate = #Predicate<WishlistItem> { item in
            item.isOwnedByCurrentUser == true && item.lastSyncedAt == nil
        }
        let unsyncedItems = try context.fetch(FetchDescriptor(predicate: predicate))

        logger.info("📤 [FIREBASE] Uploading \(unsyncedItems.count) unsynced local items")

        // Resolve child ownership from ownerId so child items are never uploaded as "user"
        let allChildren = try context.fetch(FetchDescriptor<Child>())

        for item in unsyncedItems {
            let owningChild = allChildren.first { $0.id == item.ownerId }

            var childIdString: String? = nil
            if let child = owningChild {
                guard let firebaseChildId = child.cloudKitRecordID, !firebaseChildId.isEmpty else {
                    // Child not synced to Firebase yet - skip rather than misfile the item as the parent's
                    logger.warning("⚠️ [FIREBASE] Skipping upload of '\(item.name)' - child '\(child.name)' has no Firebase ID yet")
                    continue
                }
                childIdString = firebaseChildId
            }

            _ = try await saveWishlistItem(
                id: item.id,
                name: item.name,
                url: item.url,
                description: item.itemDescription,
                imageData: item.imageData,
                ownerId: item.ownerId,
                ownerType: owningChild != nil ? "child" : "user",
                childId: childIdString,
                context: context
            )
        }
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
            return String(localized: "User is not authenticated")
        case .invalidData:
            return String(localized: "Invalid data format")
        case .networkError:
            return String(localized: "Network error occurred")
        }
    }
}
