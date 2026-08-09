//
//  SuperwallManager.swift
//  ChristmasWishlist
//

import Combine
import Foundation
import OSLog
import SuperwallKit

private let logger = Logger(subsystem: "com.designoverhaul.ChristmasWishlist", category: "Superwall")

/// Owns the Superwall SDK: configuration, identity, and the free-tier gift allowance.
///
/// The allowance is *per person* — the user and each child each get their own
/// `freeGiftsPerPerson` before the paywall appears, matching how `MyWishlistView`
/// splits lists by the selected profile.
@MainActor
final class SuperwallManager: ObservableObject {
    static let shared = SuperwallManager()

    /// Gifts a single person can have on their list before the paywall gates further adds.
    static let freeGiftsPerPerson = 8

    /// Registered when someone tries to add a gift for a person who has used up the free allowance.
    private static let giftLimitPlacement = "gift_limit_reached"

    /// Registered every time someone asks Santa for gift ideas.
    private static let askSantaPlacement = "ask_santa_search"

    /// Registered by the Settings upgrade row, so the paywall can be reached without hitting the limit.
    private static let upgradePlacement = "unlock_unlimited_gifts"

    /// Registered when someone turns on a setting that spoils friends' purchases.
    private static let revealPurchasesPlacement = "reveal_purchases"

    /// The spoiler setting being switched on, passed to the campaign so audience filters can
    /// treat the two Settings toggles and the onboarding choice differently.
    enum RevealFeature: String {
        case showPurchasedStatus = "show_purchased_status"
        case purchaseNotifications = "purchase_notifications"
        case onboardingSurprises = "onboarding_surprises"
    }

    /// True while the user holds any active entitlement, i.e. gift limits no longer apply.
    @Published private(set) var isSubscribed = false

    private var cancellables = Set<AnyCancellable>()
    private var identifiedUserId: String?

    /// `Superwall.shared` asserts when the SDK was never configured, so every placement is
    /// skipped (fail open) when the API key is missing.
    private var isConfigured = false

    private init() {}

    // MARK: - Configuration

    /// Call once from `application(_:didFinishLaunchingWithOptions:)`.
    func configure() {
        guard let apiKey = Self.apiKey else {
            logger.error("❌ [SUPERWALL] No SUPERWALL_API_KEY found — paywalls are disabled and gift limits will not be enforced")
            return
        }

        Superwall.configure(apiKey: apiKey)
        isConfigured = true
        Superwall.shared.delegate = self
        isSubscribed = Superwall.shared.subscriptionStatus.isActive
        logger.info("💳 [SUPERWALL] Configured (subscribed: \(self.isSubscribed))")

        observeAuthentication()
    }

