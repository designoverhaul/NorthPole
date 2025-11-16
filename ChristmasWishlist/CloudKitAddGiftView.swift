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
    @StateObject private var cloudKit = CloudKitManager.shared

    let onItemAdded: () -> Void

    @State private var name = ""
    @State private var url = ""
    @State private var description = ""
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var isSaving = false
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
                        // Name field
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
                        }

                        // URL field
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack {
                                Text("Link")
                                    .font(.bodyMedium)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.warmBlack)

                                Text("(Optional)")
                                    .font(.caption)
                                    .foregroundColor(.warmGray)
                            }

                            TextField("https://example.com/product", text: $url)
                                .font(.bodyMedium)
                                .foregroundColor(.warmBlack)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                                .padding(Spacing.md)
                                .background(Color.white)
                                .cornerRadius(CornerRadius.md)
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.md)
                                        .stroke(focusedField == .url ? Color.forestGreen : Color.warmGrayLight, lineWidth: 2)
                                )
                                .focused($focusedField, equals: .url)
                        }

                        // Description field
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack {
                                Text("Description")
                                    .font(.bodyMedium)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.warmBlack)

                                Text("(Optional)")
                                    .font(.caption)
                                    .foregroundColor(.warmGray)
                            }

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
                            HStack {
                                Text("Photo")
                                    .font(.bodyMedium)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.warmBlack)

                                Text("(Optional)")
                                    .font(.caption)
                                    .foregroundColor(.warmGray)
                            }

                            if let selectedImage = selectedImage {
                                // Show selected image
                                VStack(spacing: Spacing.sm) {
                                    Image(uiImage: selectedImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 200)
                                        .cornerRadius(CornerRadius.md)
                                        .clipped()

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
                                    HStack {
                                        Image(systemName: "photo.badge.plus")
                                            .font(.system(size: 24))

                                        Text("Add Photo")
                                            .font(.bodyMedium)
                                            .fontWeight(.medium)
                                    }
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
                                    ProgressView()
                                        .tint(.white)
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
            .goldTitle("Add Gift")
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
            }
            .onAppear {
                focusedField = .name
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage)
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

                _ = try await cloudKit.saveWishlistItem(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    url: url.isEmpty ? nil : url.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
                    imageData: imageData
                )

                onItemAdded()
                dismiss()
            } catch {
                print("❌ Error saving item: \(error)")
                // TODO: Show error alert
                isSaving = false
            }
        }
    }
}

// MARK: - CloudKit Edit Gift View

struct CloudKitEditGiftView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cloudKit = CloudKitManager.shared

    @State var item: CKWishlistItem
    let onItemUpdated: () -> Void

    @State private var isSaving = false
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
                            Text("Item Name")
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

                            TextField("https://example.com/product", text: Binding(
                                get: { item.url ?? "" },
                                set: { item.url = $0.isEmpty ? nil : $0 }
                            ))
                                .font(.bodyMedium)
                                .foregroundColor(.warmBlack)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                                .padding(Spacing.md)
                                .background(Color.white)
                                .cornerRadius(CornerRadius.md)
                                .focused($focusedField, equals: .url)
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
                                    ProgressView()
                                        .tint(.white)
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
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle(isDestructive: true))
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
            }
        }
    }

    private func saveItem() {
        isSaving = true

        Task {
            do {
                item.updateRecord()
                try await cloudKit.updateWishlistItem(item.record)
                onItemUpdated()
                dismiss()
            } catch {
                print("❌ Error updating item: \(error)")
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
                onItemUpdated()
                dismiss()
            } catch {
                print("❌ Error deleting item: \(error)")
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
    CloudKitAddGiftView(onItemAdded: {})
}
