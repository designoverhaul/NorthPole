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
import OSLog

private let logger = Logger(subsystem: "com.designoverhaul.ChristmasWishlist", category: "FriendsList")

struct FriendsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Friend.name) private var friends: [Friend]
    @ObservedObject private var firebase = FirebaseManager.shared

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var hasLoadedOnce = false
    
    @State private var showingContactPicker = false
    @State private var contactPermissionStatus: CNAuthorizationStatus = .notDetermined
    
    @State private var friendItemCounts: [String: Int] = [:]  // friendPhone -> item count
    @State private var friendChildren: [String: [(childId: String, child: FirestoreChild)]] = [:]  // friendPhone -> (childId, child)
    @State private var childItemCounts: [String: Int] = [:]  // childId -> item count

    var body: some View {
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
        ZStack {
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
                    .sparkle()
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
            await refreshFriendDiscoveryStatus()
            await loadFriendData()
        }
    }
    
    private func friendRow(for friend: Friend) -> some View {
        VStack(spacing: Spacing.sm) {
            // Parent friend row
            NavigationLink {
                FriendWishlistView(friend: friend, childId: nil, childName: nil)
            } label: {
                FriendRow(
                    friend: friend,
                    itemCount: friend.phoneNumber.flatMap { friendItemCounts[$0] }
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

            // Children rows (fetched from Firebase) - displayed as normal users
            if let friendPhone = friend.phoneNumber,
               let childrenData = friendChildren[friendPhone] {
                let visibleChildren = childrenData.filter { childData in
                    !friend.hiddenChildRecordIDs.contains(childData.childId)
                }
                
                ForEach(visibleChildren, id: \.childId) { childData in
                    NavigationLink {
                        FriendWishlistView(friend: friend, childId: childData.childId, childName: childData.child.name)
                    } label: {
                        // Create a temporary Friend object to display child as normal user
                        FriendRow(
                            friend: createTempFriendForChild(name: childData.child.name),
                            itemCount: childItemCounts[childData.childId]
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

        // Load friends from Firebase on appear (refresh every time, not just once)
        if firebase.isAuthenticated {
            Task {
                await loadFriendsFromFirebase()
                await refreshFriendDiscoveryStatus() // Check if any friends have installed the app
                await loadFriendData()
                hasLoadedOnce = true
            }
        }
    }
    
    /// Refresh discovery status for all friends (check if they've installed the app)
    private func refreshFriendDiscoveryStatus() async {
        logger.info("🔍 [FRIENDS] Refreshing friend discovery status for \(friends.count) friends...")
        
        var discoveredNewFriends = false
        
        for friend in friends where !friend.hasApp {
            guard let phone = friend.phoneNumber else { continue }
            
            do {
                let hasApp = try await firebase.checkIfFriendHasApp(friendPhone: phone)
                if hasApp {
                    logger.info("✅ [FRIENDS] Discovered \(friend.name) now has the app!")
                    await MainActor.run {
                        friend.hasApp = true
                        try? modelContext.save()
                    }
                    discoveredNewFriends = true
                }
            } catch {
                logger.error("⚠️ [FRIENDS] Error checking \(friend.name): \(error)")
            }
        }
        
        // If we discovered any new friends with the app, load their data (including children)
        if discoveredNewFriends {
            await loadFriendData()
        }
    }

    /// Load friends from Firebase and sync with local SwiftData cache
    private func loadFriendsFromFirebase() async {
        logger.info("🔄 [FRIENDS] Loading friends from Firebase...")

        guard firebase.isAuthenticated else {
            logger.warning("⚠️ [FRIENDS] Not authenticated, skipping")
            return
        }

        do {
            let _ = try await firebase.fetchMyFriends(context: modelContext)
            logger.info("✅ [FRIENDS] Friends synced from Firebase")
        } catch {
            logger.error("❌ [FRIENDS] Failed to load friends from Firebase: \(error)")
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
        let phoneNumber = contact.phoneNumbers.first?.value.stringValue
        let email = contact.emailAddresses.first?.value as String?
        let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)

        guard let phone = phoneNumber, !phone.isEmpty else { return }

        let normalizedPhone = PhoneNumber.normalize(phone)
        let isDuplicate = friends.contains { friend in
            guard let friendPhone = friend.phoneNumber else { return false }
            return PhoneNumber.matches(friendPhone, normalizedPhone)
        }

        if isDuplicate {
            errorMessage = String(localized: "\(name) is already in your friends list")
            showingError = true
            HapticManager.errorOccurred()
            return
        }

        HapticManager.itemAdded()

        var imageData: Data?
        if contact.imageDataAvailable {
            imageData = contact.imageData
        }

        Task {
            do {
                let friend = try await firebase.addFriend(
                    name: name,
                    phone: normalizedPhone,
                    email: email,
                    imageData: imageData,
                    context: modelContext
                )
                logger.info("✅ [ADD_FRIEND] Saved friend: \(friend.name), hasApp: \(friend.hasApp)")
                if friend.hasApp {
                    await loadFriendData()
                }
            } catch {
                logger.error("❌ [ADD_FRIEND] Failed: \(error)")
                await MainActor.run {
                    errorMessage = String(localized: "Failed to save friend: \(error.localizedDescription)")
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

        // Delete from Firebase in background
        if let firebaseId = friend.cloudKitRecordID {
            Task {
                do {
                    try await firebase.deleteFriend(friendId: firebaseId)
                    logger.info("✅ [DELETE_FRIEND] Deleted friend from Firebase: \(friend.name)")
                } catch {
                    logger.error("❌ [DELETE_FRIEND] Failed to delete from Firebase: \(error)")
                }
            }
        } else {
            logger.warning("⚠️ [DELETE_FRIEND] No Firebase document ID for friend: \(friend.name)")
        }
    }

    private func loadFriendData() async {
        guard !friends.isEmpty else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        logger.info("⏱️ [FRIENDS] Loading data for \(friends.count) local friends...")
        
        var newCounts: [String: Int] = [:]
        var newChildren: [String: [(childId: String, child: FirestoreChild)]] = [:]
        var newChildCounts: [String: Int] = [:]
        
        for friend in friends where friend.hasApp {
            guard let friendPhone = friend.phoneNumber else { continue }
            
            do {
                // Fetch friend's wishlist items
                let items = try await firebase.fetchFriendWishlistItems(ownerPhone: friendPhone)
                newCounts[friendPhone] = items.count
                
                // Fetch friend's children with their document IDs
                let childrenData = try await firebase.fetchChildrenForFriendWithIds(friendPhone: friendPhone)
                newChildren[friendPhone] = childrenData
                
                // Fetch item counts for all children
                for (childId, child) in childrenData {
                    do {
                        let childItems = try await firebase.fetchFriendWishlistItems(ownerPhone: nil, childId: childId)
                        newChildCounts[childId] = childItems.count
                    } catch {
                        newChildCounts[childId] = 0
                    }
                }
            } catch {
                logger.error("❌ Error loading data for \(friend.name): \(error)")
            }
        }
        
        await MainActor.run {
            friendItemCounts = newCounts
            friendChildren = newChildren
            childItemCounts = newChildCounts
        }
    }
    
    /// Create a temporary Friend object for displaying a child as a normal user
    private func createTempFriendForChild(name: String) -> Friend {
        return Friend(
            name: name,
            phoneNumber: nil,
            email: nil,
            hasApp: true, // Children always have items if they appear in friends list
            friendUserRecordID: nil,
            cloudKitRecordID: nil,
            imageData: nil,
            hiddenChildRecordIDs: []
        )
    }
}

#Preview {
    FriendsListView()
        .modelContainer(for: Friend.self, inMemory: true)
}
