//
//  ChristmasWishlistApp.swift
//  ChristmasWishlist
//
//  Created by Aaron Heine on 11/16/25.
//

import SwiftUI
import CloudKit
import OSLog
import Combine

private let logger = Logger(subsystem: "com.designoverhaul.ChristmasWishlist", category: "App")

@main
struct ChristmasWishlistApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        let _ = print("🎄 [APP] Body evaluated - hasCompletedOnboarding = \(hasCompletedOnboarding)")

        return WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    MainTabView()
                        .preferredColorScheme(.light)
                        .onAppear {
                            print("🎄 [APP] ✅ MainTabView appeared - SUCCESS!")
                        }
                } else {
                    OnboardingView(isCompleted: $hasCompletedOnboarding)
                        .preferredColorScheme(.light)
                        .onAppear {
                            print("🎄 [APP] OnboardingView appeared - hasCompletedOnboarding = \(hasCompletedOnboarding)")
                        }
                }
            }
            .onChange(of: hasCompletedOnboarding) { oldValue, newValue in
                print("🎄 [APP] ⚡ hasCompletedOnboarding changed from \(oldValue) to \(newValue)")
            }
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    private var cloudKitObserver: Task<Void, Never>?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        logger.info("App launched")

        // Register for remote notifications
        application.registerForRemoteNotifications()

        // ALWAYS request notification permissions on launch
        // This ensures the app appears in Settings → Notifications
        Task { @MainActor in
            // Check if we've ever requested permissions before
            let status = await NotificationManager.shared.checkAuthorizationStatus()

            if status == .notDetermined {
                // First time - request permissions
                print("📱 [PERMISSIONS] First launch - requesting notification permissions...")
                let granted = await NotificationManager.shared.requestAuthorization()

                // Set the default based on user's response
                UserDefaults.standard.set(granted, forKey: "notificationsEnabled")
                print("📱 [PERMISSIONS] User \(granted ? "granted" : "denied") notification permissions")
            } else {
                // Already requested before - sync the toggle with actual iOS permission
                let isAuthorized = (status == .authorized)
                let currentSetting = UserDefaults.standard.bool(forKey: "notificationsEnabled")

                // If settings don't match reality, update them
                if isAuthorized != currentSetting {
                    UserDefaults.standard.set(isAuthorized, forKey: "notificationsEnabled")
                    print("📱 [PERMISSIONS] Synced notification setting to match iOS permission: \(isAuthorized)")
                }
            }
        }

        // Wait for CloudKit sign-in, then subscribe to changes
        cloudKitObserver = Task { @MainActor in
            let cloudKit = CloudKitManager.shared

            // Wait for sign-in to complete
            while !cloudKit.isSignedInToiCloud {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }

            // Now safe to subscribe
            do {
                try await cloudKit.subscribeToMyWishlistChanges()
                try await cloudKit.subscribeToPurchases()

                // Start polling as a fallback (in case push notifications don't work)
                // Poll every 30 seconds to check for new purchases
                cloudKit.startPurchasePolling(interval: 30)

                // Preload friends data in background for instant display
                print("🚀 [APP] Starting friends preload...")
                await cloudKit.preloadFriendsData()
            } catch {
                logger.error("Failed to subscribe to CloudKit changes: \(error.localizedDescription)")
            }
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        logger.info("✅ Registered for remote notifications")
        logger.info("📱 Device token: \(token.prefix(20))...")
        print("✅ [PUSH] Successfully registered for remote notifications")
        print("📱 [PUSH] Device token: \(token.prefix(20))...")
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        logger.error("❌ Failed to register for remote notifications: \(error.localizedDescription)")
        print("❌ [PUSH] Failed to register for remote notifications: \(error.localizedDescription)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        logger.info("🔔 Received remote notification")
        print("🔔 [PUSH] Received remote notification")
        print("📋 [PUSH] User info: \(userInfo)")

        // Check if this is a CloudKit notification
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            logger.info("ℹ️ Not a CloudKit notification")
            print("ℹ️ [PUSH] Not a CloudKit notification")
            completionHandler(.noData)
            return
        }

        print("☁️ [PUSH] CloudKit notification detected")
        print("📋 [PUSH] Notification type: \(notification.notificationType.rawValue)")

        // Handle CloudKit query notification
        if let queryNotification = notification as? CKQueryNotification,
           let recordID = queryNotification.recordID {
            logger.info("📢 CloudKit query notification for record: \(recordID.recordName)")
            print("📢 [PUSH] CloudKit query notification for record: \(recordID.recordName)")
            print("📋 [PUSH] Record type: \(queryNotification.recordFields?["recordType"] as? String ?? "unknown")")

            Task {
                do {
                    try await CloudKitManager.shared.handlePurchaseNotification(recordID: recordID)
                    print("✅ [PUSH] Successfully handled notification")
                    completionHandler(.newData)
                } catch {
                    logger.error("❌ Failed to handle purchase notification: \(error.localizedDescription)")
                    print("❌ [PUSH] Failed to handle purchase notification: \(error.localizedDescription)")
                    completionHandler(.failed)
                }
            }
        } else {
            logger.info("ℹ️ Not a query notification or missing recordID")
            print("ℹ️ [PUSH] Not a query notification or missing recordID")
            completionHandler(.noData)
        }
    }
}
