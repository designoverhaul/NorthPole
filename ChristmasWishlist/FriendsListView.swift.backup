//
//  FriendsListView.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData
import Contacts
import ContactsUI
import CloudKit

struct FriendsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Friend.name) private var friends: [Friend]
    @ObservedObject private var cloudKit = CloudKitManager.shared

    @State private var cloudKitFriendRecords: [String: CKRecord] = [:]  // friendRecordID -> CKRecord
    @State private var friendItemCounts: [String: Int] = [:]  // friendRecordID -> item count
    @State private var friendChildren: [String: [CKChild]] = [:]  // friendRecordID -> children
    @State private var childItemCounts: [String: Int] = [:]  // childRecordID -> item count
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var hasLoadedOnce = false
    
    @State private var showingContactPicker = false
    @State private var contactPermissionStatus: CNAuthorizationStatus = .notDetermined
    @State private var friendToInvite: Friend?
    @State private var refreshTask: Task<Void, Never>?
    @State private var shareProfileURL: URL?
    @State private var showingNamePrompt = false
    @State private var tempName = ""
    @AppStorage("userName") private var userName = ""

    var isActive: Bool = true

    var body: some View {
        navigationView
    }
    
    private var navigationView: some View {
        NavigationStack {
            mainContent
                .navigationTitle("")
                .goldTitle("Friends")
                .sheet(isPresented: $showingContactPicker) {
                    ContactPickerView { contacts in
                        addFriends(from: contacts)
                    }
                }
                .onAppear(perform: handleAppear)
                .onDisappear(perform: stopPeriodicRefresh)
                .onChange(of: isActive) { oldValue, newValue in
                    handleActiveChange(oldValue, newValue)
                }
                .onChange(of: cloudKit.isSignedInToiCloud) { oldValue, newValue in
                    handleSignInChange(oldValue, newValue)
                }
                .sheet(item: $friendToInvite) { friend in
                    ShareSheet(activityItems: [createInviteMessage(for: friend)])
                }
                .sheet(item: Binding(
                    get: { shareProfileURL.map { IdentifiableURL(url: $0) } },
                    set: { shareProfileURL = $0?.url }
                )) { identifiableURL in
                    ShareSheet(activityItems: ["Here is my wishlist:", identifiableURL.url])
                }
                .alert("What's your name?", isPresented: $showingNamePrompt) {
                    TextField("Your Name", text: $tempName)
                    Button("Cancel", role: .cancel) { }
                    Button("Share") {
                        if !tempName.isEmpty {
                            userName = tempName
                            generateAndShareLink()
                        }
                    }
                } message: {
                    Text("Enter your name so friends know who sent the invite.")
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
    
    private var mainContent: some View {
        let _ = print("🔍 [UI] FriendsListView rendering with \(friends.count) friends")
        
        return ZStack {
            Color.creamBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if friends.isEmpty {
                    if isLoading {
                        loadingStateView
                    } else {
                        emptyStateView
                    }
                } else {
                    friendsList
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
    }
    
    private var friendsList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.md) {
                ForEach(friends) { friend in
                    friendRow(for: friend)
                }
            }
            .padding(Spacing.md)
        }
        .refreshable {
            await loadFriendData()
        }
    }
    
    private func friendRow(for friend: Friend) -> some View {
        VStack(spacing: Spacing.sm) {
            // Parent friend row
            NavigationLink {
                FriendWishlistView(friend: friend)
            } label: {
                FriendRow(
                    friend: friend,
                    itemCount: friendItemCounts[friend.friendUserRecordID ?? ""]
                )
            }
            .buttonStyle(PlainButtonStyle())
            .contextMenu {
                Button(role: .destructive) {
                    deleteFriend(friend)
                } label: {
                    Label("Remove Friend", systemImage: "trash")
                }
            }

            // Children rows (fetched from CloudKit)
            if let friendRecordID = friend.friendUserRecordID,
               let children = friendChildren[friendRecordID] {
                let visibleChildren = children.filter { !friend.hiddenChildRecordIDs.contains($0.id) }
                
                ForEach(visibleChildren) { child in
                    NavigationLink {
                        FriendWishlistView(friend: friend, child: child)
                    } label: {
                        ChildRow(
                            child: child,
                            itemCount: childItemCounts[child.id]
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.leading, Spacing.lg)
                }
            }
        }
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .scale.combined(with: .opacity)
        ))
    }
    
    private func handleAppear() {
        checkContactPermission()

        // Load friends from CloudKit on appear
        if !hasLoadedOnce && cloudKit.isSignedInToiCloud {
            Task {
                await loadFriendsFromCloudKit()
                await loadFriendData()
                hasLoadedOnce = true
            }
        }

        // Start periodic refresh if tab is active
        if isActive {
            startPeriodicRefresh()
        }
    }

    /// Load friends from CloudKit and sync with local SwiftData cache
    private func loadFriendsFromCloudKit() async {
        print("🔄 [FRIENDS] Loading friends from CloudKit...")

        guard cloudKit.isSignedInToiCloud else {
            print("⚠️ [FRIENDS] Not signed in to iCloud, skipping")
            return
        }

        do {
            let cloudKitFriends = try await cloudKit.fetchMyFriends()
            print("📦 [FRIENDS] Found \(cloudKitFriends.count) friends in CloudKit")

            await MainActor.run {
                // Store CloudKit records for reference
                for record in cloudKitFriends {
                    cloudKitFriendRecords[record.recordID.recordName] = record
                }

                // Sync with local cache
                for record in cloudKitFriends {
                    let name = record["name"] as? String ?? ""
                    let phoneNumber = (record["phoneNumber"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                    let email = (record["email"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                    let friendUserRecordID = (record["friendUserRecordID"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                    let addedAt = record["addedAt"] as? Date ?? Date()
                    let cloudKitRecordID = record.recordID.recordName

                    // Get photo if available
                    var imageData: Data?
                    if let asset = record["photo"] as? CKAsset,
                       let fileURL = asset.fileURL,
                       let data = try? Data(contentsOf: fileURL) {
                        imageData = data
                    }

                    // Check if friend already exists in local cache
                    if let existingFriend = friends.first(where: { friend in
                        // Match by CloudKit record ID first (most reliable)
                        if let existingCKID = friend.cloudKitRecordID, existingCKID == cloudKitRecordID {
                            return true
                        }
                        // Fallback to name or contact info
                        if friend.name == name { return true }
                        if let phone = phoneNumber, let friendPhone = friend.phoneNumber {
                            let cleanPhone = phone.filter { $0.isNumber }
                            let cleanFriendPhone = friendPhone.filter { $0.isNumber }
                            if cleanPhone == cleanFriendPhone { return true }
                        }
                        if let email = email, let friendEmail = friend.email {
                            if email.lowercased() == friendEmail.lowercased() { return true }
                        }
                        return false
                    }) {
                        // Update existing friend with latest CloudKit data
                        existingFriend.name = name
                        existingFriend.phoneNumber = phoneNumber
                        existingFriend.email = email
                        existingFriend.hasApp = friendUserRecordID != nil
                        existingFriend.friendUserRecordID = friendUserRecordID
                        existingFriend.cloudKitRecordID = cloudKitRecordID
                        existingFriend.imageData = imageData
                        print("🔄 [FRIENDS] Updated existing friend: \(name)")
                    } else {
                        // Create new friend in local cache
                        let newFriend = Friend(
                            name: name,
                            phoneNumber: phoneNumber,
                            email: email,
                            hasApp: friendUserRecordID != nil,
                            friendUserRecordID: friendUserRecordID,
                            cloudKitRecordID: cloudKitRecordID,
                            addedAt: addedAt,
                            imageData: imageData
                        )
                        modelContext.insert(newFriend)
                        print("✅ [FRIENDS] Added new friend to cache: \(name)")
                    }
                }

                // Save local changes
                try? modelContext.save()
                print("✅ [FRIENDS] Synced \(cloudKitFriends.count) friends to local cache")
            }

        } catch {
            print("❌ [FRIENDS] Failed to load friends from CloudKit: \(error)")
        }
    }
    
    private func handleActiveChange(_ oldValue: Bool, _ active: Bool) {
        if active {
            if !hasLoadedOnce && cloudKit.isSignedInToiCloud {
                Task {
                    await loadFriendsFromCloudKit()
                    await loadFriendData()
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

    private func handleSignInChange(_ oldValue: Bool, _ isSignedIn: Bool) {
        if isSignedIn && !hasLoadedOnce {
            Task {
                await loadFriendsFromCloudKit()
                await loadFriendData()
                hasLoadedOnce = true
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
            SnowflakeLoadingView("Loading friends...")
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

        case .limited:
            showingContactPicker = true

        @unknown default:
            break
        }
    }

    private func addFriends(from contacts: [CNContact]) {
        for contact in contacts {
            addFriend(from: contact)
        }
    }

    private func addFriend(from contact: CNContact) {
        // Get primary phone/email for display/saving
        let phoneNumber = contact.phoneNumbers.first?.value.stringValue
        let email = contact.emailAddresses.first?.value as String?

        // Get ALL phones and emails for discovery
        let phoneNumbers = contact.phoneNumbers.map { $0.value.stringValue }
        let emails = contact.emailAddresses.map { $0.value as String }

        let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)

        // Check if this friend already exists locally
        let isDuplicate = friends.contains { friend in
            if friend.name.lowercased() == name.lowercased() { return true }

            if let phone = phoneNumber, let friendPhone = friend.phoneNumber,
               !phone.isEmpty, !friendPhone.isEmpty {
                let cleanPhone = phone.filter { $0.isNumber }
                let cleanFriendPhone = friendPhone.filter { $0.isNumber }
                if cleanPhone == cleanFriendPhone { return true }
            }

            if let email = email, let friendEmail = friend.email,
               !email.isEmpty, !friendEmail.isEmpty {
                if email.lowercased() == friendEmail.lowercased() { return true }
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
            // Try to discover if friend has the app (tries all phones and emails)
            var friendUserRecordID: String?
            do {
                if let recordID = try await cloudKit.discoverUser(phoneNumbers: phoneNumbers, emails: emails) {
                    friendUserRecordID = recordID.recordName
                    print("✅ Discovered friend has app! Record ID: \(recordID.recordName)")
                } else {
                    print("ℹ️ Friend hasn't installed the app yet")
                }
            } catch {
                print("⚠️ Error discovering user: \(error)")
            }

            // STEP 1: Save to CloudKit FIRST (source of truth)
            do {
                let savedRecord = try await cloudKit.saveFriend(
                    name: name,
                    phoneNumber: phoneNumber,
                    email: email,
                    friendUserRecordID: friendUserRecordID,
                    imageData: imageData
                )
                print("✅ [ADD_FRIEND] Saved friend to CloudKit: \(name)")

                // STEP 2: Then cache locally for fast display
                await MainActor.run {
                    let newFriend = Friend(
                        name: name,
                        phoneNumber: phoneNumber,
                        email: email,
                        hasApp: friendUserRecordID != nil,
                        friendUserRecordID: friendUserRecordID,
                        cloudKitRecordID: savedRecord.recordID.recordName,
                        imageData: imageData
                    )

                    print("💾 [ADD_FRIEND] Caching friend locally: \(name), hasApp: \(friendUserRecordID != nil)")
                    print("📋 [ADD_FRIEND] CloudKit record ID: \(savedRecord.recordID.recordName)")

                    modelContext.insert(newFriend)

                    do {
                        try modelContext.save()
                        print("✅ [ADD_FRIEND] Successfully cached friend: \(name)")
                        print("📊 [ADD_FRIEND] Total friends now: \(friends.count)")
                    } catch {
                        print("❌ [ADD_FRIEND] Failed to cache friend: \(error)")
                    }

                    // Store CloudKit record
                    cloudKitFriendRecords[savedRecord.recordID.recordName] = savedRecord

                    // Track for review prompt
                    ReviewManager.shared.markFirstFriendAdded()

                    // Refresh data to get item counts
                    Task { await loadFriendData() }
                }
            } catch {
                print("❌ [ADD_FRIEND] Failed to save friend to CloudKit: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to save friend: \(error.localizedDescription)"
                    showingError = true
                    HapticManager.errorOccurred()
                }
            }
        }
    }
    
    private func deleteFriend(_ friend: Friend) {
        // Delete from local cache immediately
        modelContext.delete(friend)
        try? modelContext.save()
        HapticManager.itemDeleted()

        // Delete from CloudKit in background
        if let cloudKitRecordID = friend.cloudKitRecordID {
            Task {
                do {
                    let recordID = CKRecord.ID(recordName: cloudKitRecordID)
                    try await cloudKit.deleteFriend(recordID)
                    print("✅ [DELETE_FRIEND] Deleted friend from CloudKit: \(friend.name)")
                } catch {
                    print("❌ [DELETE_FRIEND] Failed to delete from CloudKit: \(error)")
                    // Note: Local delete already happened, so we're in an inconsistent state
                    // Consider showing error to user and offering to retry
                }
            }
        } else {
            print("⚠️ [DELETE_FRIEND] No CloudKit record ID for friend: \(friend.name)")
        }
    }

    private func loadFriendData() async {
        guard !friends.isEmpty else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        print("⏱️ [FRIENDS] Loading data for \(friends.count) local friends...")
        
        var newCounts: [String: Int] = [:]
        var newChildren: [String: [CKChild]] = [:]
        var newChildCounts: [String: Int] = [:]
        
        for friend in friends where friend.hasApp {
            guard let friendRecordID = friend.friendUserRecordID else { continue }
            
            do {
                // Fetch friend's wishlist items
                let items = try await cloudKit.fetchFriendWishlistItems(friendRecordID: friendRecordID)
                newCounts[friendRecordID] = items.count
                
                // Fetch friend's children
                let childRecords = try await cloudKit.fetchChildrenForUser(userRecordID: friendRecordID)
                var children = childRecords.map { CKChild(from: $0) }
                
                // Deduplicate children by name (keep the one with items, or most recent if both have/not have items)
                // This handles cases where duplicate Child records exist in CloudKit
                var uniqueChildren: [String: CKChild] = [:]
                var childItemCountsTemp: [String: Int] = [:]
                
                // First, fetch item counts for all children to help with deduplication
                for child in children {
                    do {
                        let childItems = try await cloudKit.fetchFriendWishlistItems(friendRecordID: child.id)
                        childItemCountsTemp[child.id] = childItems.count
                    } catch {
                        childItemCountsTemp[child.id] = 0
                    }
                }
                
                // Now deduplicate, preferring children with items
                for child in children {
                    let itemCount = childItemCountsTemp[child.id] ?? 0
                    
                    if let existing = uniqueChildren[child.name] {
                        let existingItemCount = childItemCountsTemp[existing.id] ?? 0
                        
                        // Prefer the one with items, or if both have/not have items, keep the most recent
                        if itemCount > existingItemCount {
                            uniqueChildren[child.name] = child
                        } else if itemCount == existingItemCount && child.createdAt > existing.createdAt {
                            uniqueChildren[child.name] = child
                        }
                    } else {
                        uniqueChildren[child.name] = child
                    }
                }
                
                children = Array(uniqueChildren.values).sorted { $0.name < $1.name }
                newChildren[friendRecordID] = children
                
                // Store item counts for the deduplicated children
                for child in children {
                    newChildCounts[child.id] = childItemCountsTemp[child.id] ?? 0
                }
            } catch {
                print("❌ Error loading data for \(friend.name): \(error)")
            }
        }
        
        await MainActor.run {
            friendItemCounts = newCounts
            friendChildren = newChildren
            childItemCounts = newChildCounts
        }
    }

    private func inviteFriend(_ friend: Friend) {
        HapticManager.buttonTapped()
        friendToInvite = friend
    }

    private func createInviteMessage(for friend: Friend) -> String {
        return """
        I have a wishlist here if you are interested. I would like to see yours as well. Get the list here:

        https://apps.apple.com/app/id6755366177
        """
    }

    private func startPeriodicRefresh() {
        stopPeriodicRefresh()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled, isActive, cloudKit.isSignedInToiCloud else { break }
                // Sync friends from CloudKit, then load their data
                await loadFriendsFromCloudKit()
                await loadFriendData()
            }
        }
    }

    private func stopPeriodicRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
    
    private func prepareShareProfile() {
        HapticManager.buttonTapped()
        
        if userName.isEmpty {
            tempName = ""
            showingNamePrompt = true
        } else {
            generateAndShareLink()
        }
    }
    
    private func generateAndShareLink() {
        // Generate URL - this will be nil if not signed in to iCloud
        guard let url = DeepLinkManager.shared.generateInviteLink(name: userName) else {
            errorMessage = "Could not generate invite link. Please make sure you are signed in to iCloud."
            showingError = true
            HapticManager.errorOccurred()
            return
        }

        // Setting shareProfileURL will automatically show the sheet via .sheet(item:)
        shareProfileURL = url
    }
}

#Preview {
    FriendsListView()
        .modelContainer(for: Friend.self, inMemory: true)
}
