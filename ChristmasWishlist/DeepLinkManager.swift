//
//  DeepLinkManager.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData
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

                    // Friend's wishlist will be available via Firebase when they navigate to it
                } catch {
                    print("❌ [DEEPLINK] Failed to save updated friend: \(error)")
                }

                // Friend updated - refresh handled by SwiftData
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

            // Friend saved - refresh handled by SwiftData
        } catch {
            print("❌ [DEEPLINK] Failed to save friend: \(error)")
            HapticManager.notification(.error)
        }

        // Reset state
        pendingFriendName = nil
        pendingRecordID = nil
        showAddConfirmation = false
    }

    func generateInviteLink(name: String? = nil) -> URL? {
        // TODO: Implement with Firebase phone number based deep linking
        // For now, return nil until Firebase deep linking is implemented
        return nil
    }
}
