//
//  FriendsListView.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI
import Contacts
import ContactsUI
import CloudKit

struct FriendsListView: View {
    @StateObject private var cloudKit = CloudKitManager.shared
    @State private var friends: [CKFriend] = []
    @State private var friendItemCounts: [String: Int] = [:]  // friendRecordID -> item count
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var hasLoadedOnce = false
    @State private var hasInitializedFromCache = false

    @State private var showingContactPicker = false
    @State private var contactPermissionStatus: CNAuthorizationStatus = .notDetermined
    @State private var friendToInvite: CKFriend?
    @State private var refreshTask: Task<Void, Never>?

    var isActive: Bool = true

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if friends.isEmpty {
                        if isLoading || cloudKit.isPreloadingFriends {
                            loadingStateView
                        } else {
                            emptyStateView
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: Spacing.md) {
                                ForEach(friends) { friend in
                                    VStack(spacing: Spacing.sm) {
                                        // Parent friend row
                                        NavigationLink {
                                            FriendWishlistView(friend: friend)
                                        } label: {
                                            FriendRow(
                                                friend: friend,
                                                itemCount: friendItemCounts[friend.friendUserRecordID ?? ""],
                                                onInvite: {
                                                    inviteFriend(friend)
                                                }
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())

                                        // Children (always shown, indented)
                                        ForEach(friend.visibleChildren) { child in
                                            NavigationLink {
                                                FriendWishlistView(friend: friend, child: child)
                                            } label: {
                                                ChildRow(
                                                    child: child,
                                                    itemCount: friendItemCounts[child.id]
                                                )
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .padding(.leading, 48)
                                        }
                                    }
                                    .transition(.asymmetric(
                                        insertion: .scale.combined(with: .opacity),
                                        removal: .scale.combined(with: .opacity)
                                    ))
                                }
                            }
                            .padding(Spacing.md)
                        }
                        .refreshable {
                            await loadFriends()
                        }
                    }
                }

