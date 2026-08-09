//
//  SettingsView.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var firebase = FirebaseManager.shared
    @ObservedObject private var superwall = SuperwallManager.shared
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("showPurchasedItems") private var showPurchasedItems = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    /// Mirrors the stored settings so a switch the paywall denied can animate back off.
    @State private var showPurchasedToggle = false
    @State private var notificationsToggle = false
    @State private var showingPermissionAlert = false
    @State private var showingErrorAlert = false
    @State private var errorAlertMessage = ""
    @State private var showingSuccessAlert = false
    @State private var successAlertMessage = ""
    @State private var showingDeleteAccountFirstConfirm = false
    @State private var showingDeleteAccountFinalConfirm = false
    @State private var isDeletingAccount = false

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
                            SettingsRow(
                                icon: "figure.and.child.holdinghands",
                                title: "Manage Children",
                                subtitle: "Kids without a phone"
                            )
                        }
                        .listRowBackground(Color.creamCard)
                    } header: {
                        SettingsSectionHeader("Profile")
                    } footer: {
                        SettingsSectionFooter("Add kids who don't have their own phone. Their wish lists will be available when friends connect to you.")
                    }

                    Section {
                        if superwall.isSubscribed {
                            SettingsRow(
                                icon: "checkmark.seal.fill",
                                iconColor: .gold,
                                title: "Unlimited gifts",
                                subtitle: "Thanks for supporting North Pole"
                            )
                            .listRowBackground(Color.creamCard)
                        } else {
                            Button {
                                HapticManager.buttonTapped()
                                superwall.presentUpgrade()
                            } label: {
                                SettingsRow(
                                    icon: "sparkles",
                                    iconColor: .gold,
                                    title: "Unlock unlimited gifts",
                                    subtitle: "Every list is capped at \(SuperwallManager.freeGiftsPerPerson) gifts for now",
                                    accessory: .chevron
                                )
                            }
                            .listRowBackground(Color.creamCard)
                        }
                    } header: {
                        SettingsSectionHeader("Membership")
                    }

                    Section {
                        Toggle(isOn: $showPurchasedToggle) {
                            SettingsRow(icon: "eye", title: "Show purchased status")
                        }
                        .tint(.forestGreen)
                        .listRowBackground(Color.creamCard)
                        .onChange(of: showPurchasedToggle) { _, newValue in
                            setShowPurchasedItems(newValue)
                        }

                        Toggle(isOn: $notificationsToggle) {
                            SettingsRow(icon: "bell.fill", title: "Purchase notifications")
                        }
                        .tint(.forestGreen)
                        .listRowBackground(Color.creamCard)
                        .onChange(of: notificationsToggle) { _, newValue in
                            setNotificationsEnabled(newValue)
                        }
                    } header: {
                        SettingsSectionHeader("Secrecy")
                    } footer: {
                        SettingsSectionFooter(
                            "If on, you'll see when your wishlist items have been purchased.",
                            "Get notified when someone purchases from your wishlist."
                        )
                    }

                    Section {
                        Button {
                            HapticManager.buttonTapped()
                            rateApp()
                        } label: {
                            SettingsRow(icon: "star.fill", iconColor: .gold, title: "Rate App")
                        }
                        .listRowBackground(Color.creamCard)

                        Button(action: sendBugReport) {
                            SettingsRow(icon: "ladybug.fill", title: "Report a Bug")
                        }
                        .listRowBackground(Color.creamCard)

                        Button(action: requestFeature) {
                            SettingsRow(icon: "lightbulb.fill", iconColor: .gold, title: "Wish for new app feature")
                        }
                        .listRowBackground(Color.creamCard)
                    } header: {
                        SettingsSectionHeader("Support")
                    }

                    // MARK: - Account
                    Section {
                        Button {
                            HapticManager.buttonTapped()
                            showingDeleteAccountFirstConfirm = true
                        } label: {
                            SettingsRow(icon: "person.fill.xmark", title: "Delete My Account")
                        }
                        .disabled(!firebase.isAuthenticated)
                        .listRowBackground(Color.creamCard)
                    } header: {
                        SettingsSectionHeader("Account")
                    }

                    // Shown for Xcode / development installs only — not App Store or TestFlight.
                    // Do not gate this on `#if DEBUG`: Run was historically Release on device, which
                    // compiled the whole section out of every phone install.
                    if DeveloperTools.isAvailable {
                        Section {
                            // Reads the live status so a real purchase (or the paywall) moves it too.
                            Toggle(isOn: Binding(
                                get: { superwall.isSubscribed },
                                set: { superwall.setDebugSubscribed($0) }
                            )) {
                                SettingsRow(
                                    icon: "crown.fill",
                                    iconColor: .gold,
                                    verbatim: "Force Subscriber Status"
                                )
                            }
                            .tint(.forestGreen)
                            .listRowBackground(Color.creamCard)

                            Button(action: restartOnboarding) {
                                SettingsRow(icon: "arrow.counterclockwise", verbatim: "Restart Onboarding")
                            }
                            .listRowBackground(Color.creamCard)

                            Button(action: cleanLocalDatabase) {
                                SettingsRow(icon: "trash", iconColor: .warmGray, verbatim: "Reset Local Cache")
                            }
                            .listRowBackground(Color.creamCard)

                            NavigationLink {
                                ImportLogsView()
                            } label: {
                                SettingsRow(icon: "doc.text.magnifyingglass", verbatim: "Import Logs")
                            }
                            .listRowBackground(Color.creamCard)
                        } header: {
                            SettingsSectionHeader(verbatim: "Developer Tools")
                        }
                    }

                    Section {
                        Link(destination: URL(string: "https://designoverhaul.com/privacy-policy-north-pole/")!) {
                            SettingsRow(
                                icon: "hand.raised.fill",
                                title: "Privacy Policy",
                                accessory: .externalLink
                            )
                        }
                        .listRowBackground(Color.creamCard)
                    } header: {
                        SettingsSectionHeader("Legal")
                    }

                    // App Version Footer
                    Section {
                        VStack(spacing: Spacing.xs) {
                            Text("North Pole v\(appVersion)")
                                .font(.caption)
                                .foregroundColor(.warmGray)
                            Text("Made with ❄️ in Atlanta")
                                .font(.caption)
                                .foregroundColor(.warmGrayLight)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, Spacing.sm)
                        .listRowBackground(Color.clear)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("")
            .goldTitle("Settings")
            .onAppear {
                showPurchasedToggle = showPurchasedItems
                notificationsToggle = notificationsEnabled
            }
            .onChange(of: showPurchasedItems) { _, newValue in
                showPurchasedToggle = newValue
            }
            .onChange(of: notificationsEnabled) { _, newValue in
                notificationsToggle = newValue
            }
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
                Text("This will permanently delete your wishlists, children, purchases, friends, and account from North Pole. This cannot be undone.")
            }
            .alert("Delete My Account Data", isPresented: $showingDeleteAccountFinalConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete My Account", role: .destructive) {
                    Task {
                        await deleteAccountData()
                    }
                }
            } message: {
                Text("Are you sure? This permanently removes your North Pole data. Other users’ data will not be affected.")
            }
        }
    }

    // MARK: - Functions

    /// Both spoiler settings only turn on if the paywall lets them, so the switch is driven
    /// through Superwall and mirrors the stored value again once it has decided.
    private func setShowPurchasedItems(_ isOn: Bool) {
        guard isOn != showPurchasedItems else { return }

        guard isOn else {
            showPurchasedItems = false
            return
        }

        superwall.requestRevealPurchases(feature: .showPurchasedStatus) {
            showPurchasedItems = true
        } didResolve: {
            showPurchasedToggle = showPurchasedItems
        }
    }

    private func setNotificationsEnabled(_ isOn: Bool) {
        guard isOn != notificationsEnabled else { return }

        guard isOn else {
            notificationsEnabled = false
            syncNotificationSetting()
            return
        }

        superwall.requestRevealPurchases(feature: .purchaseNotifications) {
            notificationsEnabled = true
            requestNotificationPermissions()
        } didResolve: {
            notificationsToggle = notificationsEnabled
        }
    }

    /// Makes sure iOS will actually deliver notifications, turning the setting back off if not.
    private func requestNotificationPermissions() {
        Task { @MainActor in
            let status = await NotificationManager.shared.checkAuthorizationStatus()

            switch status {
            case .notDetermined:
                print("📱 [SETTINGS] Requesting notification permissions for first time...")
                let granted = await NotificationManager.shared.requestAuthorization()
                if granted {
                    print("✅ [SETTINGS] User granted notification permissions")
                } else {
                    notificationsEnabled = false
                    showingPermissionAlert = true
                }
            case .denied:
                print("⚠️ [SETTINGS] Notifications denied - need to enable in iOS Settings")
                notificationsEnabled = false
                showingPermissionAlert = true
            default:
                print("✅ [SETTINGS] Notifications already authorized")
            }

            syncNotificationSetting()
        }
    }

    /// Mirrors the preference to Firestore so Cloud Functions know whether to push.
    private func syncNotificationSetting() {
        let enabled = notificationsEnabled
        Task {
            do {
                try await FirebaseManager.shared.updateNotificationSetting(enabled)
                print("✅ [SETTINGS] Notification preference synced to Firestore: \(enabled)")
            } catch {
                print("⚠️ [SETTINGS] Failed to sync notification preference: \(error.localizedDescription)")
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
        let subject = String(localized: "North Pole - Bug Report")
        let body = String(localized: """
        Please describe the bug you encountered:



        ---
        App Version: \(appVersion)
        Device: \(UIDevice.current.model)
        iOS Version: \(UIDevice.current.systemVersion)
        """)

        if let url = URL(string: "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            UIApplication.shared.open(url)
        }
    }

    private func requestFeature() {
        let email = "contact@designoverhaul.com"
        let subject = String(localized: "North Pole - Feature Request")
        let body = String(localized: """
        Hi,

        This is a user-driven product and we value your feedback! What feature would you like to see?



        ---
        App Version: \(appVersion)
        Device: \(UIDevice.current.model)
        iOS Version: \(UIDevice.current.systemVersion)
        """)

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

    /// Sends the app back to the onboarding flow. `RootView` observes the same
    /// `hasCompletedOnboarding` key, so clearing it swaps the root view out.
    private func restartOnboarding() {
        HapticManager.buttonTapped()
        print("🎄 [SETTINGS] Restarting onboarding")
        hasCompletedOnboarding = false
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

                successAlertMessage = "Local cache cleaned. Restart the app to re-download from Firebase."
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
                errorAlertMessage = String(localized: "Not signed in. Please sign in before deleting your account.")
                showingErrorAlert = true
            }
            return
        }

        await MainActor.run { isDeletingAccount = true }

        do {
            try await firebase.deleteAllAccountData(context: modelContext)
            await MainActor.run {
                isDeletingAccount = false
                hasCompletedOnboarding = false
                successAlertMessage = String(localized: "Your account and data were deleted.")
                showingSuccessAlert = true
                HapticManager.notification(.success)
            }
        } catch {
            await MainActor.run {
                isDeletingAccount = false
                errorAlertMessage = String(localized: "Failed to delete account data: \(error.localizedDescription)")
                showingErrorAlert = true
                HapticManager.errorOccurred()
            }
        }
    }

}

