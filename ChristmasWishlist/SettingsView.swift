//
//  SettingsView.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI
import CloudKit

struct SettingsView: View {
    @StateObject private var cloudKit = CloudKitManager.shared
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("showPurchasedItems") private var showPurchasedItems = true
    @State private var showingPermissionAlert = false
    @State private var showingErrorAlert = false
    @State private var errorAlertMessage = ""
    @State private var showingSuccessAlert = false
    @State private var successAlertMessage = ""
    @State private var showingOnboarding = false

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
                        Toggle("Show checked-off items", isOn: $showPurchasedItems)
                            .tint(.forestGreen)
                            .foregroundColor(.warmBlack)
                            .listRowBackground(Color.creamCard)

                        Toggle("Purchase notifications", isOn: $notificationsEnabled)
                            .tint(.forestGreen)
                            .foregroundColor(.warmBlack)
                            .listRowBackground(Color.creamCard)
                            .onChange(of: notificationsEnabled) { oldValue, newValue in
                                // Always check/request permissions when toggled
                                requestNotificationPermissions(userToggledOn: newValue)
                            }
                    } header: {
                        Text("Secrecy")
                            .foregroundColor(.forestGreen)
                    } footer: {
                        Text("Get notified when a friend checks items off your list. Choose whether to see which items have been marked as purchased. Turn off to keep it a complete surprise!")
                            .foregroundColor(.warmGray)
                            .font(.caption)
                    }

                    Section {
                        Button(action: {
                            HapticManager.buttonTapped()
                            ReviewManager.shared.requestReviewManually()
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

                    Section {
                        Button(action: { showingOnboarding = true }) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                    .foregroundColor(.gold)
                                Text("View Onboarding Tutorial")
                                    .foregroundColor(.warmBlack)
                                Spacer()
                            }
                        }
                        .listRowBackground(Color.creamCard)

                        Button(action: checkSubscriptions) {
                            HStack {
                                Image(systemName: "bell.badge.fill")
                                    .foregroundColor(.forestGreen)
                                Text("Check Notification Subscriptions")
                                    .foregroundColor(.warmBlack)
                                Spacer()
                            }
                        }
                        .listRowBackground(Color.creamCard)

                        Button(action: resubscribeToNotifications) {
                            HStack {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .foregroundColor(.gold)
                                Text("Reset Notification Subscriptions")
                                    .foregroundColor(.warmBlack)
                                Spacer()
                            }
                        }
                        .listRowBackground(Color.creamCard)

                        Button(action: testLocalNotification) {
                            HStack {
                                Image(systemName: "bell.fill")
                                    .foregroundColor(.gold)
                                Text("Test Local Notification")
                                    .foregroundColor(.warmBlack)
                                Spacer()
                            }
                        }
                        .listRowBackground(Color.creamCard)
                    } header: {
                        Text("Developer")
                            .foregroundColor(.forestGreen)
                    } footer: {
                        Text("View the onboarding tutorial again for testing purposes. Check or reset CloudKit notification subscriptions if you're not receiving purchase notifications.")
                            .foregroundColor(.warmGray)
                            .font(.caption)
                    }

                    Section {
                        Link(destination: URL(string: "https://designoverhaul.com/wishlist-privacy-policy/")!) {
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
                                Text("Christmas Wishlist v\(appVersion)")
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
        let subject = "Christmas Wishlist - Bug Report"
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
        let subject = "Christmas Wishlist - Feature Request"
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
        Task {
            do {
                let subscriptions = try await cloudKit.fetchAllSubscriptions()
                await MainActor.run {
                    if subscriptions.isEmpty {
                        errorAlertMessage = "No active CloudKit subscriptions found. This might be why you're not receiving notifications. Try 'Reset Notification Subscriptions'."
                        showingErrorAlert = true
                    } else {
                        let subscriptionList = subscriptions.map { "• \($0.subscriptionID)" }.joined(separator: "\n")
                        successAlertMessage = "Found \(subscriptions.count) active subscription(s):\n\n\(subscriptionList)"
                        showingSuccessAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    errorAlertMessage = "Failed to check subscriptions: \(error.localizedDescription)"
                    showingErrorAlert = true
                }
            }
        }
    }

    private func resubscribeToNotifications() {
        Task {
            do {
                try await cloudKit.resubscribeToAll()
                await MainActor.run {
                    successAlertMessage = "Successfully reset notification subscriptions! You should now receive notifications when friends purchase your items."
                    showingSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    errorAlertMessage = "Failed to reset subscriptions: \(error.localizedDescription)"
                    showingErrorAlert = true
                }
            }
        }
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

}

#Preview {
    SettingsView()
}
