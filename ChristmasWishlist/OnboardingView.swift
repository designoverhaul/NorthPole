//
//  OnboardingView.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI
import Contacts
import ContactsUI
import CloudKit

enum OnboardingStep {
    case welcome
    case addChildren
}

struct OnboardingView: View {
    @StateObject private var cloudKit = CloudKitManager.shared
    @State private var currentStep: OnboardingStep = .welcome
    @State private var showingContactPicker = false
    @State private var selectedContacts: [CNContact] = []
    @State private var isProcessing = false
    @State private var processingProgress: Double = 0
    @State private var childrenToAdd: [String] = []
    @State private var newChildName = ""
    @State private var showingAddChildSheet = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var failedFriends: [String] = []
    @Binding var isCompleted: Bool

    var body: some View {
        ZStack {
            Color.creamBackground
                .ignoresSafeArea()

            switch currentStep {
            case .welcome:
                welcomeScreen
            case .addChildren:
                childrenScreen
            }
        }
        .sheet(isPresented: $showingContactPicker) {
            MultiContactPickerView { contacts in
                selectedContacts = contacts
                processFriends()
            }
        }
        .sheet(isPresented: $showingAddChildSheet) {
            AddChildSheet(
                newChildName: $newChildName,
                isAdding: .constant(false),
                onAdd: addChild
            )
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Welcome Screen
    private var welcomeScreen: some View {
        VStack(spacing: Spacing.md) {
            Spacer()

            // Santa Image
            Image("Santa")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 280)
                .padding(.horizontal, Spacing.lg)

            // Santa's message (directly on background, no container)
            VStack(spacing: Spacing.md) {
                Text("Welcome!\nI'll be your matchmaker for gifting.")
                    .font(.custom("Caveat", size: 37))
                    .foregroundColor(.warmBlack)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Thanks for the help. Please select everyone that you may exchange gifts with.")
                    .font(.bodyLarge)
                    .foregroundColor(.warmGray)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()

            // Processing indicator
            if isProcessing {
                VStack(spacing: Spacing.sm) {
                    ProgressView(value: processingProgress)
                        .tint(.forestGreen)
                        .padding(.horizontal, Spacing.xl)

                    Text("Adding \(selectedContacts.count) friends...")
                        .font(.bodySmall)
                        .foregroundColor(.warmGray)
                }
                .padding(.bottom, Spacing.lg)
            } else {
                // Get Started Button
                Button {
                    HapticManager.buttonTapped()
                    requestContactsAccess()
                } label: {
                    HStack {
                        Image(systemName: "person.2.fill")
                        Text("Select Friends")
                    }
                    .font(.headingSmall)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .fill(
                                LinearGradient(
                                    colors: [Color.forestGreen, Color.forestGreenLight],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: DesignShadow.medium, radius: 8, x: 0, y: 4)
                }
                .sparkle(isActive: true)
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.lg)

                // Skip button
                Button {
                    HapticManager.buttonTapped()
                    moveToChildrenScreen()
                } label: {
                    Text("Skip for now")
                        .font(.bodyMedium)
                        .foregroundColor(.warmGray)
                }
                .padding(.bottom, Spacing.xl)
            }
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
    }

    // MARK: - Children Screen
    private var childrenScreen: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Santa Image
            Image("Santa")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 200)
                .padding(.horizontal, Spacing.lg)

            // Santa's message (directly on background, no container)
            Text("Would you like to add any kids to the gift exchange?")
                .font(.custom("Caveat", size: 37))
                .foregroundColor(.warmBlack)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)

            // Children list
            if !childrenToAdd.isEmpty {
                VStack(spacing: Spacing.sm) {
                    ForEach(Array(childrenToAdd.enumerated()), id: \.offset) { index, name in
                        HStack {
                            Image(systemName: "figure.and.child.holdinghands")
                                .foregroundColor(.forestGreen)

                            Text(name)
                                .font(.bodyLarge)
                                .foregroundColor(.warmBlack)

                            Spacer()

                            Button {
                                removeChild(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.warmGray)
                            }
                        }
                        .padding(Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(Color.creamCard)
                        )
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }

            Spacer()

            // Add Child Button
            Button {
                HapticManager.buttonTapped()
                showingAddChildSheet = true
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle.badge.plus")
                    Text("Add a Child")
                }
                .font(.bodyLarge.weight(.semibold))
                .foregroundColor(.forestGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(Color.forestGreen, lineWidth: 2)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(Color.creamCard)
                        )
                )
            }
            .padding(.horizontal, Spacing.xl)

            // Continue/Skip Button
            if isProcessing {
                VStack(spacing: Spacing.sm) {
                    ProgressView(value: processingProgress)
                        .tint(.forestGreen)
                        .padding(.horizontal, Spacing.xl)

                    Text("Adding children...")
                        .font(.bodySmall)
                        .foregroundColor(.warmGray)
                }
                .padding(.bottom, Spacing.lg)
            } else {
                Button {
                    HapticManager.buttonTapped()
                    processChildren()
                } label: {
                    Text(childrenToAdd.isEmpty ? "Skip" : "Continue")
                        .font(.headingSmall)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.forestGreen, Color.forestGreenLight],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .shadow(color: DesignShadow.medium, radius: 8, x: 0, y: 4)
                }
                .sparkle(isActive: !childrenToAdd.isEmpty)
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xl)
            }
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
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
                        showingContactPicker = true
                    } else {
                        HapticManager.errorOccurred()
                        // User denied - complete onboarding anyway
                        completeOnboarding()
                    }
                }
            }

        case .denied, .restricted:
            HapticManager.errorOccurred()
            // Move to children screen without contacts
            moveToChildrenScreen()

        case .limited:
            showingContactPicker = true

        @unknown default:
            break
        }
    }

    private func moveToChildrenScreen() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentStep = .addChildren
        }
    }

    private func addChild() {
        guard !newChildName.isEmpty else { return }

        childrenToAdd.append(newChildName)
        newChildName = ""
        showingAddChildSheet = false
        HapticManager.itemAdded()
    }

    private func removeChild(at index: Int) {
        HapticManager.buttonTapped()
        _ = withAnimation {
            childrenToAdd.remove(at: index)
        }
    }

    private func processFriends() {
        guard !selectedContacts.isEmpty else {
            moveToChildrenScreen()
            return
        }

        isProcessing = true
        processingProgress = 0

        Task {
            for (index, contact) in selectedContacts.enumerated() {
                let phoneNumber = contact.phoneNumbers.first?.value.stringValue
                let email = contact.emailAddresses.first?.value as String?

                // Get contact's photo if available
                var imageData: Data?
                if contact.imageDataAvailable {
                    imageData = contact.imageData
                }

                let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)

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
                } catch {
                    print("Failed to add friend \(name): \(error)")
                }

                // Update progress
                await MainActor.run {
                    processingProgress = Double(index + 1) / Double(selectedContacts.count)
                }
            }

            // Small delay to show completion
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            HapticManager.itemAdded()
            await MainActor.run {
                isProcessing = false
                moveToChildrenScreen()
            }
        }
    }

    private func processChildren() {
        guard !childrenToAdd.isEmpty else {
            completeOnboarding()
            return
        }

        isProcessing = true
        processingProgress = 0

        Task {
            for (index, name) in childrenToAdd.enumerated() {
                do {
                    _ = try await cloudKit.saveChild(name: name)
                } catch {
                    print("Failed to add child \(name): \(error)")
                }

                // Update progress
                await MainActor.run {
                    processingProgress = Double(index + 1) / Double(childrenToAdd.count)
                }
            }

            // Small delay to show completion
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            HapticManager.itemAdded()
            completeOnboarding()
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isCompleted = true
        }
    }
}

// MARK: - Multi-Contact Picker
struct MultiContactPickerView: UIViewControllerRepresentable {
    let onContactsSelected: ([CNContact]) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onContactsSelected: onContactsSelected)
    }

    class Coordinator: NSObject, CNContactPickerDelegate {
        let onContactsSelected: ([CNContact]) -> Void

        init(onContactsSelected: @escaping ([CNContact]) -> Void) {
            self.onContactsSelected = onContactsSelected
        }

        // Multi-select support
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            onContactsSelected(contacts)
        }

        // Handle cancellation
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onContactsSelected([])
        }
    }
}

#Preview {
    OnboardingView(isCompleted: .constant(false))
}
