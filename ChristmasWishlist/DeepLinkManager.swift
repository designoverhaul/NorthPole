//
//  DeepLinkManager.swift
//  ChristmasWishlist
//

import SwiftUI
import SwiftData
import Combine

/// Handles inbound `christmaswishlist://add-friend` links. Nothing in the app
/// generates these anymore — Messages renders a custom scheme as plain text, so
/// invites send the App Store link only — but links from older builds are still
/// out in people's message threads and must keep working.
class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()

    @Published var pendingFriendName: String?
    @Published var pendingFriendPhone: String?
    @Published var showAddConfirmation = false

    @MainActor
    func handle(url: URL, modelContext: ModelContext) {
        print("🔗 [DEEPLINK] Handling URL: \(url.absoluteString)")

        guard url.scheme == "christmaswishlist",
              url.host == "add-friend" else {
            print("❌ [DEEPLINK] Invalid scheme or host")
            return
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems,
              let phoneRaw = queryItems.first(where: { $0.name == "phone" })?.value,
              let name = queryItems.first(where: { $0.name == "name" })?.value else {
            print("❌ [DEEPLINK] Missing phone or name parameters")
            return
        }

        let phone = PhoneNumber.normalize(phoneRaw)
        guard !phone.isEmpty else {
            print("❌ [DEEPLINK] Invalid phone")
            return
        }

        print("🔗 [DEEPLINK] Found friend invite: \(name) (\(phone))")

        let descriptor = FetchDescriptor<Friend>()
        do {
            let existing = try modelContext.fetch(descriptor).first { friend in
                guard let friendPhone = friend.phoneNumber else { return false }
                return PhoneNumber.matches(friendPhone, phone)
            }

            if let existing {
                existing.name = name
                existing.phoneNumber = phone
                existing.hasApp = true
                try? modelContext.save()
                print("ℹ️ [DEEPLINK] Friend already exists — updated \(existing.name)")
                return
            }

            pendingFriendPhone = phone
            pendingFriendName = name
            showAddConfirmation = true
        } catch {
            print("❌ [DEEPLINK] Error checking for existing friend: \(error)")
        }
    }

    @MainActor
    func confirmAddFriend(modelContext: ModelContext) {
        guard let name = pendingFriendName,
              let phone = pendingFriendPhone else { return }

        print("🔗 [DEEPLINK] Adding new friend: \(name) (\(phone))")

        Task {
            do {
                _ = try await FirebaseManager.shared.addFriend(
                    name: name,
                    phone: phone,
                    context: modelContext
                )
                HapticManager.notification(.success)
            } catch {
                print("❌ [DEEPLINK] Failed to save friend: \(error)")
                HapticManager.notification(.error)
            }

            await MainActor.run {
                pendingFriendName = nil
                pendingFriendPhone = nil
                showAddConfirmation = false
            }
        }
    }
}
