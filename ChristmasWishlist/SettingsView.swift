//
//  SettingsView.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData
import CloudKit

struct SettingsView: View {
    @ObservedObject private var cloudKit = CloudKitManager.shared
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
                        .disabled(!cloudKit.isSignedInToiCloud)
                        .listRowBackground(Color.creamCard)
                    } header: {
                        Text("Account")
                            .foregroundColor(.forestGreen)
                    }

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
        Task {
            print("🧹 [CLOUDKIT_CLEAN] User requested CloudKit duplicate removal")

            guard cloudKit.isSignedInToiCloud else {
                await MainActor.run {
                    errorAlertMessage = "Not signed in to iCloud. Please sign in to clean CloudKit duplicates."
                    showingErrorAlert = true
                }
                return
            }

            do {
                // Fetch ALL wishlist items from CloudKit
                let allRecords = try await cloudKit.fetchMyWishlistItems()
                print("🧹 [CLOUDKIT_CLEAN] Fetched \(allRecords.count) total items from CloudKit")

                // Group by unique key: name + ownerID
                var itemGroups: [String: [CKRecord]] = [:]

                for record in allRecords {
                    let itemName = record["name"] as? String ?? "Unknown"
                    let ownerRef = record["ownerID"] as? CKRecord.Reference
                    let ownerID = ownerRef?.recordID.recordName ?? "no_owner"

                    let uniqueKey = "\(itemName)_\(ownerID)"

                    if itemGroups[uniqueKey] == nil {
                        itemGroups[uniqueKey] = []
                    }
                    itemGroups[uniqueKey]?.append(record)
                }

                // Find duplicates (groups with more than 1 record)
                var recordsToDelete: [CKRecord.ID] = []
                var totalDuplicates = 0

                for (key, records) in itemGroups {
                    if records.count > 1 {
                        // Sort by creation date (keep the most recent)
                        let sortedRecords = records.sorted { r1, r2 in
                            let date1 = r1.creationDate ?? Date.distantPast
                            let date2 = r2.creationDate ?? Date.distantPast
                            return date1 > date2 // Most recent first
                        }

                        // Keep the first (most recent), delete the rest
                        let duplicates = Array(sortedRecords.dropFirst())
                        for duplicate in duplicates {
                            recordsToDelete.append(duplicate.recordID)
                        }

                        totalDuplicates += duplicates.count
                        print("🧹 [CLOUDKIT_CLEAN] Found \(records.count) copies of '\(key)' - will delete \(duplicates.count) duplicates")
                    }
                }

                print("🧹 [CLOUDKIT_CLEAN] Total duplicates to delete: \(totalDuplicates)")

                if recordsToDelete.isEmpty {
                    await MainActor.run {
                        successAlertMessage = "No duplicates found! Your CloudKit database is clean."
                        showingSuccessAlert = true
                        HapticManager.notification(.success)
                    }
                    return
                }

                // Delete duplicates from CloudKit in batches (CloudKit limit is 400 per operation)
                let batchSize = 400
                var deletedCount = 0

                for batch in recordsToDelete.chunked(into: batchSize) {
                    let database = CKContainer.default().privateCloudDatabase
                    let deleteOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: batch)

                    deleteOperation.modifyRecordsResultBlock = { result in
                        switch result {
                        case .success:
                            deletedCount += batch.count
                            print("✅ [CLOUDKIT_CLEAN] Deleted batch of \(batch.count) duplicates")
                        case .failure(let error):
                            print("❌ [CLOUDKIT_CLEAN] Failed to delete batch: \(error)")
                        }
                    }

                    database.add(deleteOperation)

                    // Wait for operation to complete
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay between batches
                }

                print("✅ [CLOUDKIT_CLEAN] Deleted \(deletedCount) duplicate items from CloudKit")

                await MainActor.run {
                    successAlertMessage = "Successfully removed \(deletedCount) duplicate items from CloudKit!\n\nTotal items before: \(allRecords.count)\nDuplicates removed: \(deletedCount)\nUnique items remaining: \(itemGroups.count)"
                    showingSuccessAlert = true
                    HapticManager.notification(.success)
                }

            } catch {
                print("❌ [CLOUDKIT_CLEAN] Failed to clean CloudKit: \(error)")
                await MainActor.run {
                    errorAlertMessage = "Failed to clean CloudKit duplicates: \(error.localizedDescription)"
                    showingErrorAlert = true
                    HapticManager.errorOccurred()
                }
            }
        }
    }

    private func deleteAccountData() async {
        print("🧨 [SETTINGS] User confirmed delete account")

        guard cloudKit.isSignedInToiCloud else {
            errorAlertMessage = "Not signed in to iCloud. Please sign in before deleting your account data."
            showingErrorAlert = true
            return
        }

        do {
            try await cloudKit.wipeCurrentUserData()
            await MainActor.run {
                successAlertMessage = "Your account data for this app has been deleted from iCloud for this Apple ID. You can now start fresh by adding children and wishlist items again."
                showingSuccessAlert = true
                HapticManager.notification(.success)
            }
        } catch let ckError as CKError {
            await MainActor.run {
                errorAlertMessage = ckError.userFriendlyMessage
                showingErrorAlert = true
                HapticManager.errorOccurred()
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
