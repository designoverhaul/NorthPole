//
//  ChristmasWishlistApp.swift
//  ChristmasWishlist
//
//  Created by Aaron Heine on 11/16/25.
//

import SwiftUI
import CloudKit
import OSLog

private let logger = Logger(subsystem: "com.designoverhaul.ChristmasWishlist", category: "App")

@main
struct ChristmasWishlistApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                MainTabView()
                    .preferredColorScheme(.light) // Force light mode only
            } else {
                OnboardingView(isCompleted: $hasCompletedOnboarding)
                    .preferredColorScheme(.light) // Force light mode only
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
        logger.info("Registered for remote notifications")
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        logger.error("Failed to register for remote notifications: \(error.localizedDescription)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        logger.info("Received remote notification")

        // Check if this is a CloudKit notification
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            completionHandler(.noData)
            return
        }

        // Handle CloudKit query notification
        if let queryNotification = notification as? CKQueryNotification,
           let recordID = queryNotification.recordID {
            logger.info("CloudKit query notification for record: \(recordID.recordName)")

            Task {
                do {
                    try await CloudKitManager.shared.handlePurchaseNotification(recordID: recordID)
                    completionHandler(.newData)
                } catch {
                    logger.error("Failed to handle purchase notification: \(error.localizedDescription)")
                    completionHandler(.failed)
                }
            }
        } else {
            completionHandler(.noData)
        }
    }
}