// MARK: - Settings Building Blocks

/// A single Settings row. Owns the icon size, the fixed icon column and the
/// label typography so every row's text starts on the same vertical line no
/// matter how wide its SF Symbol is.
/// Gates developer-only UI. Xcode installs keep `embedded.mobileprovision`; App Store and
/// TestFlight strip it, so ordinary users never see these controls — even in a Release binary.
enum DeveloperTools {
    static var isAvailable: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") != nil
        #endif
    }
}

private struct SettingsRow: View {
    enum Accessory {
        case chevron
        case externalLink

        var symbol: String {
            switch self {
            case .chevron: return "chevron.right"
            case .externalLink: return "arrow.up.right"
            }
        }
    }

    private let icon: String
    private let iconColor: Color
    private let title: Text
    private let subtitle: Text?
    private let accessory: Accessory?

    /// Width of the icon column. Sized for the widest symbol used here
    /// (`figure.and.child.holdinghands`) so nothing crowds the label.
    private let iconColumnWidth: CGFloat = 26

    init(
        icon: String,
        iconColor: Color = .forestGreen,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        accessory: Accessory? = nil
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = Text(title)
        self.subtitle = subtitle.map { Text($0) }
        self.accessory = accessory
    }

    /// For strings that must stay out of the string catalog (DEBUG-only rows).
    init(
        icon: String,
        iconColor: Color = .forestGreen,
        verbatim title: String,
        accessory: Accessory? = nil
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = Text(verbatim: title)
        self.subtitle = nil
        self.accessory = accessory
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: iconColumnWidth)