                // Floating Action Button
                VStack {
                    Spacer()

                    HStack {
                        Spacer()

                        FloatingActionButton(
                            action: {
                                HapticManager.buttonTapped()
                                requestContactsAccess()
                            },
                            icon: "plus"
                        )
                        .sparkle(isActive: true)
                        .padding(Spacing.lg)
                    }
                }
            }
            .navigationTitle("")
            .goldTitle("Friends")
            .sheet(isPresented: $showingContactPicker) {
                ContactPickerView { contact in
                    addFriend(from: contact)
                }
            }
            .onAppear {
                checkContactPermission()

                // Initialize from cache on first appearance
                if !hasInitializedFromCache && !cloudKit.cachedFriends.isEmpty {
                    print("📋 [FRIENDS] Initializing from cache (\(cloudKit.cachedFriends.count) friends)")
                    friends = cloudKit.cachedFriends
                    friendItemCounts = cloudKit.cachedFriendItemCounts
                    hasInitializedFromCache = true
                    hasLoadedOnce = true
                }

                // Load friends on appear if CloudKit is ready and we haven't loaded yet
                if !hasLoadedOnce && cloudKit.isSignedInToiCloud {
                    Task {
                        await loadFriends()
                        hasLoadedOnce = true
                    }
                }
                // Start periodic refresh if tab is active
                if isActive {
                    startPeriodicRefresh()
                }
            }
            .onDisappear {
                stopPeriodicRefresh()
            }
            .onChange(of: isActive) { _, active in
                if active {
                    if !hasLoadedOnce && cloudKit.isSignedInToiCloud {
                        Task {
                            await loadFriends()
                            hasLoadedOnce = true
                        }
                    }
                    // Start periodic refresh when tab becomes active
                    startPeriodicRefresh()
                } else {
                    // Stop periodic refresh when tab becomes inactive
                    stopPeriodicRefresh()
                }
            }
            .onChange(of: cloudKit.isSignedInToiCloud) { _, isSignedIn in
                // Load data immediately when CloudKit is ready, regardless of tab visibility
                // This ensures friends list is prefetched and ready when user switches tabs
                if isSignedIn && !hasLoadedOnce {
                    Task {
                        await loadFriends()
                        hasLoadedOnce = true
                    }
                }
            }
            .onChange(of: cloudKit.shouldRefreshFriends) { _, _ in
                // Reload friends when refresh is triggered (e.g., after demo data load)
                Task {
                    await loadFriends()
                }
            }
            .onChange(of: cloudKit.isPreloadingFriends) { oldValue, newValue in
                // When preloading completes, update UI with cached data
                if oldValue && !newValue && !hasInitializedFromCache && !cloudKit.cachedFriends.isEmpty {
                    print("📋 [FRIENDS] Updating from newly populated cache (\(cloudKit.cachedFriends.count) friends)")
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        friends = cloudKit.cachedFriends
                        friendItemCounts = cloudKit.cachedFriendItemCounts
                    }
                    hasInitializedFromCache = true
                    hasLoadedOnce = true
                }
            }
            .sheet(item: $friendToInvite) { friend in
                ShareSheet(activityItems: [createInviteMessage(for: friend)])
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "person.2")
                .font(.system(size: 72))
                .foregroundColor(.warmGrayLight)

            Text("No friends added yet")
                .font(.headingMedium)
                .foregroundColor(.warmGray)

            Text("Tap the + button to add friends\nfrom your contacts")
                .font(.bodyMedium)
                .foregroundColor(.warmGray)
                .multilineTextAlignment(.center)

            Spacer()
        }
    }

    private var loadingStateView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .tint(.forestGreen)

            Text("Loading friends...")
                .font(.bodyMedium)
                .foregroundColor(.warmGray)

            Spacer()
        }
    }

    private func checkContactPermission() {
        contactPermissionStatus = CNContactStore.authorizationStatus(for: .contacts)
    }

    private func requestContactsAccess() {
        let store = CNContactStore()

        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            showingContactPicker = true

        case .notDetermined:
            store.requestAccess(for: .contacts) { granted, error in
                DispatchQueue.main.async {
                    if granted {
                        contactPermissionStatus = .authorized
                        showingContactPicker = true
                    } else {
                        HapticManager.errorOccurred()
                    }
                }
            }

        case .denied, .restricted:
            HapticManager.errorOccurred()
            // In a real app, show alert directing user to Settings

        case .limited:
            // Limited access - show picker with available contacts
            showingContactPicker = true

        @unknown default:
            break
        }
    }

    private func addFriend(from contact: CNContact) {
        let phoneNumber = contact.phoneNumbers.first?.value.stringValue
        let email = contact.emailAddresses.first?.value as String?
        let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)

        // Check if this friend already exists
        let isDuplicate = friends.contains { friend in
            // Match by name (case-insensitive)
            if friend.name.lowercased() == name.lowercased() {
                return true
            }
            // Match by phone number
            if let phone = phoneNumber, let friendPhone = friend.phoneNumber,
               !phone.isEmpty, !friendPhone.isEmpty {
                let cleanPhone = phone.filter { $0.isNumber }
                let cleanFriendPhone = friendPhone.filter { $0.isNumber }
                if cleanPhone == cleanFriendPhone {
                    return true
                }
            }
            // Match by email (case-insensitive)
            if let email = email, let friendEmail = friend.email,
               !email.isEmpty, !friendEmail.isEmpty {
                if email.lowercased() == friendEmail.lowercased() {
                    return true
                }
            }
            return false
        }

        if isDuplicate {
            errorMessage = "\(name) is already in your friends list"
            showingError = true
            HapticManager.errorOccurred()
            return
        }

        HapticManager.itemAdded()

        // Get contact's photo if available
        var imageData: Data?
        if contact.imageDataAvailable {
            imageData = contact.imageData
        }

        Task {
            do {
                // Try to discover if friend has the app (tries phone first, then email)
                var friendUserRecordID: String?
                if let recordID = try await cloudKit.discoverUser(phoneNumber: phoneNumber, email: email) {
                    friendUserRecordID = recordID.recordName
                    print("✅ Discovered friend has app! Record ID: \(recordID.recordName)")
                } else {
                    print("ℹ️ Friend hasn't installed the app yet")
                }

                // Save friend to CloudKit
                _ = try await cloudKit.saveFriend(
                    name: name,
                    phoneNumber: phoneNumber,
                    email: email,
                    imageData: imageData,
                    friendUserRecordID: friendUserRecordID
                )

                // Delay for CloudKit consistency - increased to ensure propagation on new devices
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

                // Track for review prompt (after first friend)
                ReviewManager.shared.markFirstFriendAdded()

                // Reload friends
                await loadFriends()
            } catch let ckError as CKError {
                // CloudKit-specific error handling
                await MainActor.run {
                    errorMessage = ckError.userFriendlyMessage
                    showingError = true
                    HapticManager.errorOccurred()
                }
                print("❌ Failed to add friend \(name): \(ckError)")
            } catch {
                // Other errors
                await MainActor.run {
                    errorMessage = "Failed to add friend: \(error.localizedDescription)"
                    showingError = true
                    HapticManager.errorOccurred()
                }
                print("❌ Failed to add friend \(name): \(error)")
            }
        }
    }

    private func loadFriends() async {
        let startTime = Date()
        print("⏱️ [FRIENDS] Starting to load friends...")
        print("📊 [FRIENDS] Current user record ID: \(cloudKit.currentUserRecordID?.recordName ?? "unknown")")

        isLoading = true
        defer { isLoading = false }

        do {
            let fetchStart = Date()
            let records = try await cloudKit.fetchMyFriends()
            print("⏱️ [FRIENDS] Fetched \(records.count) friend records in \(Date().timeIntervalSince(fetchStart).formatted())s")

            // Log details about each friend record for debugging
            if records.count > 0 {
                print("📋 [FRIENDS] Friend records breakdown:")
                for (index, record) in records.enumerated() {
                    let name = record["name"] as? String ?? "unknown"
                    let ownerID = record["ownerID"] as? String ?? "unknown"
                    let friendUserRecordID = record["friendUserRecordID"] as? String ?? "none"
                    print("  \(index + 1). \(name) (ownerID: \(ownerID.prefix(8))..., hasApp: \(!friendUserRecordID.isEmpty))")
                }
            }

            // Fetch children for each friend who has the app
            var friendsWithChildren: [CKFriend] = []
            for record in records {
                let friendRecordID = record["friendUserRecordID"] as? String
                var children: [CKChild] = []

                if let friendRecordID = friendRecordID, !friendRecordID.isEmpty {
                    let childFetchStart = Date()
                    do {
                        let childRecords = try await cloudKit.fetchChildrenForUser(userRecordID: friendRecordID)
                        children = childRecords.map { CKChild(from: $0) }
                        print("⏱️ [FRIENDS] Fetched \(children.count) children for friend in \(Date().timeIntervalSince(childFetchStart).formatted())s")
                    } catch let error as CKError where error.code == .unknownItem {
                        // Record type doesn't exist yet - normal on first run
                        print("☁️ CloudKit: Child record type not created yet")
                        children = []
                    } catch {
                        print("❌ Error fetching children for friend: \(error)")
                    }
                }

                friendsWithChildren.append(CKFriend(from: record, children: children))
            }

            await MainActor.run {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    friends = friendsWithChildren
                }
            }

            print("⏱️ [FRIENDS] Displayed \(friends.count) friends in UI")

            // Fetch item counts for friends and children
            let countStart = Date()
            await loadItemCounts()
            print("⏱️ [FRIENDS] Loaded all item counts in \(Date().timeIntervalSince(countStart).formatted())s")
            print("⏱️ [FRIENDS] TOTAL TIME: \(Date().timeIntervalSince(startTime).formatted())s")
        } catch let ckError as CKError {
            let friendlyMessage = ckError.userFriendlyMessage
            await MainActor.run {
                errorMessage = friendlyMessage
                showingError = true
            }
            print("❌ [FRIENDS] Failed after \(Date().timeIntervalSince(startTime).formatted())s: \(ckError.localizedDescription)")
        } catch {
            await MainActor.run {
                errorMessage = "Unable to load friends. Please check your internet connection and try again."
                showingError = true
            }
            print("❌ [FRIENDS] Failed after \(Date().timeIntervalSince(startTime).formatted())s: \(error.localizedDescription)")
        }
    }

    private func loadItemCounts() async {
        var totalFetches = 0
        for friend in friends where friend.hasApp {
            guard let friendRecordID = friend.friendUserRecordID else { continue }

            // Load item count for friend
            let fetchStart = Date()
            do {
                let items = try await cloudKit.fetchFriendWishlistItems(friendRecordID: friendRecordID)
                totalFetches += 1
                print("⏱️ [COUNTS] Fetched \(items.count) items for \(friend.name) in \(Date().timeIntervalSince(fetchStart).formatted())s")
                await MainActor.run {
                    friendItemCounts[friendRecordID] = items.count
                }
            } catch {
                print("❌ Error loading item count for \(friend.name): \(error)")
            }

            // Load item counts for friend's children
            for child in friend.children {
                let childFetchStart = Date()
                do {
                    let items = try await cloudKit.fetchFriendWishlistItems(friendRecordID: child.id)
                    totalFetches += 1
                    print("⏱️ [COUNTS] Fetched \(items.count) items for child \(child.name) in \(Date().timeIntervalSince(childFetchStart).formatted())s")
                    await MainActor.run {
                        friendItemCounts[child.id] = items.count
                    }
                } catch {
                    print("❌ Error loading item count for \(child.name): \(error)")
                }
            }
        }
        print("⏱️ [COUNTS] Completed \(totalFetches) item count fetches")
    }

    private func inviteFriend(_ friend: CKFriend) {
        HapticManager.buttonTapped()
        friendToInvite = friend
    }

    private func createInviteMessage(for friend: CKFriend) -> String {
        return """
        I have a wishlist here if you are interested. I would like to see yours as well. Get the list here:

        https://apps.apple.com/app/id6755366177
        """
    }

    private func startPeriodicRefresh() {
        // Cancel existing task if any
        stopPeriodicRefresh()

        // Start new periodic refresh task
        refreshTask = Task {
            while !Task.isCancelled {
                // Wait 30 seconds
                try? await Task.sleep(nanoseconds: 30_000_000_000)

                // Check if still active and not cancelled
                guard !Task.isCancelled, isActive, cloudKit.isSignedInToiCloud else {
                    break
                }

                // Refresh friends list
                await loadFriends()
            }
        }
    }

    private func stopPeriodicRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}

// MARK: - Contact Picker Wrapper
struct ContactPickerView: UIViewControllerRepresentable {
    let onContactSelected: (CNContact) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onContactSelected: onContactSelected)
    }

    class Coordinator: NSObject, CNContactPickerDelegate {
        let onContactSelected: (CNContact) -> Void

        init(onContactSelected: @escaping (CNContact) -> Void) {
            self.onContactSelected = onContactSelected
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onContactSelected(contact)
        }
    }
}

#Preview {
    FriendsListView()
}
