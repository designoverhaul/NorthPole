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
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var showingContactPicker = false
    @State private var contactPermissionStatus: CNAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if friends.isEmpty {
                        emptyStateView
                    } else {
                        ScrollView {
                            LazyVStack(spacing: Spacing.md) {
                                ForEach(friends) { friend in
                                    NavigationLink {
                                        FriendWishlistView(friend: friend)
                                    } label: {
                                        FriendRow(friend: friend)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .transition(.asymmetric(
                                        insertion: .scale.combined(with: .opacity),
                                        removal: .scale.combined(with: .opacity)
                                    ))
                                }
                            }
                            .padding(Spacing.md)
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
                            icon: "person.badge.plus"
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
                Task {
                    await loadFriends()
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
        HapticManager.itemAdded()

        let phoneNumber = contact.phoneNumbers.first?.value.stringValue
        let email = contact.emailAddresses.first?.value as String?

        // Get contact's photo if available
        var imageData: Data?
        if contact.imageDataAvailable {
            imageData = contact.imageData
        }

        let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)

        Task {
            do {
                // Try to discover if friend has the app by email
                var friendUserRecordID: String?
                if let email = email {
                    if let recordID = try await cloudKit.discoverUserByEmail(email) {
                        friendUserRecordID = recordID.recordName
                    }
                }

                // Save friend to CloudKit
                _ = try await cloudKit.saveFriend(
                    name: name,
                    phoneNumber: phoneNumber,
                    email: email,
                    imageData: imageData,
                    friendUserRecordID: friendUserRecordID
                )

                // Reload friends
                await loadFriends()
            } catch {
                errorMessage = "Failed to add friend: \(error.localizedDescription)"
                HapticManager.errorOccurred()
            }
        }
    }

    private func loadFriends() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let records = try await cloudKit.fetchMyFriends()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                friends = records.map { CKFriend(from: $0) }
            }
        } catch {
            errorMessage = "Failed to load friends: \(error.localizedDescription)"
        }
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