            VStack(alignment: .leading, spacing: 2) {
                title
                    .font(.bodyMedium)
                    .foregroundColor(.warmBlack)

                if let subtitle {
                    subtitle
                        .font(.caption)
                        .foregroundColor(.warmGray)
                }
            }

            Spacer(minLength: Spacing.sm)

            if let accessory {
                Image(systemName: accessory.symbol)
                    .font(.caption)
                    .foregroundColor(.warmGray)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Section header. The top padding is what separates one group from the next —
/// `listSectionSpacing` can only shrink the system default, not grow it.
private struct SettingsSectionHeader: View {
    private let title: Text

    init(_ title: LocalizedStringKey) {
        self.title = Text(title)
    }

    init(verbatim title: String) {
        self.title = Text(verbatim: title)
    }

    var body: some View {
        title
            .font(.headingSmall)
            .foregroundColor(.forestGreen)
            .textCase(nil)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xs)
    }
}

private struct SettingsSectionFooter: View {
    /// Each key renders as its own paragraph, so a section explaining several
    /// controls stays translatable one sentence at a time.
    private let paragraphs: [LocalizedStringKey]

    init(_ paragraphs: LocalizedStringKey...) {
        self.paragraphs = paragraphs
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
            }
        }
        .font(.caption)
        .foregroundColor(.warmGray)
        .padding(.top, Spacing.xs)
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
