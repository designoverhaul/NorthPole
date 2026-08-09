//
//  NotificationManager.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import UserNotifications
import OSLog

private let logger = Logger(subsystem: "com.designoverhaul.ChristmasWishlist", category: "NotificationManager")

@MainActor
class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    // MARK: - Permission Management

    /// Request notification permissions from the user
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            logger.info("Notification permission granted: \(granted)")
            return granted
        } catch {
            logger.error("Failed to request notification authorization: \(error.localizedDescription)")
            return false
        }
    }

    /// Check current authorization status
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Notification Delivery

    /// Send notification when someone purchases an item from your wishlist
    func sendItemPurchasedNotification(itemName: String, friendName: String) async {
        print("📲 [LOCAL_NOTIFICATION] Attempting to send notification for item: '\(itemName)'")

        // Check if notifications are enabled in settings
        // Default to false if never set (matches @AppStorage default in SettingsView — the
        // setting is paywalled, so it stays off until the user unlocks it)
        let notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        print("⚙️ [LOCAL_NOTIFICATION] Settings: notificationsEnabled = \(notificationsEnabled)")

        guard notificationsEnabled else {
            logger.info("Notifications disabled in settings, skipping notification")
            print("⚠️ [LOCAL_NOTIFICATION] Notifications disabled in app settings")
            return
        }

        // Check authorization status
        let status = await checkAuthorizationStatus()
        print("🔐 [LOCAL_NOTIFICATION] Authorization status: \(status.rawValue)")

        guard status == .authorized else {
            logger.warning("Notifications not authorized, current status: \(status.rawValue)")
            print("⚠️ [LOCAL_NOTIFICATION] Not authorized (status: \(status.rawValue))")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Gift Purchased!")
        content.body = String(localized: "🎁 Someone purchased \(itemName) for you!")
        content.sound = .default
        content.badge = 1

        // Add custom data for handling notification taps
        content.userInfo = [
            "type": "item_purchased",
            "itemName": itemName,
            "friendName": friendName
        ]

        print("📝 [LOCAL_NOTIFICATION] Created notification content:")
        print("   Title: \(content.title)")
        print("   Body: \(content.body)")

        // Deliver immediately
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // nil trigger = immediate delivery
        )

        do {
            try await center.add(request)
            logger.info("✅ Sent item purchased notification for '\(itemName)'")
            print("✅ [LOCAL_NOTIFICATION] Successfully sent notification for '\(itemName)'")
        } catch {
            logger.error("❌ Failed to send notification: \(error.localizedDescription)")
            print("❌ [LOCAL_NOTIFICATION] Failed to send: \(error.localizedDescription)")
        }
    }

    // MARK: - Utility

    /// Clear all delivered notifications and reset badge count
    func clearAllNotifications() {
        center.removeAllDeliveredNotifications()
        center.setBadgeCount(0)
        logger.info("Cleared all notifications")
    }

    /// Remove pending notification requests
    func removePendingNotifications() {
        center.removeAllPendingNotificationRequests()
        logger.info("Removed all pending notifications")
    }
}
