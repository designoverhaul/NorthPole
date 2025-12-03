//
//  CloudKitAddGiftView.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI
import CloudKit

struct CloudKitAddGiftView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var cloudKit = CloudKitManager.shared

    let ownerRecordID: String?
    let ownerName: String
    let onItemAdded: (CKWishlistItem) -> Void

    @State private var name = ""
    @State private var url = ""
    @State private var description = ""
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var isSaving = false
    @State private var isExtractingData = false
    @State private var isCleaningTitle = false
    @State private var previousURLLength = 0
    @State private var clipboardHasContent = false
    @State private var showingLinkHelp = false
    @State private var errorAlertMessage: String?
    @State private var showErrorAlert = false
    @FocusState private var focusedField: Field?

    enum Field {
        case name, url, description
    }

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Owner indicator (if adding for a child)
                        if ownerName != "Me" {
                            HStack {
                                Image(systemName: "figure.2.and.child.holdinghands")
                                    .foregroundColor(.forestGreen)
                                Text("Adding gift for \(ownerName)")
                                    .font(.bodyMedium)
                                    .foregroundColor(.warmGray)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Spacing.md)
                            .background(Color.creamCard)
                            .cornerRadius(CornerRadius.md)
                        }

                        // Name field
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Item")
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

                        // URL field
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
                                TextField("https://example.com/product", text: $url)
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

                        // Description field
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
                                if isSaving {
                                    Text("❄️")
                                        .font(.system(size: 20))
                                }
                                Text(isSaving ? "Saving..." : "Save")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!isFormValid || isSaving)
                        .opacity(isFormValid && !isSaving ? 1.0 : 0.5)
                        .padding(.top, Spacing.md)
                    }
                    .padding(Spacing.lg)
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
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .keyboard) {
                    Button(action: {
                        HapticManager.buttonTapped()
                        focusedField = nil
                    }) {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.forestGreen)
                            .padding(12)
                            .background(Color.white.opacity(0.9))
                            .clipShape(Circle())
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
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
            .alert("Error Saving Item", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {
                    showErrorAlert = false
                }
            } message: {
                if let errorMessage = errorAlertMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    private func saveItem() {
        guard isFormValid else { return }

        isSaving = true
        HapticManager.itemAdded()

        Task {
            do {
                let imageData = selectedImage?.jpegData(compressionQuality: 0.7)

                let savedRecord = try await cloudKit.saveWishlistItem(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    url: url.isEmpty ? nil : url.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
                    imageData: imageData,
                    ownerRecordID: ownerRecordID
                )

                let newItem = CKWishlistItem(from: savedRecord)
                onItemAdded(newItem)

                // Track for review prompt (after 3rd item)
                ReviewManager.shared.incrementItemsAdded()

                dismiss()
            } catch {
                print("❌ Error saving item: \(error)")
                
                // Extract user-friendly error message
                if let ckError = error as? CKError {
                    errorAlertMessage = ckError.userFriendlyMessage
                } else {
                    errorAlertMessage = error.localizedDescription
                }
                
                showErrorAlert = true
                isSaving = false
            }
        }
    }

    // MARK: - Clipboard Check

    private func checkClipboard() {
        clipboardHasContent = UIPasteboard.general.hasStrings
    }

    // MARK: - URL Extraction

    private func handleURLChange(oldValue: String, newValue: String) {
        // Detect paste (significant length increase)
        let lengthIncrease = newValue.count - oldValue.count

        // If user pasted a URL (length increased by >10 chars) and it looks like a URL
        if lengthIncrease > 10 && newValue.contains(".") && !isExtractingData {
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
                        self.description = "\(extractedDescription)\n\nPrice: \(price)"
                    } else {
                        self.description = extractedDescription
                    }
                } else if let price = productData.price {
                    // Description is duplicate, so only add price
                    self.description = "Price: \(price)"
                }
            } else if let price = productData.price, description.isEmpty {
                // Only price available
                self.description = "Price: \(price)"
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

// MARK: - CloudKit Edit Gift View

struct CloudKitEditGiftView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var cloudKit = CloudKitManager.shared

    @State var item: CKWishlistItem
    let onItemUpdated: (CKWishlistItem) -> Void
    let onItemDeleted: ((String) -> Void)?

    @State private var isSaving = false
    @State private var clipboardHasContent = false
    @State private var errorAlertMessage: String?
    @State private var showErrorAlert = false
    @FocusState private var focusedField: Field?

    enum Field {
        case name, url, description
    }

    var isFormValid: Bool {
        !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Name field
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Item")
                                .font(.bodyMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(.warmBlack)

                            TextField("e.g., Coffee Maker", text: $item.name)
                                .font(.bodyLarge)
                                .foregroundColor(.warmBlack)
                                .padding(Spacing.md)
                                .background(Color.white)
                                .cornerRadius(CornerRadius.md)
                                .focused($focusedField, equals: .name)
                        }

                        // URL field
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Link")
                                .font(.bodyMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(.warmBlack)

                            HStack(spacing: 0) {
                                TextField("https://example.com/product", text: Binding(
                                    get: { item.url ?? "" },
                                    set: { item.url = $0.isEmpty ? nil : $0 }
                                ))
                                    .font(.bodyMedium)
                                    .foregroundColor(.warmBlack)
                                    .keyboardType(.URL)
                                    .autocapitalization(.none)
                                    .padding(Spacing.md)
                                    .focused($focusedField, equals: .url)
                                    .tint(.forestGreen)

                                Button(action: {
                                    if let pastedString = UIPasteboard.general.string {
                                        item.url = pastedString
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
                        }

                        // Description field
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Description")
                                .font(.bodyMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(.warmBlack)

                            TextField("Add any notes...", text: Binding(
                                get: { item.itemDescription ?? "" },
                                set: { item.itemDescription = $0.isEmpty ? nil : $0 }
                            ), axis: .vertical)
                                .font(.bodyMedium)
                                .foregroundColor(.warmBlack)
                                .lineLimit(3...6)
                                .padding(Spacing.md)
                                .background(Color.white)
                                .cornerRadius(CornerRadius.md)
                                .focused($focusedField, equals: .description)
                        }

                        // Save button
                        Button(action: saveItem) {
                            HStack {
                                if isSaving {
                                    Text("❄️")
                                        .font(.system(size: 20))
                                }
                                Text(isSaving ? "Saving..." : "Save Changes")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!isFormValid || isSaving)
                        .padding(.top, Spacing.md)

                        // Delete button
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
                        .disabled(isSaving)
                    }
                    .padding(Spacing.lg)
                }
            }
            .navigationTitle("")
            .goldTitle("Edit Gift")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.warmGray)
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .keyboard) {
                    Button(action: {
                        HapticManager.buttonTapped()
                        focusedField = nil
                    }) {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.forestGreen)
                            .padding(12)
                            .background(Color.white.opacity(0.9))
                            .clipShape(Circle())
                    }
                }
            }
            .onAppear {
                checkClipboard()
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {
                    showErrorAlert = false
                }
            } message: {
                if let errorMessage = errorAlertMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    private func checkClipboard() {
        clipboardHasContent = UIPasteboard.general.hasStrings
    }

    private func saveItem() {
        isSaving = true

        Task {
            do {
                item.updateRecord()
                try await cloudKit.updateWishlistItem(item.record)
                onItemUpdated(item)
                dismiss()
            } catch {
                print("❌ Error updating item: \(error)")
                
                // Extract user-friendly error message
                if let ckError = error as? CKError {
                    errorAlertMessage = ckError.userFriendlyMessage
                } else {
                    errorAlertMessage = error.localizedDescription
                }
                
                showErrorAlert = true
                isSaving = false
            }
        }
    }

    private func deleteItem() {
        isSaving = true

        Task {
            do {
                try await cloudKit.deleteWishlistItem(item.record.recordID)
                HapticManager.itemDeleted()
                onItemDeleted?(item.id)
                dismiss()
            } catch {
                print("❌ Error deleting item: \(error)")
                
                // Extract user-friendly error message
                if let ckError = error as? CKError {
                    errorAlertMessage = ckError.userFriendlyMessage
                } else {
                    errorAlertMessage = error.localizedDescription
                }
                
                showErrorAlert = true
                isSaving = false
            }
        }
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.image = originalImage
            }

            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    CloudKitAddGiftView(ownerRecordID: nil, ownerName: "Me", onItemAdded: { _ in })
}
