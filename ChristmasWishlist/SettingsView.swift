//
//  SettingsView.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @ObservedObject private var firebase = FirebaseManager.shared
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("showPurchasedItems") private var showPurchasedItems = true
    @State private var showingPermissionAlert = false
    @State private var showingErrorAlert = false
    @State private var errorAlertMessage = ""
    @State private var showingSuccessAlert = false
    @State private var successAlertMessage = ""
    @State private var showingOnboarding = false
    @State private var showingDeleteAccountFirstConfirm = false
    @State private var showingDeleteAccountFinalConfirm = false

    var isActive: Bool = true

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamBackground
                    .ignoresSafeArea()

                Form {
                    Section {
                        NavigationLink {
                            ManageChildrenView()
                        } label: {
                            HStack {
                                Image(systemName: "figure.2.and.child.holdinghands")
                                    .foregroundColor(.forestGreen)
                                Text("Manage Children")
                                    .foregroundColor(.warmBlack)
                            }
                        }
                        .listRowBackground(Color.creamCard)
                    } header: {
                        Text("Profile")
                            .foregroundColor(.forestGreen)
                    } footer: {
                        Text("Your children's wish lists will be available when friends connect to you.")
                            .foregroundColor(.warmGray)
                            .font(.caption)
                    }

                    Section {
                        Toggle("Show purchased status", isOn: $showPurchasedItems)
                            .tint(.forestGreen)
                            .foregroundColor(.warmBlack)
                            .listRowBackground(Color.creamCard)
                    } header: {
                        Text("Secrecy")
                            .foregroundColor(.forestGreen)
                    } footer: {
                        Text("If on you'll know when your wish list items are purchased")
                            .foregroundColor(.warmGray)
                            .font(.caption)
                    }

                    Section {
                        Toggle("Purchase notifications", isOn: $notificationsEnabled)
                            .tint(.forestGreen)
                            .foregroundColor(.warmBlack)
                            .listRowBackground(Color.creamCard)
                            .onChange(of: notificationsEnabled) { oldValue, newValue in
                                // Always check/request permissions when toggled
                                requestNotificationPermissions(userToggledOn: newValue)
                            }
                    } footer: {
                        Text("Get notified when someone purchases from your wishlist")
                            .foregroundColor(.warmGray)
                            .font(.caption)
                    }

                    Section {
                        Button(action: {
                            HapticManager.buttonTapped()
                            rateApp()
                        }) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.gold)
                                Text("Rate App")
                                    .foregroundColor(.warmBlack)
                                Spacer()
                            }
                        }
                        .listRowBackground(Color.creamCard)

                        Button(action: sendBugReport) {
                            HStack {
                                Image(systemName: "ladybug.fill")
                                    .foregroundColor(.forestGreen)
                                Text("Report a Bug")
                                    .foregroundColor(.warmBlack)
                                Spacer()
                            }
                        }
                        .listRowBackground(Color.creamCard)

                        Button(action: requestFeature) {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.gold)
                                Text("Wish for new app feature")
                                    .foregroundColor(.warmBlack)
                                Spacer()
                            }
                        }
                        .listRowBackground(Color.creamCard)
                    } header: {
                        Text("Support")
                            .foregroundColor(.forestGreen)
                    }

                    // MARK: - Account
                    Section {
                        Button {
                            HapticManager.buttonTapped()
                            showingDeleteAccountFirstConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "person.fill.xmark")
                                    .foregroundColor(.forestGreen)
                                Text("Delete My Account")
                                    .foregroundColor(.warmBlack)
                                Spacer()
                            }
                        }
                        .disabled(!firebase.isAuthenticated)
                        .listRowBackground(Color.creamCard)
                    } header: {
                        Text("Account")
                            .foregroundColor(.forestGreen)
                    }

                    #if DEBUG
                    Section {
                        NavigationLink {
                            CloudKitDebugView()
                        } label: {
                            HStack {
                                Image(systemName: "ladybug.fill")
                                    .foregroundColor(.forestGreen)
                                Text("CloudKit Debug")
                                    .foregroundColor(.warmBlack)
                            }
                        }
                        .listRowBackground(Color.creamCard)
                    } header: {
                        Text("Developer Tools")
                            .foregroundColor(.forestGreen)
                    }
                    #endif

                    Section {
                        Link(destination: URL(string: "https://designoverhaul.com/privacy-policy-north-pole/")!) {
                            HStack {
                                Image(systemName: "hand.raised.fill")
                                    .foregroundColor(.forestGreen)
                                Text("Privacy Policy")
                                    .foregroundColor(.warmBlack)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundColor(.warmGray)
                            }
                        }
                        .listRowBackground(Color.creamCard)
                    } header: {
                        Text("Legal")
                        .foregroundColor(.forestGreen)
                    }

                    // App Version Footer
                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: 4) {
                                Text("North Pole v\(appVersion)")
                                    .font(.caption)
                                    .foregroundColor(.warmGray)
                                Text("Made with ❄️ for the holidays")
                                    .font(.caption)
                                    .foregroundColor(.warmGrayLight)
                            }
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("")
            .goldTitle("Settings")
            .alert("Notifications Disabled", isPresented: $showingPermissionAlert) {
                Button("Open Settings", role: .none) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {
                    notificationsEnabled = false
                }
            } message: {
                Text("Notification permissions were denied. Please enable them in Settings to receive purchase notifications.")
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorAlertMessage)
            }
            .alert("Success", isPresented: $showingSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(successAlertMessage)
            }
            .alert("Delete My Account?", isPresented: $showingDeleteAccountFirstConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Continue", role: .destructive) {
                    showingDeleteAccountFirstConfirm = false
                    showingDeleteAccountFinalConfirm = true
                }
            } message: {
                Text("This will delete all of your wishlists, children, purchases, and friends from iCloud for this app on your iCloud account. This cannot be undone.")
            }
            .alert("Delete My Account Data", isPresented: $showingDeleteAccountFinalConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete My Account", role: .destructive) {
                    Task {
                        await deleteAccountData()
                    }
                }
            } message: {
                Text("Are you sure? This action will permanently remove your data for this app from iCloud on this account. Other users’ data will not be affected.")
            }
            .fullScreenCover(isPresented: $showingOnboarding) {
                OnboardingView(isCompleted: $showingOnboarding)
            }
        }
    }

    // MARK: - Functions

    private func requestNotificationPermissions(userToggledOn: Bool) {
        Task {
            // First check current status
            let status = await NotificationManager.shared.checkAuthorizationStatus()

            if status == .notDetermined {
                // Never asked before - request now
                print("📱 [SETTINGS] Requesting notification permissions for first time...")
                let granted = await NotificationManager.shared.requestAuthorization()

                await MainActor.run {
                    if !granted {
                        // User denied - turn toggle back off
                        notificationsEnabled = false
                        showingPermissionAlert = true
                    } else {
                        print("✅ [SETTINGS] User granted notification permissions")
                    }
                }
            } else if status == .denied {
                // User previously denied - need to go to Settings
                print("⚠️ [SETTINGS] Notifications denied - need to enable in iOS Settings")
                await MainActor.run {
                    notificationsEnabled = false
                    showingPermissionAlert = true
                }
            } else if status == .authorized {
                // Already authorized - just update the preference
                print("✅ [SETTINGS] Notifications already authorized")
                await MainActor.run {
                    notificationsEnabled = userToggledOn
                }
            }
        }
    }

    private func rateApp() {
        // Direct link to App Store review page
        if let url = URL(string: "https://apps.apple.com/app/id6755366177?action=write-review") {
            UIApplication.shared.open(url)
        }
    }

    private func sendBugReport() {
        let email = "contact@designoverhaul.com"
        let subject = "North Pole - Bug Report"
        let body = """
        Please describe the bug you encountered:



        ---
        App Version: \(appVersion)
        Device: \(UIDevice.current.model)
        iOS Version: \(UIDevice.current.systemVersion)
        """

        if let url = URL(string: "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            UIApplication.shared.open(url)
        }
    }

    private func requestFeature() {
        let email = "contact@designoverhaul.com"
        let subject = "North Pole - Feature Request"
        let body = """
        Hi,

        This is a user-driven product and we value your feedback! What feature would you like to see?



        ---
        App Version: \(appVersion)
        Device: \(UIDevice.current.model)
        iOS Version: \(UIDevice.current.systemVersion)
        """

        if let url = URL(string: "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            UIApplication.shared.open(url)
        }
    }

    private func checkSubscriptions() {
        // TODO: Implement Firebase FCM subscription check
        errorAlertMessage = "Subscription checking not yet implemented with Firebase"
        showingErrorAlert = true
    }

    private func resubscribeToNotifications() {
        // TODO: Implement Firebase FCM resubscription
        errorAlertMessage = "Notification resubscription not yet implemented with Firebase"
        showingErrorAlert = true
    }

    private func testLocalNotification() {
        Task {
            print("🧪 [TEST] Triggering test notification...")
            await NotificationManager.shared.sendItemPurchasedNotification(
                itemName: "Test Item",
                friendName: "Test Friend"
            )
            await MainActor.run {
                successAlertMessage = "Test notification sent! If you don't see a notification banner, check Settings → Notifications → Listmas and ensure notifications are enabled."
                showingSuccessAlert = true
            }
        }
    }

    private func cleanLocalDatabase() {
        Task { @MainActor in
            print("🧹 [CLEAN] User requested database clean")

            do {
                let context = ChristmasWishlistApp.sharedModelContainer.mainContext

                // Delete all wishlist items
                let itemsDescriptor = FetchDescriptor<WishlistItem>()
                let items = try context.fetch(itemsDescriptor)
                for item in items {
                    context.delete(item)
                }
                print("🧹 [CLEAN] Deleted \(items.count) wishlist items")

                // Delete all children
                let childrenDescriptor = FetchDescriptor<Child>()
                let children = try context.fetch(childrenDescriptor)
                for child in children {
                    context.delete(child)
                }
                print("🧹 [CLEAN] Deleted \(children.count) children")

                // Delete all friends
                let friendsDescriptor = FetchDescriptor<Friend>()
                let friends = try context.fetch(friendsDescriptor)
                for friend in friends {
                    context.delete(friend)
                }
                print("🧹 [CLEAN] Deleted \(friends.count) friends")

                try context.save()
                print("✅ [CLEAN] Database cleaned successfully")

                // Reset migration flag so it runs again
                UserDefaults.standard.set(false, forKey: "hasRunCloudKitMigration_v1")
                print("✅ [CLEAN] Reset migration flag")

                successAlertMessage = "Local database cleaned! Deleted \(items.count) items, \(children.count) children, and \(friends.count) friends.\n\nRestart the app to re-download from CloudKit."
                showingSuccessAlert = true

                HapticManager.notification(.success)
            } catch {
                print("❌ [CLEAN] Failed to clean database: \(error)")
                errorAlertMessage = "Failed to clean database: \(error.localizedDescription)"
                showingErrorAlert = true
                HapticManager.errorOccurred()
            }
        }
    }

    private func cleanCloudKitDuplicates() {
        // CloudKit duplicate cleaning no longer needed
        errorAlertMessage = "This feature was for CloudKit and is no longer needed with Firebase"
        showingErrorAlert = true
    }

    private func deleteAccountData() async {
        print("🧨 [SETTINGS] User confirmed delete account")

        guard firebase.isAuthenticated else {
            await MainActor.run {
                errorAlertMessage = "Not signed in to Firebase. Please sign in before deleting your account data."
                showingErrorAlert = true
            }
            return
        }

        do {
            // TODO: Implement Firebase account deletion
            // This should delete all user data from Firestore
            await MainActor.run {
                errorAlertMessage = "Account deletion not yet implemented with Firebase"
                showingErrorAlert = true
            }
        } catch {
            await MainActor.run {
                errorAlertMessage = "Failed to delete account data: \(error.localizedDescription)"
                showingErrorAlert = true
                HapticManager.errorOccurred()
            }
        }
    }

}

// Helper extension for batching arrays
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

#Preview {
    SettingsView()
}
