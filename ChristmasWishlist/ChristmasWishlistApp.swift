//
//  ChristmasWishlistApp.swift
//  ChristmasWishlist
//
//  Created by Aaron Heine on 11/16/25.
//

import SwiftUI
import SwiftData
import OSLog
import Combine
import FirebaseCore
import FirebaseMessaging
import FirebaseAuth
import UserNotifications
import UIKit

private let logger = Logger(subsystem: "com.designoverhaul.ChristmasWishlist", category: "App")

@main
struct ChristmasWishlistApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        let _ = print("🎄 [APP] Body evaluated - hasCompletedOnboarding = \(hasCompletedOnboarding)")

        return WindowGroup {
            RootView()
        }
        .modelContainer(Self.sharedModelContainer)
    }
    
    static var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Friend.self,
            Child.self,
            WishlistItem.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            container.mainContext.autosaveEnabled = true
            print("✅ [APP] ModelContainer initialized successfully")
            return container
        } catch {
            print("❌ [APP] Failed to initialize ModelContainer: \(error)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext
    @StateObject private var deepLinkManager = DeepLinkManager.shared
    @StateObject private var firebaseAuth = FirebaseAuthManager.shared

    var body: some View {
        Group {
            // Check Firebase authentication first
            if !firebaseAuth.isAuthenticated {
                // User not signed in - show phone auth
                PhoneAuthView()
                    .preferredColorScheme(.light)
                    .onAppear {
                        print("🔥 [APP] PhoneAuthView appeared - user not authenticated")
                    }
            } else if hasCompletedOnboarding {
                // User signed in and onboarding complete - show main app
                MainTabView()
                    .preferredColorScheme(.light)
                    .task {
                        // Ensure user document exists in Firestore (in case it wasn't created during onboarding)
                        let firebase = FirebaseManager.shared
                        do {
                            let displayName = "User" // Default name
                            try await firebase.createOrUpdateUser(displayName: displayName)
                            logger.info("✅ [APP] User document verified/created in Firestore")
                        } catch {
                            logger.warning("⚠️ [APP] Failed to ensure user document exists: \(error)")
                        }
                    }
                    .onAppear {
                        print("🎄 [APP] ✅ MainTabView appeared - SUCCESS!")
                    }
            } else {
                // User signed in but onboarding not complete
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
        .onChange(of: firebaseAuth.isAuthenticated) { oldValue, newValue in
            print("🔥 [APP] ⚡ isAuthenticated changed from \(oldValue) to \(newValue)")
        }
        .onOpenURL { url in
            // Handle Firebase Auth URLs first
            if Auth.auth().canHandle(url) {
                print("🔗 [DEEPLINK] Firebase Auth URL handled")
                return
            }
            
            // Handle other deep links (like friend invites)
            deepLinkManager.handle(url: url, modelContext: modelContext)
        }
        .alert("Add Friend?", isPresented: $deepLinkManager.showAddConfirmation) {
            Button("Cancel", role: .cancel) {
                deepLinkManager.showAddConfirmation = false
            }
            Button("Add Friend") {
                deepLinkManager.confirmAddFriend(modelContext: modelContext)
            }
        } message: {
            if let name = deepLinkManager.pendingFriendName {
                Text("Do you want to add \(name) to your friends list?")
            }
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Initialize Firebase FIRST, before anything else
        FirebaseApp.configure()
        logger.info("🔥 [FIREBASE] Firebase initialized")
        
        // Set up Firebase Messaging delegate
        Messaging.messaging().delegate = self
        
        // Set up notification center delegate
        UNUserNotificationCenter.current().delegate = self
        
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

        return true
    }
    
    // Handle URL schemes for Firebase Phone Authentication
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        logger.info("🔗 [APPDELEGATE] Handling URL: \(url.absoluteString)")
        
        // Handle Firebase Phone Auth URL first
        if Auth.auth().canHandle(url) {
            logger.info("✅ [APPDELEGATE] Firebase Auth handled the URL")
            return true
        }
        
        // Handle other URL schemes (like deep links)
        logger.info("ℹ️ [APPDELEGATE] URL not handled by Firebase Auth, passing to SwiftUI")
        return false
    }
    
    // MARK: - Remote Notifications for Firebase Phone Auth
    
    // Register device token with Firebase
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        logger.info("📱 [NOTIFICATIONS] Device token registered")
        
        // Forward to Firebase Auth for Phone Authentication
        // Use .prod for production, .sandbox for development
        #if DEBUG
        Auth.auth().setAPNSToken(deviceToken, type: .sandbox)
        #else
        Auth.auth().setAPNSToken(deviceToken, type: .prod)
        #endif
        
        // Also forward to Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
    }
    
    // Handle registration failure
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        logger.error("❌ [NOTIFICATIONS] Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    // Handle incoming remote notifications
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        logger.info("📱 [NOTIFICATIONS] Received remote notification")
        
        // Forward to Firebase Auth for Phone Authentication first
        if Auth.auth().canHandleNotification(userInfo) {
            logger.info("📱 [NOTIFICATIONS] Handled by Firebase Auth")
            completionHandler(.noData)
            return
        }
        
        // Forward to Firebase Messaging
        Messaging.messaging().appDidReceiveMessage(userInfo)
        logger.info("📱 [NOTIFICATIONS] Handled by Firebase Messaging")
        
        completionHandler(.newData)
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        logger.info("📱 [NOTIFICATIONS] Will present notification")
        
        // Check if Firebase Auth can handle it
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler([])
            return
        }
        
        // Show notification for other types
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        logger.info("📱 [NOTIFICATIONS] Did receive notification response")
        
        // Check if Firebase Auth can handle it
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler()
            return
        }
        
        completionHandler()
    }
    
    // MARK: - MessagingDelegate
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        logger.info("📱 [FCM] FCM registration token: \(fcmToken ?? "nil")")
        
        // You can send this token to your server if needed
        if let token = fcmToken {
            UserDefaults.standard.set(token, forKey: "fcmToken")
        }
    }

}
