//
//  OnboardingView.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI
import Contacts
import ContactsUI
import SwiftData

enum OnboardingStep {
    case welcome
    case addChildren
    case surprisePreference
    case instructions
}

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("showPurchasedItems") private var showPurchasedItems = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
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
        .onAppear {
            initializeCurrentUser()
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
                .sparkle()
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
            Text("Would you like to add your kids (without a phone) to the gift exchange?")
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
            .sparkle()
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
                        chooseSurprises()
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
                    .sparkle()

                    // "I don't like surprises" button
                    Button {
                        HapticManager.buttonTapped()
                        chooseSpoilers()
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
                Text("Adding items from the web\nto your wishlist")
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
                    
                    // Create user document in Firestore before completing onboarding
                    Task {
                        let firebase = FirebaseManager.shared
                        do {
                            // Use phone number as display name for now (or we can prompt for name later)
                            let displayName = "User" // Default name - can be updated later
                            try await firebase.createOrUpdateUser(displayName: displayName)
                            print("✅ [ONBOARDING] User document created in Firestore")
                            
                            // Set completed after user document is created
                            await MainActor.run {
                                isCompleted = true
                                print("🎄 [ONBOARDING] isCompleted set to true - @AppStorage will handle UserDefaults")
                            }
                        } catch {
                            print("❌ [ONBOARDING] Failed to create user document: \(error)")
                            // Still complete onboarding even if document creation fails
                            await MainActor.run {
                                isCompleted = true
                            }
                        }
                    }
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
                .sparkle()
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

    private func initializeCurrentUser() {
        // Firebase will handle user initialization during phone auth
        // This function is no longer needed but kept for compatibility
        print("✅ [ONBOARDING] User initialization handled by Firebase Auth")
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

    /// Keeps friends' claims hidden — the free choice, and the default for both settings.
    private func chooseSurprises() {
        showPurchasedItems = false
        notificationsEnabled = false
        moveToInstructionsScreen()
    }

    /// Reveals claims and purchase notifications, which is the same paid feature as the two
    /// Settings switches — the paywall decides, so onboarding only continues once it unlocks.
    private func chooseSpoilers() {
        SuperwallManager.shared.requestRevealPurchases(feature: .onboardingSurprises) {
            showPurchasedItems = true
            notificationsEnabled = true
            requestNotificationPermissionsAndContinue()
        }
    }

    private func requestNotificationPermissionsAndContinue() {
        Task { @MainActor in
            let status = await NotificationManager.shared.checkAuthorizationStatus()
            if status == .notDetermined {
                print("📱 [ONBOARDING] Requesting notification permissions...")
                let granted = await NotificationManager.shared.requestAuthorization()
                if !granted {
                    notificationsEnabled = false
                }
            } else if status == .denied {
                notificationsEnabled = false
            }

            moveToInstructionsScreen()
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
        let phoneNumber = contact.phoneNumbers.first?.value.stringValue
        let email = contact.emailAddresses.first?.value as String?
        let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)

        guard let phone = phoneNumber, !phone.isEmpty else { return }

        HapticManager.itemAdded()

        var imageData: Data?
        if contact.imageDataAvailable {
            imageData = contact.imageData
        }

        // Firestore is the source of truth for friendships. A local-only Friend row
        // would look added but never connect the two accounts, so retry instead of
        // faking it, and keep onboarding moving if it still fails.
        for attempt in 1...2 {
            do {
                _ = try await FirebaseManager.shared.addFriend(
                    name: name,
                    phone: phone,
                    email: email,
                    imageData: imageData,
                    context: modelContext
                )
                return
            } catch {
                print("⚠️ [ONBOARDING] Failed to save friend \(name) (attempt \(attempt)): \(error)")
            }
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
                await addFriend(from: contact)

                // Update progress
                await MainActor.run {
                    processingProgress = Double(index + 1) / Double(selectedContacts.count)
                }
            }

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
            let firebase = FirebaseManager.shared

            for (index, name) in childrenToAdd.enumerated() {
                do {
                    // Save to Firebase (or skip if not authenticated)
                    let childId = try await firebase.saveChild(name: name)

                    // Save to SwiftData
                    await MainActor.run {
                        let newChild = Child(
                            name: name,
                            parentId: UUID(),
                            cloudKitRecordID: childId
                        )
                        modelContext.insert(newChild)
                        try? modelContext.save()
                    }
                } catch {
                    print("⚠️ [ONBOARDING] Failed to add child \(name): \(error)")
                    // Continue with next child even if one fails
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
