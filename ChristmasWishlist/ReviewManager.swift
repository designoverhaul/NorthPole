//
//  ReviewManager.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import Foundation
import StoreKit
import SwiftUI

/// Manages App Store review prompts following Apple's best practices
/// - Only prompts at positive moments (after user accomplishes something)
/// - Automatically respects Apple's 3-prompts-per-365-days limit
/// - Tracks milestones to avoid over-prompting
class ReviewManager {
    static let shared = ReviewManager()

    private init() {}

    // MARK: - User Defaults Keys
    private enum Keys {
        static let itemsAddedCount = "reviewManager_itemsAddedCount"
        static let hasAddedFirstFriend = "reviewManager_hasAddedFirstFriend"
        static let hasMarkedFirstPurchase = "reviewManager_hasMarkedFirstPurchase"
        static let lastReviewRequestDate = "reviewManager_lastReviewRequestDate"
    }

    // MARK: - Milestone Tracking

    /// Call this every time a user adds a wishlist item
    func incrementItemsAdded() {
        let count = UserDefaults.standard.integer(forKey: Keys.itemsAddedCount) + 1
        UserDefaults.standard.set(count, forKey: Keys.itemsAddedCount)

        // Request review after 3rd item
        if count == 3 {
            requestReview(reason: "Added 3 items")
        }
    }

    /// Call this when user adds their first friend
    func markFirstFriendAdded() {
        let hasAdded = UserDefaults.standard.bool(forKey: Keys.hasAddedFirstFriend)

        if !hasAdded {
            UserDefaults.standard.set(true, forKey: Keys.hasAddedFirstFriend)
            requestReview(reason: "Added first friend")
        }
    }

    /// Call this when user marks their first item as purchased for a friend
    func markFirstPurchase() {
        let hasPurchased = UserDefaults.standard.bool(forKey: Keys.hasMarkedFirstPurchase)

        if !hasPurchased {
            UserDefaults.standard.set(true, forKey: Keys.hasMarkedFirstPurchase)
            requestReview(reason: "First purchase")
        }
    }

    // MARK: - Manual Review Request

    /// Manually request review (for Settings button)
    func requestReviewManually() {
        requestReview(reason: "Manual request")
    }

    // MARK: - Private Helpers

    /// Lets the triggering UI (sheet dismissal, sparkle animation) finish before the prompt appears.
    private static let presentationDelay: Duration = .seconds(2)

    private func requestReview(reason: String) {
        // Don't prompt too frequently - wait at least 7 days between prompts
        if let lastRequestDate = UserDefaults.standard.object(forKey: Keys.lastReviewRequestDate) as? Date {
            let daysSinceLastRequest = Calendar.current.dateComponents([.day], from: lastRequestDate, to: Date()).day ?? 0

            if daysSinceLastRequest < 7 {
                print("⭐️ [REVIEW] Skipping review prompt - only \(daysSinceLastRequest) days since last request")
                return
            }
        }

        Task { @MainActor in
            try? await Task.sleep(for: Self.presentationDelay)

            guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
                print("⭐️ [REVIEW] No active window scene found")
                return
            }

            // iOS automatically limits this to 3 prompts per 365 days
            print("⭐️ [REVIEW] Requesting review - Reason: \(reason)")
            AppStore.requestReview(in: scene)

            UserDefaults.standard.set(Date(), forKey: Keys.lastReviewRequestDate)
        }
    }
}
