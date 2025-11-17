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
    @AppStorage("userName") private var name = ""
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("showPurchasedItems") private var showPurchasedItems = true
    @State private var showingPermissionAlert = false
    @State private var isSavingName = false
    @State private var hasLoadedName = false
    @State private var showingDemoDataAlert = false
    @State private var showingLoadDemoDataAlert = false
    @State private var showingErrorAlert = false
    @State private var errorAlertMessage = ""
    @State private var showingSuccessAlert = false
    @State private var successAlertMessage = ""
    @FocusState private var nameFieldFocused: Bool

    var isActive: Bool = true

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamBackground
                    .ignoresSafeArea()
                    .onTapGesture {
                        nameFieldFocused = false
                    }

                Form {
                    Section {
                        HStack {
                            Text("Name")
                                .foregroundColor(.warmBlack)
                            Spacer()
                            TextField("Your name", text: $name)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(.warmBlack)
                                .focused($nameFieldFocused)
                                .submitLabel(.done)
                                .onSubmit {
                                    nameFieldFocused = false
                                }
                                .onChange(of: name) { oldValue, newValue in
                                    saveNameToCloudKit(newValue)
                                }
                            if isSavingName {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .listRowBackground(Color.creamCard)

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
                                if newValue {
                                    requestNotificationPermissions()
                                }
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
                        Button(action: rateApp) {
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
                        NavigationLink {
                            ImportLogsView()
                        } label: {
                            HStack {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .foregroundColor(.forestGreen)
                                Text("Import Logs")
                                    .foregroundColor(.warmBlack)
                            }
                        }
                        .listRowBackground(Color.creamCard)

                        Button(action: { showingLoadDemoDataAlert = true }) {
                            HStack {
                                Image(systemName: "person.3.fill")
                                    .foregroundColor(.gold)
                                Text("Load Demo Data")
                                    .foregroundColor(.warmBlack)
                                Spacer()
                            }
                        }
                        .listRowBackground(Color.creamCard)

                        Button(action: { showingDemoDataAlert = true }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(.red)
                                Text("Clear All Data")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                        .listRowBackground(Color.creamCard)
                    } header: {
                        Text("Debugging")
                            .foregroundColor(.forestGreen)
                    } footer: {
                        Text("Load sample friends and wishlists for testing. Clear all data will delete everything.")
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
            .alert("Clear All Data?", isPresented: $showingDemoDataAlert) {
                Button("Delete Everything", role: .destructive) {
                    clearAllData()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all friends, wishlists, and children. This action cannot be undone.")
            }
            .alert("Load Demo Data?", isPresented: $showingLoadDemoDataAlert) {
                Button("Load Demo Data", role: .none) {
                    loadDemoData()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will create sample friends and wishlists for testing. If you've already loaded demo data, this will create duplicates. Consider clearing all data first.")
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
            .onChange(of: isActive) { _, active in
                if active && !hasLoadedName && cloudKit.isSignedInToiCloud {
                    loadNameFromCloudKit()
                    hasLoadedName = true
                }
            }
            .onChange(of: cloudKit.isSignedInToiCloud) { _, isSignedIn in
                // Load user name immediately when CloudKit is ready
                if isSignedIn && !hasLoadedName {
                    loadNameFromCloudKit()
                    hasLoadedName = true
                }
            }
        }
    }

    // MARK: - Functions

    private func loadNameFromCloudKit() {
        guard cloudKit.isSignedInToiCloud else { return }

        Task {
            do {
                if let cloudName = try await cloudKit.fetchUserProfile() {
                    name = cloudName
                }
            } catch {
                print("❌ Error loading user profile: \(error)")
            }
        }
    }

    private func saveNameToCloudKit(_ newName: String) {
        guard cloudKit.isSignedInToiCloud else { return }
        guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isSavingName = true

        Task {
            do {
                try await cloudKit.saveUserProfile(name: newName.trimmingCharacters(in: .whitespacesAndNewlines))
                isSavingName = false
            } catch {
                print("❌ Error saving user profile: \(error)")
                isSavingName = false
            }
        }
    }

    private func requestNotificationPermissions() {
        Task {
            let granted = await NotificationManager.shared.requestAuthorization()
            if !granted {
                await MainActor.run {
                    showingPermissionAlert = true
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

    private func loadDemoData() {
        Task {
            do {
                try await CloudKitDemoDataGenerator.generateDemoData()
                await MainActor.run {
                    HapticManager.itemAdded()
                    successAlertMessage = "Demo data loaded successfully! Go to the Friends tab to see Sarah and her children's wishlists."
                    showingSuccessAlert = true
                }
            } catch let ckError as CKError {
                print("❌ Error loading demo data: \(ckError)")
                await MainActor.run {
                    HapticManager.errorOccurred()
                    errorAlertMessage = ckError.userFriendlyMessage
                    showingErrorAlert = true
                }
            } catch CloudKitError.notSignedIn {
                print("❌ Error loading demo data: Not signed in")
                await MainActor.run {
                    HapticManager.errorOccurred()
                    errorAlertMessage = "Please sign in to iCloud in Settings to use this feature."
                    showingErrorAlert = true
                }
            } catch {
                print("❌ Error loading demo data: \(error)")
                await MainActor.run {
                    HapticManager.errorOccurred()
                    errorAlertMessage = "Failed to load demo data: \(error.localizedDescription)"
                    showingErrorAlert = true
                }
            }
        }
    }

    private func clearAllData() {
        Task {
            do {
                try await CloudKitDemoDataGenerator.clearAllData()
                await MainActor.run {
                    HapticManager.buttonTapped()
                    successAlertMessage = "All data has been cleared successfully."
                    showingSuccessAlert = true
                }
            } catch let ckError as CKError {
                print("❌ Error clearing data: \(ckError)")
                await MainActor.run {
                    HapticManager.errorOccurred()
                    errorAlertMessage = ckError.userFriendlyMessage
                    showingErrorAlert = true
                }
            } catch CloudKitError.notSignedIn {
                print("❌ Error clearing data: Not signed in")
                await MainActor.run {
                    HapticManager.errorOccurred()
                    errorAlertMessage = "Please sign in to iCloud in Settings to use this feature."
                    showingErrorAlert = true
                }
            } catch {
                print("❌ Error clearing data: \(error)")
                await MainActor.run {
                    HapticManager.errorOccurred()
                    errorAlertMessage = "Failed to clear data: \(error.localizedDescription)"
                    showingErrorAlert = true
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
