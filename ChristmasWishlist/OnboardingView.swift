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
import SwiftData

enum OnboardingStep {
    case welcome
    case addChildren
    case surprisePreference
    case instructions
}

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var cloudKit = CloudKitManager.shared
    @AppStorage("showPurchasedItems") private var showPurchasedItems = true
    
    @State private var currentUserId: UUID = {
        if let existingId = AppGroupContainer.getCurrentUserId() {
            return existingId
        } else {
            let newId = UUID()
            AppGroupContainer.saveCurrentUserId(newId)
            return newId
        }
    }()
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

    // Adaptive image width: 30% on iPad, 200 on iPhone
    private var featuredImageMaxWidth: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return UIScreen.main.bounds.width * 0.3
        } else {
            return 200
        }
    }

    // Larger image width for instructions screen
    private var instructionsImageMaxWidth: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return UIScreen.main.bounds.width * 0.65
        } else {
            return UIScreen.main.bounds.width * 0.9
        }
    }

    var body: some View {
        let _ = print("🎄 [ONBOARDING] Body evaluated - isCompleted = \(isCompleted)")

        return ZStack {
            Color.creamBackground
                .ignoresSafeArea()

            switch currentStep {
            case .welcome:
                welcomeScreen
            case .addChildren:
                childrenScreen
            case .surprisePreference:
                surprisePreferenceScreen
            case .instructions:
                instructionsScreen
            }
        }
        .onChange(of: isCompleted) { oldValue, newValue in
            print("🎄 [ONBOARDING] ⚡ isCompleted binding changed from \(oldValue) to \(newValue)")
        }
        .fallingSnow(isActive: true, count: 25)
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
                .frame(maxWidth: featuredImageMaxWidth)
                .parallax3D()
                .padding(.horizontal, Spacing.lg)

            // Santa's message (directly on background, no container)
            VStack(spacing: Spacing.md) {
                Text("Welcome!\nCan I ask for some help? ")
                    .font(.custom("Caveat", size: 32))
                    .lineSpacing(-8)
                    .foregroundColor(.warmBlack)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Please select everyone that you\nmay exchange gifts with.")
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
                        .tint(.gold)
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
                                    colors: [Color.gold, Color.goldShimmer, Color.gold],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .stroke(Color.gold.opacity(0.6), lineWidth: 2)
                    )
                    .shadow(color: Color.gold.opacity(0.4), radius: 12, x: 0, y: 6)
                    .shadow(color: Color.goldShimmer.opacity(0.3), radius: 4, x: 0, y: 2)
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
        ZStack(alignment: .topLeading) {
            VStack(spacing: Spacing.xl) {
                Spacer()

            // Cookies Image
            Image("cookie")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: featuredImageMaxWidth)
                .parallax3D()
                .padding(.horizontal, Spacing.lg)

            // Santa's message (directly on background, no container)
            Text("Would you like to add your kids to the gift exchange?")
                .font(.custom("Caveat", size: 32))
                .lineSpacing(-8)
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
                .font(.headingSmall)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(
                            LinearGradient(
                                colors: [Color.gold, Color.goldShimmer, Color.gold],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(Color.gold.opacity(0.6), lineWidth: 2)
                )
                .shadow(color: Color.gold.opacity(0.4), radius: 12, x: 0, y: 6)
                .shadow(color: Color.goldShimmer.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .sparkle(isActive: true)
            .padding(.horizontal, Spacing.xl)

            // Continue/Skip Button
            if isProcessing {
                VStack(spacing: Spacing.sm) {
                    ProgressView(value: processingProgress)
                        .tint(.gold)
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
                    if childrenToAdd.isEmpty {
                        Text("Skip for now")
                            .font(.bodyMedium)
                            .foregroundColor(.warmGray)
                    } else {
                        Text("Continue")
                            .font(.headingSmall)
                            .bold()
                            .foregroundColor(Color(hex: "#8B2E1F"))
                    }
                }
                .padding(.bottom, Spacing.xl)
            }
            }

            // Back button
            Button(action: {
                HapticManager.buttonTapped()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    currentStep = .welcome
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.forestGreen)
                    .padding(Spacing.md)
                    .background(
                        Circle()
                            .fill(Color.white)
                            .shadow(color: DesignShadow.soft, radius: 8, x: 0, y: 2)
                    )
            }
            .padding(.top, 16)
            .padding(.leading, Spacing.lg)
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
    }

    // MARK: - Surprise Preference Screen
    private var surprisePreferenceScreen: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: Spacing.xl) {
                Spacer()

                // Milk Image
                Image("milk")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: featuredImageMaxWidth)
                    .parallax3D()
                    .padding(.horizontal, Spacing.lg)

                // Santa's message
                Text("Would you like to know if items are checked off your list?")
                    .font(.custom("Caveat", size: 32))
                    .lineSpacing(-8)
                    .foregroundColor(.warmBlack)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.lg)

                Spacer()

                // Choice Buttons
                VStack(spacing: Spacing.md) {
                    // "I like surprises!" button
                    Button {
                        HapticManager.buttonTapped()
                        showPurchasedItems = false
                        UserDefaults.standard.set(false, forKey: "showPurchasedItems")
                        UserDefaults.standard.set(false, forKey: "notificationsEnabled")
                        moveToInstructionsScreen()
                    } label: {
                        VStack(spacing: Spacing.xs) {
                            Text("I like surprises!")
                                .font(.headingSmall)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.gold, Color.goldShimmer, Color.gold],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .stroke(Color.gold.opacity(0.6), lineWidth: 2)
                        )
                        .shadow(color: Color.gold.opacity(0.4), radius: 12, x: 0, y: 6)
                        .shadow(color: Color.goldShimmer.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .sparkle(isActive: true)

                    // "I don't like surprises" button
                    Button {
                        HapticManager.buttonTapped()
                        showPurchasedItems = true
                        UserDefaults.standard.set(true, forKey: "showPurchasedItems")
                        UserDefaults.standard.set(true, forKey: "notificationsEnabled")
                        moveToInstructionsScreen()
                    } label: {
                        VStack(spacing: Spacing.xs) {
                            Text("I don't like surprises.")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundColor(.warmGray)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.15)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        )
                        .shadow(color: Color.gray.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xl)
            }

            // Back button
            Button(action: {
                HapticManager.buttonTapped()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    currentStep = .addChildren
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.forestGreen)
                    .padding(Spacing.md)
                    .background(
                        Circle()
                            .fill(Color.white)
                            .shadow(color: DesignShadow.soft, radius: 8, x: 0, y: 2)
                    )
            }
            .padding(.top, 16)
            .padding(.leading, Spacing.lg)
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
    }

    // MARK: - Instructions Screen
    private var instructionsScreen: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: Spacing.md) {
                Spacer()
                    .frame(height: 40)

                // Heading
                Text("Adding items\nto your wishlist")
                    .font(.custom("Caveat", size: 36))
                    .lineSpacing(-8)
                    .foregroundColor(.warmBlack)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.sm)

                // Instructions Image - Maximum size
                Image("instructions")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: instructionsImageMaxWidth)
                    .padding(.horizontal, Spacing.md)

                Spacer()

                // Continue Button
                Button {
                    print("🎄 [ONBOARDING] Get Started button pressed")
                    HapticManager.buttonTapped()

                    // ONLY set the binding - @AppStorage automatically writes to UserDefaults
                    isCompleted = true
                    print("🎄 [ONBOARDING] isCompleted set to true - @AppStorage will handle UserDefaults")
                } label: {
                    VStack(spacing: Spacing.xs) {
                        Text("Get Started")
                            .font(.headingSmall)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .fill(
                                LinearGradient(
                                    colors: [Color.gold, Color.goldShimmer, Color.gold],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .stroke(Color.gold.opacity(0.6), lineWidth: 2)
                    )
                    .shadow(color: Color.gold.opacity(0.4), radius: 12, x: 0, y: 6)
                    .shadow(color: Color.goldShimmer.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .sparkle(isActive: true)
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xl)
            }

            // Back button
            Button(action: {
                HapticManager.buttonTapped()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    currentStep = .surprisePreference
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.forestGreen)
                    .padding(Spacing.md)
                    .background(
                        Circle()
                            .fill(Color.white)
                            .shadow(color: DesignShadow.soft, radius: 8, x: 0, y: 2)
                    )
            }
            .padding(.top, 16)
            .padding(.leading, Spacing.lg)
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
                        // User denied - move to children screen
                        moveToChildrenScreen()
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

    private func moveToSurprisePreferenceScreen() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentStep = .surprisePreference
        }
    }

    private func moveToInstructionsScreen() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentStep = .instructions
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

    private func addFriend(from contact: CNContact) async {
        // Get primary phone/email for display/saving
        let phoneNumber = contact.phoneNumbers.first?.value.stringValue
        let email = contact.emailAddresses.first?.value as String?
        
        // Get ALL phones and emails for discovery
        let phoneNumbers = contact.phoneNumbers.map { $0.value.stringValue }
        let emails = contact.emailAddresses.map { $0.value as String }
        
        let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)

        HapticManager.itemAdded()

        // Get contact's photo if available
        var imageData: Data?
        if contact.imageDataAvailable {
            imageData = contact.imageData
        }

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

        // Save friend to SwiftData (Local Storage)
        let newFriend = Friend(
            name: name,
            phoneNumber: phoneNumber,
            email: email,
            hasApp: friendUserRecordID != nil,
            friendUserRecordID: friendUserRecordID,
            imageData: imageData
        )
        
        await MainActor.run {
            modelContext.insert(newFriend)
            try? modelContext.save()
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
                let contactName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                
                do {
                    await addFriend(from: contact)
                } catch let ckError as CKError where ckError.code == .quotaExceeded {
                    // CloudKit quota exceeded - show error and stop processing
                    print("❌ CloudKit quota exceeded while adding friend")
                    await MainActor.run {
                        errorMessage = ckError.userFriendlyMessage
                        showingError = true
                        isProcessing = false
                    }
                    break // Stop processing remaining contacts
                } catch {
                    // Other error - log and continue with next contact
                    print("❌ Failed to add friend \(contactName): \(error)")
                    await MainActor.run {
                        failedFriends.append(contactName)
                    }
                }

                // Update progress
                await MainActor.run {
                    processingProgress = Double(index + 1) / Double(selectedContacts.count)
                }
            }

            // Delay for CloudKit consistency and trigger refresh in FriendsListView
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

            // Notify FriendsListView to refresh when user navigates to it
            CloudKitManager.shared.shouldRefreshFriends.toggle()

            HapticManager.itemAdded()
            await MainActor.run {
                isProcessing = false
                moveToChildrenScreen()
            }
        }
    }

    private func processChildren() {
        // If no children to add, move to surprise preference screen immediately
        guard !childrenToAdd.isEmpty else {
            moveToSurprisePreferenceScreen()
            return
        }

        // Has children to save
        isProcessing = true
        processingProgress = 0

        Task {
            for (index, name) in childrenToAdd.enumerated() {
                do {
                    let record = try await cloudKit.saveChild(name: name)
                    
                    // Save to SwiftData
                    await MainActor.run {
                        let newChild = Child(
                            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
                            name: name,
                            parentId: currentUserId,
                            createdAt: record.creationDate ?? Date()
                        )
                        modelContext.insert(newChild)
                        try? modelContext.save()
                    }
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

            await MainActor.run {
                HapticManager.itemAdded()
                moveToSurprisePreferenceScreen()
            }
        }
    }

}

// MARK: - Multi-Contact Picker
struct MultiContactPickerView: UIViewControllerRepresentable {
    let onContactsSelected: ([CNContact]) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        // Explicitly allow selection of any contact to prevent "details mode"
        picker.predicateForSelectionOfContact = NSPredicate(value: true)
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