    /// Superwall's public API key, injected at build time from `Secrets.xcconfig`.
    private static var apiKey: String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPERWALL_API_KEY") as? String,
              key.hasPrefix("pk_") else {
            return nil
        }
        return key
    }

    /// Ties Superwall's identity to the Firebase account so entitlements follow the user across devices.
    private func observeAuthentication() {
        FirebaseAuthManager.shared.$currentUser
            .map(\.?.uid)
            .sink { [weak self] uid in
                MainActor.assumeIsolated {
                    self?.updateIdentity(uid: uid)
                }
            }
            .store(in: &cancellables)
    }

    /// Superwall keeps an anonymous alias per install, and `reset()` mints a fresh one while
    /// discarding paywall assignments. So it's only correct when a real user signs *out* —
    /// a launch that was already signed out must leave the existing alias alone.
    private func updateIdentity(uid: String?) {
        guard uid != identifiedUserId else { return }
        identifiedUserId = uid

        if let uid {
            Superwall.shared.identify(userId: uid)
            logger.info("💳 [SUPERWALL] Identified user")
        } else {
            Superwall.shared.reset()
            logger.info("💳 [SUPERWALL] Reset identity (signed out)")
        }
    }

    // MARK: - Gift Limit

    /// Gifts still available for a person, or `nil` when the user is subscribed (unlimited).
    func remainingGifts(usedCount: Int) -> Int? {
        guard !isSubscribed else { return nil }
        return max(0, Self.freeGiftsPerPerson - usedCount)
    }

    /// Runs `addGift` if the person still has room, otherwise lets Superwall decide.
    ///
    /// Over the limit, the paywall's *Gated* setting means `addGift` only runs once the
    /// user subscribes. If no campaign is configured yet, Superwall calls `addGift`
    /// straight away — adding gifts keeps working rather than dead-ending.
    func requestAddGift(
        usedCount: Int,
        isForChild: Bool,
        addGift: @escaping () -> Void
    ) {
        guard usedCount >= Self.freeGiftsPerPerson, isConfigured else {
            addGift()
            return
        }

        logger.info("💳 [SUPERWALL] Gift limit reached (\(usedCount) gifts) — registering placement")

        Superwall.shared.register(
            placement: Self.giftLimitPlacement,
            params: [
                "gift_count": usedCount,
                "gift_limit": Self.freeGiftsPerPerson,
                "person_type": isForChild ? "child" : "self"
            ]
        ) {
            addGift()
        }
    }

    // MARK: - Ask Santa

    /// Runs `search` unless the campaign decides Ask Santa needs a paywall first.
    ///
    /// Unlike the gift limit there's no allowance in the app here, so whether Ask Santa is
    /// free, free-for-the-first-few, or paid is entirely a dashboard decision — audience
    /// filters can key off `is_refining` to treat "Find More" differently from a first search.
    func requestAskSantaSearch(isRefining: Bool, search: @escaping () -> Void) {
        guard isConfigured else {
            search()
            return
        }

        Superwall.shared.register(
            placement: Self.askSantaPlacement,
            params: ["is_refining": isRefining]
        ) {
            search()
        }
    }

    // MARK: - Spoiler Settings

    /// Runs `enable` only if the campaign lets this user see purchase spoilers.
    ///
    /// Like Ask Santa there's no allowance in the app — whether "Show purchased status" and
    /// "Purchase notifications" are free or paid is a dashboard decision, so the callers must
    /// treat the switch as off until `enable` actually runs.
    ///
    /// `didResolve` always runs once Superwall is finished, *after* `enable` would have run,
    /// so a toggle that optimistically flipped on can snap back when the paywall was dismissed
    /// without a purchase.
    func requestRevealPurchases(
        feature: RevealFeature,
        enable: @escaping () -> Void,
        didResolve: @escaping () -> Void = {}
    ) {
        guard isConfigured else {
            enable()
            didResolve()
            return
        }

        // Superwall calls the handler before the feature closure, so hop to the next main-actor
        // turn to make sure `didResolve` sees the final state.
        func resolve() {
            Task { @MainActor in didResolve() }
        }

        let handler = PaywallPresentationHandler()
        handler.onDismiss { _, _ in resolve() }
        handler.onSkip { _ in resolve() }
        handler.onError { _ in resolve() }

        logger.info("💳 [SUPERWALL] Reveal purchases requested (\(feature.rawValue))")

        Superwall.shared.register(
            placement: Self.revealPurchasesPlacement,
            params: ["feature": feature.rawValue],
            handler: handler
        ) {
            enable()
        }
    }

    /// Presents the paywall from a deliberate upgrade tap, e.g. the Settings row.
    func presentUpgrade() {
        guard isConfigured else { return }
        Superwall.shared.register(placement: Self.upgradePlacement)
    }

    /// The entitlement the dashboard's product grants. Matching it means audience filters on
    /// `device.activeEntitlements` see what they would after a real purchase.
    private static let debugEntitlementId = "pro"

    /// Override entitlement state for exercising paywalls and the gift limit without a
    /// sandbox purchase. Only reachable from Developer Tools (Xcode installs).
    ///
    /// This drives Superwall's own `subscriptionStatus` rather than just our copy, so paywall
    /// gating and audience filters react too; `isSubscribed` then updates itself through the
    /// delegate. Deliberately not persisted — Superwall recomputes entitlements from the receipt
    /// on launch, so an override that outlived the session would silently disagree with the SDK.
    func setDebugSubscribed(_ subscribed: Bool) {
        guard isConfigured else { return }

        Superwall.shared.subscriptionStatus = subscribed
            ? .active([Entitlement(id: Self.debugEntitlementId)])
            : .inactive
        logger.info("💳 [SUPERWALL] Debug override — forcing subscribed: \(subscribed)")
    }
}

// MARK: - SuperwallDelegate

extension SuperwallManager: SuperwallDelegate {
    func subscriptionStatusDidChange(
        from oldValue: SubscriptionStatus,
        to newValue: SubscriptionStatus
    ) {
        isSubscribed = newValue.isActive
        logger.info("💳 [SUPERWALL] Subscription status changed (subscribed: \(self.isSubscribed))")
    }
}
