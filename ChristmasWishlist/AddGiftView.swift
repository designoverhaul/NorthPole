//
//  AddGiftView.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData

struct AddGiftView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let userId: UUID
    let onItemAdded: () -> Void
    let itemToEdit: WishlistItem?

    @ObservedObject private var firebase = FirebaseManager.shared
    @State private var name = ""
    @State private var url = ""
    @State private var description = ""
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingLinkHelp = false
    @State private var isSyncingToCloud = false
    @State private var clipboardHasContent = false
    @State private var isExtractingData = false
    @State private var isCleaningTitle = false
    @State private var previousURLLength = 0
    @FocusState private var focusedField: Field?

    enum Field {
        case name, url, description
    }

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isEditMode: Bool {
        itemToEdit != nil
    }

    init(userId: UUID, onItemAdded: @escaping () -> Void, itemToEdit: WishlistItem? = nil) {
        self.userId = userId
        self.onItemAdded = onItemAdded
        self.itemToEdit = itemToEdit

        // Pre-populate fields if editing
        if let item = itemToEdit {
            _name = State(initialValue: item.name)
            _url = State(initialValue: item.url ?? "")
            _description = State(initialValue: item.itemDescription ?? "")
            if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                _selectedImage = State(initialValue: uiImage)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // URL field (optional)
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack {
                                Text("Link")
                                    .font(.bodyMedium)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.warmBlack)

                                Spacer()

                                Button(action: {
                                    HapticManager.buttonTapped()
                                    showingLinkHelp = true
                                }) {
                                    Image(systemName: "questionmark.circle")
                                        .font(.system(size: 16))
                                        .foregroundColor(.forestGreen)
                                }
                            }

                            HStack(spacing: 0) {
                                TextField("", text: $url)
                                    .font(.bodyMedium)
                                    .foregroundColor(.warmBlack)
                                    .keyboardType(.URL)
                                    .autocapitalization(.none)
                                    .padding(Spacing.md)
                                    .focused($focusedField, equals: .url)
                                    .tint(.forestGreen)

                                Button(action: {
                                    if let pastedString = UIPasteboard.general.string {
                                        url = pastedString
                                        // Dismiss keyboard after pasting
                                        focusedField = nil
                                    }
                                    HapticManager.buttonTapped()
                                    checkClipboard()
                                }) {
                                    Text("Paste")
                                        .font(.bodyMedium)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, Spacing.md)
                                        .padding(.vertical, Spacing.sm)
                                        .background(
                                            RoundedRectangle(cornerRadius: CornerRadius.sm)
                                                .fill(clipboardHasContent ? Color.forestGreen : Color.warmGrayLight)
                                        )
                                }
                                .disabled(!clipboardHasContent)
                                .padding(.trailing, Spacing.sm)
                            }
                            .background(Color.white)
                            .cornerRadius(CornerRadius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .stroke(focusedField == .url ? Color.forestGreen : Color.warmGrayLight, lineWidth: 2)
                            )
                            .onChange(of: url) { oldValue, newValue in
                                handleURLChange(oldValue: oldValue, newValue: newValue)
                            }

                            // Extraction indicator
                            if isExtractingData {
                                HStack(spacing: Spacing.sm) {
                                    Text("❄️")
                                        .font(.system(size: 16))
                                    Text("Extracting product info...")
                                        .font(.caption)
                                        .foregroundColor(.forestGreen)
                                }
                                .padding(.top, Spacing.xs)
                            }
                        }

                        // Name field (required)
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Item Name")
                                .font(.bodyMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(.warmBlack)

                            TextField("e.g., Coffee Maker", text: $name)
                                .font(.bodyLarge)
                                .foregroundColor(.warmBlack)
                                .padding(Spacing.md)
                                .background(Color.white)
                                .cornerRadius(CornerRadius.md)
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.md)
                                        .stroke(focusedField == .name ? Color.forestGreen : Color.warmGrayLight, lineWidth: 2)
                                )
                                .focused($focusedField, equals: .name)

                            // Title cleaning indicator
                            if isCleaningTitle {
                                HStack(spacing: Spacing.sm) {
                                    Text("✨")
                                        .font(.system(size: 16))
                                    Text("Cleaning title...")
                                        .font(.caption)
                                        .foregroundColor(.forestGreen)
                                }
                                .padding(.top, Spacing.xs)
                            }
                        }

                        // Description field (optional)
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Description")
                                .font(.bodyMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(.warmBlack)

                            TextField("Add any notes or preferences...", text: $description, axis: .vertical)
                                .font(.bodyMedium)
                                .foregroundColor(.warmBlack)
                                .lineLimit(3...6)
                                .padding(Spacing.md)
                                .background(Color.white)
                                .cornerRadius(CornerRadius.md)
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.md)
                                        .stroke(focusedField == .description ? Color.forestGreen : Color.warmGrayLight, lineWidth: 2)
                                )
                                .focused($focusedField, equals: .description)
                        }

                        // Photo section
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Photo")
                                .font(.bodyMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(.warmBlack)

                            if let selectedImage = selectedImage {
                                // Show selected image
                                VStack(spacing: Spacing.sm) {
                                    Image(uiImage: selectedImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity)
                                        .frame(maxHeight: 300)
                                        .cornerRadius(CornerRadius.md)

                                    Button(action: {
                                        showingImagePicker = true
                                    }) {
                                        HStack {
                                            Image(systemName: "photo")
                                            Text("Change Photo")
                                        }
                                        .font(.bodyMedium)
                                        .foregroundColor(.forestGreen)
                                    }
                                }
                            } else {
                                // Show add photo button
                                Button(action: {
                                    showingImagePicker = true
                                }) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 24))
                                        .foregroundColor(.forestGreen)
                                        .frame(maxWidth: .infinity)
                                        .padding(Spacing.lg)
                                    .background(Color.white)
                                    .cornerRadius(CornerRadius.md)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.md)
                                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                            .foregroundColor(.warmGrayLight)
                                    )
                                }
                            }
                        }

                        // Save button
                        Button(action: saveItem) {
                            HStack {
                                Spacer()
                                Text("Save")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!isFormValid)
                        .opacity(isFormValid ? 1.0 : 0.5)
                        .padding(.top, Spacing.md)
                        
                        // Delete button (only in edit mode)
                        if isEditMode {
                            Button(action: deleteItem) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete Gift")
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.warmGray)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, Spacing.lg)
                                .padding(.vertical, Spacing.md)
                                .background(Color.creamCard)
                                .cornerRadius(CornerRadius.md)
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.md)
                                        .stroke(Color.warmGrayLight, lineWidth: 1.5)
                                )
                            }
                            .padding(.top, Spacing.sm)
                        }
                    }
                    .padding(Spacing.lg)
                }
            }
            .navigationTitle("")
            .goldTitle(isEditMode ? "Edit Gift" : "Add Gift")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.buttonTapped()
                        dismiss()
                    }
                    .foregroundColor(.warmGray)
                }
            }
            .onAppear {
                focusedField = .name
                checkClipboard()
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .sheet(isPresented: $showingLinkHelp) {
                LinkHelpView()
            }
        }
    }

    private func saveItem() {
        guard isFormValid else { return }

        HapticManager.itemAdded()
        isSyncingToCloud = true

        let imageData = selectedImage?.jpegData(compressionQuality: 0.7)
        print("💾 [ADDGIFT] saveItem - selectedImage exists: \(selectedImage != nil), imageData bytes: \(imageData?.count ?? 0)")
        if let imageData = imageData {
            print("💾 [ADDGIFT] Image data size: \(imageData.count) bytes")
        }

        if let existingItem = itemToEdit {
            // Update existing item
            existingItem.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            existingItem.url = url.isEmpty ? nil : url.trimmingCharacters(in: .whitespacesAndNewlines)
            existingItem.itemDescription = description.isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines)
            existingItem.imageData = imageData
            print("✏️ [ADDGIFT] Updated item '\(existingItem.name)' with imageData: \(existingItem.imageData != nil), bytes: \(existingItem.imageData?.count ?? 0)")

            // Sync update to Firebase
            Task {
                await syncItemToFirebase(item: existingItem, isNewItem: false)
            }
        } else {
            // Create new item
            let newItem = WishlistItem(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                url: url.isEmpty ? nil : url.trimmingCharacters(in: .whitespacesAndNewlines),
                itemDescription: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
                ownerId: userId,
                imageData: imageData,
                imageUrl: nil, // Will be set after upload to Firebase
                ownerPhone: FirebaseAuthManager.shared.currentUserPhone ?? "",
                isOwnedByCurrentUser: true,
                lastSyncedAt: nil // Will be set after sync to Firebase
            )
            modelContext.insert(newItem)
            print("➕ [ADDGIFT] Created new item '\(newItem.name)' with imageData: \(newItem.imageData != nil), bytes: \(newItem.imageData?.count ?? 0)")

            // Sync new item to Firebase immediately
            Task {
                await syncItemToFirebase(item: newItem, isNewItem: true)
            }
        }

        onItemAdded()

        dismiss()
    }

    private func syncItemToFirebase(item: WishlistItem, isNewItem: Bool) async {
        guard firebase.isAuthenticated else {
            print("⚠️ [SYNC] Not authenticated, skipping Firebase sync")
            isSyncingToCloud = false
            return
        }

        print("☁️ [SYNC] Syncing item '\(item.name)' to Firebase...")
        print("☁️ [SYNC] Item has imageData: \(item.imageData != nil), bytes: \(item.imageData?.count ?? 0)")

        do {
            // Determine if this belongs to a child by checking if item.ownerId matches any child's ID
            // Fetch all children to check if item.ownerId matches any of them
            let childrenDescriptor = FetchDescriptor<Child>()
            let allChildren = (try? modelContext.fetch(childrenDescriptor)) ?? []
            
            // Check if item.ownerId matches any child's SwiftData UUID
            let matchingChild = allChildren.first { $0.id == item.ownerId }
            let isChild = matchingChild != nil
            var childIdString: String? = nil
            
            if isChild, let child = matchingChild {
                // This item belongs to a child - get the Firebase document ID
                if let firebaseChildId = child.cloudKitRecordID, !firebaseChildId.isEmpty {
                    childIdString = firebaseChildId
                    print("✅ [SYNC] Item belongs to child '\(child.name)'")
                    print("✅ [SYNC] Child SwiftData ID: \(child.id.uuidString), Firebase ID: \(firebaseChildId)")
                    // Verify they're different (they should be - SwiftData UUID vs Firebase document ID)
                    if child.id.uuidString == firebaseChildId {
                        print("⚠️ [SYNC] WARNING: SwiftData UUID matches Firebase ID - this shouldn't happen!")
                    }
                } else {
                    print("❌ [SYNC] ERROR: Child '\(child.name)' exists but has no Firebase ID! This item will be saved incorrectly.")
                    print("❌ [SYNC] This should not happen - child should have been synced to Firebase first.")
                    // Don't save without childId - it would appear in parent's list incorrectly
                    throw NSError(domain: "AddGiftView", code: 1, userInfo: [NSLocalizedDescriptionKey: String(localized: "Child account not properly synced. Please try again.")])
                }
            } else {
                print("✅ [SYNC] Item belongs to user (not a child)")
            }

            let savedItemId = try await firebase.saveWishlistItem(
                id: item.id,
                name: item.name,
                url: item.url,
                description: item.itemDescription,
                imageData: item.imageData,
                ownerId: item.ownerId,
                ownerType: isChild ? "child" : "user",
                childId: childIdString,
                context: modelContext
            )
            print("✅ [SYNC] Successfully synced to Firebase")
            print("✅ [SYNC] Item ID: \(savedItemId)")
            print("✅ [SYNC] ownerType: \(isChild ? "child" : "user"), childId: \(childIdString ?? "nil")")
            if isChild {
                print("✅ [SYNC] This item should appear in child's wishlist, not parent's")
            } else {
                print("✅ [SYNC] This item should appear in user's wishlist")
            }
            isSyncingToCloud = false

            if isNewItem {
                ReviewManager.shared.incrementItemsAdded()
            }
        } catch {
            print("❌ [SYNC] Failed to sync to Firebase: \(error.localizedDescription)")
            isSyncingToCloud = false
        }
    }

    private func deleteItem() {
        guard let item = itemToEdit else { return }

        HapticManager.itemDeleted()

        // Delete from Firebase and local database
        Task {
            // Delete from Firebase first
            do {
                try await firebase.deleteWishlistItem(id: item.id)
                print("✅ [DELETE] Deleted item '\(item.name)' from Firebase")
            } catch {
                print("❌ [DELETE] Failed to delete from Firebase: \(error.localizedDescription)")
            }

            // Delete from local database
            await MainActor.run {
                modelContext.delete(item)
                onItemAdded() // Trigger refresh
                dismiss()
            }
        }
    }

    private func checkClipboard() {
        clipboardHasContent = UIPasteboard.general.hasStrings
    }

    // MARK: - URL Extraction

    private func handleURLChange(oldValue: String, newValue: String) {
        // Detect paste (significant length increase)
        let lengthIncrease = newValue.count - oldValue.count

        // If user pasted a URL (length increased by >10 chars) and it looks like a URL
        if lengthIncrease > 10 && newValue.contains(".") && !isExtractingData {
            // Dismiss keyboard after pasting URL
            focusedField = nil
            extractProductData(from: newValue)
        }

        previousURLLength = newValue.count
    }

    private func extractProductData(from urlString: String) {
        isExtractingData = true

        Task {
            let productData = await URLProductExtractor.extract(from: urlString)

            // Fill in extracted data (only if fields are currently empty)
            if let extractedName = productData.name, name.isEmpty {
                // Set the raw extracted name first (so user sees it immediately)
                name = extractedName

                // Then clean it up with AI
                isCleaningTitle = true
                let cleanedName = await XAIService.shared.cleanProductTitle(extractedName)
                name = cleanedName
                isCleaningTitle = false
            }

            // Only use description if it's meaningfully different from the name
            if let extractedDescription = productData.description, description.isEmpty {
                // Check if description is just a duplicate of the name
                let trimmedDesc = extractedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

                // Skip if:
                // 1. Exactly the same
                // 2. Description is just name with minor additions (< 30 chars difference)
                let isIdentical = trimmedDesc.lowercased() == trimmedName.lowercased()
                let isTooSimilar = trimmedDesc.count < trimmedName.count + 30 &&
                                  trimmedDesc.lowercased().hasPrefix(trimmedName.lowercased())

                if !isIdentical && !isTooSimilar {
                    // Use the description - it has meaningful content
                    if let price = productData.price {
                        self.description = "\(extractedDescription)\n\n" + String(localized: "Price: \(price)")
                    } else {
                        self.description = extractedDescription
                    }
                } else if let price = productData.price {
                    // Description is duplicate, so only add price
                    self.description = String(localized: "Price: \(price)")
                }
            } else if let price = productData.price, description.isEmpty {
                // Only price available
                self.description = String(localized: "Price: \(price)")
            }

            // Download and set image if available
            if let imageURL = productData.imageURL, selectedImage == nil {
                if let imageData = await ProductImageDownloader.shared.downloadImage(from: imageURL),
                   let image = UIImage(data: imageData) {
                    selectedImage = image
                }
            }

            // Provide haptic feedback on successful extraction
            if productData.hasData {
                HapticManager.itemAdded()
            }

            isExtractingData = false
        }
    }
}

// MARK: - Link Help View
struct LinkHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamBackground
                    .ignoresSafeArea()

                VStack(spacing: Spacing.md) {
                    Text("Adding items\nto your wishlist")
                        .font(.custom("Caveat", size: 36))
                        .lineSpacing(-8)
                        .foregroundColor(.warmBlack)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.lg)

                    Image("instructions")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.9)
                        .padding(.horizontal, Spacing.md)

                    Spacer()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        HapticManager.buttonTapped()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.warmGray)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    AddGiftView(userId: UUID(), onItemAdded: {})
        .modelContainer(for: [WishlistItem.self])
}
