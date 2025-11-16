//
//  ShareExtensionView.swift
//  ShareExtension
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

struct ShareExtensionView: View {
    let extensionContext: NSExtensionContext?

    @Environment(\.modelContext) private var modelContext
    @State private var name: String = ""
    @State private var url: String = ""
    @State private var description: String = ""
    @State private var imageData: Data?
    @State private var isLoading = true
    @State private var currentUserId = UUID() // Will be loaded from UserDefaults
    @FocusState private var focusedField: Field?

    enum Field {
        case name, description
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamBackground
                    .ignoresSafeArea()

                if isLoading {
                    VStack {
                        ProgressView("Loading...")
                            .tint(.forestGreen)
                        Text("Debug: Loading shared content...")
                            .font(.caption)
                            .foregroundColor(.warmGray)
                            .padding(.top)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: Spacing.lg) {
                            // Preview image if available
                            if let imageData = imageData,
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 200)
                                    .cornerRadius(CornerRadius.md)
                                    .shadow(
                                        color: DesignShadow.medium,
                                        radius: 8,
                                        x: 0,
                                        y: 4
                                    )
                            }

                            // Name field (editable)
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Text("Item Name")
                                    .font(.bodyMedium)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.warmBlack)

                                TextField("Enter item name", text: $name)
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

                            // URL (read-only, from share)
                            if !url.isEmpty {
                                VStack(alignment: .leading, spacing: Spacing.sm) {
                                    Text("Link")
                                        .font(.bodyMedium)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.warmBlack)

                                    Text(url)
                                        .font(.caption)
                                        .foregroundColor(.warmGray)
                                        .padding(Spacing.md)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.warmGrayLight.opacity(0.2))
                                        .cornerRadius(CornerRadius.md)
                                        .lineLimit(2)
                                }
                            }

                            // Description field (optional)
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                HStack {
                                    Text("Notes")
                                        .font(.bodyMedium)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.warmBlack)

                                    Text("(Optional)")
                                        .font(.caption)
                                        .foregroundColor(.warmGray)
                                }

                                TextField("Add any notes...", text: $description, axis: .vertical)
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

                            // Add button
                            Button(action: addItem) {
                                HStack {
                                    Spacer()
                                    Text("Add to Wishlist")
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
                        }
                        .padding(Spacing.lg)
                    }
                }
            }
            .navigationTitle("Add to Wishlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cancel()
                    }
                    .foregroundColor(.warmGray)
                }
            }
        }
        .onAppear {
            print("🎁 ShareExtensionView: onAppear called")
            loadCurrentUser()
            loadSharedContent()
        }
    }

    private func loadCurrentUser() {
        print("🎁 ShareExtensionView: loadCurrentUser started")
        // Load user ID from shared UserDefaults (App Group)
        if let userId = AppGroupContainer.getCurrentUserId() {
            print("🎁 ShareExtensionView: Found existing user ID: \(userId)")
            currentUserId = userId
        } else {
            // Create new user ID if none exists
            let newId = UUID()
            print("🎁 ShareExtensionView: Creating new user ID: \(newId)")
            AppGroupContainer.saveCurrentUserId(newId)
            currentUserId = newId
        }
    }

    private func loadSharedContent() {
        print("🎁 ShareExtensionView: loadSharedContent started")

        guard let extensionContext = extensionContext else {
            print("❌ ShareExtensionView: extensionContext is nil")
            ImportLogger.log(attempt: ImportAttempt(
                success: false,
                errorMessage: "Extension context is nil"
            ))
            isLoading = false
            return
        }

        guard let item = extensionContext.inputItems.first as? NSExtensionItem else {
            print("❌ ShareExtensionView: No input items found")
            ImportLogger.log(attempt: ImportAttempt(
                success: false,
                errorMessage: "No input items found"
            ))
            isLoading = false
            return
        }

        print("🎁 ShareExtensionView: Found input item")

        // Get attachments
        guard let attachments = item.attachments else {
            print("❌ ShareExtensionView: No attachments found")
            ImportLogger.log(attempt: ImportAttempt(
                success: false,
                errorMessage: "No attachments found"
            ))
            isLoading = false
            return
        }

        print("🎁 ShareExtensionView: Found \(attachments.count) attachments")
        let group = DispatchGroup()
        let attachmentCount = attachments.count

        // Try to get URL
        for attachment in attachments {
            if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                group.enter()
                attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { data, error in
                    if let url = data as? URL {
                        DispatchQueue.main.async {
                            self.url = url.absoluteString
                            // Try to extract title from URL
                            if self.name.isEmpty {
                                self.name = url.lastPathComponent
                                    .replacingOccurrences(of: "-", with: " ")
                                    .replacingOccurrences(of: "_", with: " ")
                                    .capitalized
                            }
                        }
                    }
                    group.leave()
                }
            }

            // Try to get text (might contain title)
            if attachment.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                group.enter()
                attachment.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { data, error in
                    if let text = data as? String, self.name.isEmpty {
                        DispatchQueue.main.async {
                            // Use first line as name if available
                            let lines = text.components(separatedBy: .newlines)
                            if let firstLine = lines.first, !firstLine.isEmpty {
                                self.name = String(firstLine.prefix(100))
                            }
                        }
                    }
                    group.leave()
                }
            }

            // Try to get image
            if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                group.enter()
                attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { data, error in
                    if let url = data as? URL,
                       let imageData = try? Data(contentsOf: url) {
                        DispatchQueue.main.async {
                            self.imageData = imageData
                        }
                    } else if let image = data as? UIImage {
                        DispatchQueue.main.async {
                            self.imageData = image.jpegData(compressionQuality: 0.7)
                        }
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            print("🎁 ShareExtensionView: Content loading completed")
            print("🎁 ShareExtensionView: Name: \(self.name)")
            print("🎁 ShareExtensionView: URL: \(self.url)")

            // Log the import attempt (initially as loading completed)
            ImportLogger.log(attempt: ImportAttempt(
                url: self.url.isEmpty ? nil : self.url,
                extractedName: self.name.isEmpty ? nil : self.name,
                success: true, // We got this far
                errorMessage: nil,
                attachmentCount: attachmentCount
            ))

            self.isLoading = false
            self.focusedField = .name
        }
    }

    private func addItem() {
        print("🎁 ShareExtensionView: addItem called")
        HapticManager.itemAdded()

        let newItem = WishlistItem(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            url: url.isEmpty ? nil : url,
            itemDescription: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
            ownerId: currentUserId
        )

        modelContext.insert(newItem)

        do {
            try modelContext.save()
            print("🎁 ShareExtensionView: Item saved successfully")

            // Log successful save
            ImportLogger.log(attempt: ImportAttempt(
                url: url.isEmpty ? nil : url,
                extractedName: name,
                success: true,
                errorMessage: nil,
                attachmentCount: 0
            ))
        } catch {
            print("❌ ShareExtensionView: Error saving item: \(error)")

            // Log save failure
            ImportLogger.log(attempt: ImportAttempt(
                url: url.isEmpty ? nil : url,
                extractedName: name,
                success: false,
                errorMessage: "Save failed: \(error.localizedDescription)",
                attachmentCount: 0
            ))
        }

        // Close extension
        print("🎁 ShareExtensionView: Closing extension")
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func cancel() {
        print("🎁 ShareExtensionView: User cancelled")
        extensionContext?.cancelRequest(withError: NSError(domain: "ShareExtension", code: 0, userInfo: nil))
    }
}
