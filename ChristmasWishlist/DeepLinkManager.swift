//
//  DeepLinkManager.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData
import CloudKit
import Combine

class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()
    
    @Published var pendingFriendName: String?
    @Published var showAddConfirmation = false
    
    private var pendingRecordID: String?
    
    @MainActor
    func handle(url: URL, modelContext: ModelContext) {
        print("🔗 [DEEPLINK] Handling URL: \(url.absoluteString)")

        guard url.scheme == "christmaswishlist",
              url.host == "add-friend" else {
            print("❌ [DEEPLINK] Invalid scheme or host")
            return
        }

        // Parse query items
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems else {
            return
        }

        // Extract parameters
        guard let recordID = queryItems.first(where: { $0.name == "id" })?.value,
              let name = queryItems.first(where: { $0.name == "name" })?.value else {
            print("❌ [DEEPLINK] Missing id or name parameters")
            return
        }

        print("🔗 [DEEPLINK] Found friend invite: \(name) (\(recordID))")

        // Check if friend already exists by Record ID
        let recordIDDescriptor = FetchDescriptor<Friend>(
            predicate: #Predicate<Friend> { friend in
                friend.friendUserRecordID == recordID
            }
        )

        // Also check if friend exists by name (for updating incomplete records)
        let nameDescriptor = FetchDescriptor<Friend>(
            predicate: #Predicate<Friend> { friend in
                friend.name == name
            }
        )

        do {
            // First check by Record ID
            let existingByRecordID = try modelContext.fetch(recordIDDescriptor)
            if let existing = existingByRecordID.first {
                print("ℹ️ [DEEPLINK] Friend already exists with this Record ID: \(existing.name)")
                // Update name if it changed
                if existing.name != name {
                    existing.name = name
                    try? modelContext.save()
                    print("✅ [DEEPLINK] Updated friend name to: \(name)")
                }
                return
            }

            // Check by name (for incomplete friend records)
            let existingByName = try modelContext.fetch(nameDescriptor)
            if let existing = existingByName.first {
                print("ℹ️ [DEEPLINK] Friend exists by name but missing Record ID - updating...")
                print("🔗 [DEEPLINK] Old: hasApp=\(existing.hasApp), recordID=\(existing.friendUserRecordID ?? "nil")")

                // Update the existing friend with the Record ID
                existing.friendUserRecordID = recordID
                existing.hasApp = true

                do {
                    try modelContext.save()
                    print("✅ [DEEPLINK] Updated existing friend '\(name)' with Record ID: \(recordID)")
                    print("✅ [DEEPLINK] New: hasApp=\(existing.hasApp), recordID=\(existing.friendUserRecordID ?? "nil")")
                    HapticManager.notification(.success)

                    // IMMEDIATELY download friend's wishlist since they now have a Record ID
                    Task {
                        await downloadFriendWishlistImmediately(friendRecordID: recordID, friendName: name, modelContext: modelContext)
                    }
                } catch {
                    print("❌ [DEEPLINK] Failed to save updated friend: \(error)")
                }

                // Trigger refresh
                CloudKitManager.shared.shouldRefreshFriends.toggle()
                return
            }

            // Friend doesn't exist at all - store for confirmation dialog
            print("🆕 [DEEPLINK] New friend - showing confirmation dialog")
            self.pendingRecordID = recordID
            self.pendingFriendName = name
            self.showAddConfirmation = true

        } catch {
            print("❌ [DEEPLINK] Error checking for existing friend: \(error)")
        }
    }
    
    @MainActor
    func confirmAddFriend(modelContext: ModelContext) {
        guard let name = pendingFriendName,
              let recordID = pendingRecordID else { return }

        print("🔗 [DEEPLINK] Adding new friend: \(name)")

        let newFriend = Friend(
            name: name,
            hasApp: true,
            friendUserRecordID: recordID
        )

        modelContext.insert(newFriend)

        do {
            try modelContext.save()
            print("✅ [DEEPLINK] Friend saved successfully")
            HapticManager.notification(.success)

            // Trigger refresh
            CloudKitManager.shared.shouldRefreshFriends.toggle()

            // IMMEDIATELY download friend's wishlist from CloudKit
            Task {
                await downloadFriendWishlistImmediately(friendRecordID: recordID, friendName: name, modelContext: modelContext)
            }
        } catch {
            print("❌ [DEEPLINK] Failed to save friend: \(error)")
            HapticManager.notification(.error)
        }

        // Reset state
        pendingFriendName = nil
        pendingRecordID = nil
        showAddConfirmation = false
    }

    @MainActor
    private func downloadFriendWishlistImmediately(friendRecordID: String, friendName: String, modelContext: ModelContext) async {
        print("⚡ [IMMEDIATE] Downloading \(friendName)'s wishlist NOW...")

        let cloudKit = CloudKitManager.shared

        guard cloudKit.isSignedInToiCloud else {
            print("⚠️ [IMMEDIATE] Not signed in to iCloud")
            return
        }

        do {
            // Fetch friend's wishlist items from CloudKit
            let items = try await cloudKit.fetchFriendWishlistItems(friendRecordID: friendRecordID)
            print("⚡ [IMMEDIATE] Downloaded \(items.count) items for \(friendName)")

            // Fetch friend's children
            let children = try await cloudKit.fetchChildrenForUser(userRecordID: friendRecordID)
            print("⚡ [IMMEDIATE] Downloaded \(children.count) children for \(friendName)")

            // Note: We don't save to SwiftData because friends' items are viewed read-only
            // They're cached in WishlistCache for display in FriendWishlistView

            print("✅ [IMMEDIATE] \(friendName)'s wishlist ready to view!")
            HapticManager.notification(.success)
        } catch {
            print("❌ [IMMEDIATE] Failed to download wishlist: \(error)")
        }
    }
    
    func generateInviteLink(name: String? = nil) -> URL? {
        guard let recordID = CloudKitManager.shared.currentUserRecordID?.recordName else {
            return nil
        }
        
        // Use provided name or default
        let friendName = name ?? "A Friend"
        
        var components = URLComponents()
        components.scheme = "christmaswishlist"
        components.host = "add-friend"
        components.queryItems = [
            URLQueryItem(name: "id", value: recordID),
            URLQueryItem(name: "name", value: friendName)
        ]
        
        return components.url
    }
}
