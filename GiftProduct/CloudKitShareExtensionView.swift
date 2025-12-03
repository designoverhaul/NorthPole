//
//  CloudKitShareExtensionView.swift
//  GiftProduct
//
//  Created by Claude Code
//

import SwiftUI
import CloudKit
import UniformTypeIdentifiers
import UIKit

struct CloudKitShareExtensionView: View {
    let extensionContext: NSExtensionContext?

    @StateObject private var cloudKit = CloudKitManager.shared
    @State private var name: String = ""
    @State private var url: String = ""
    @State private var description: String = ""
    @State private var imageData: Data?
    @State private var isLoading = true
    @State private var isSaving = false
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
                    VStack(spacing: 16) {
                        Text("❄️")
                            .font(.system(size: 36))
                        Text("Loading...")
                            .font(.body)
                            .foregroundColor(.warmGray)
                        Text("Extracting product info...")
                            .font(.caption)
                            .foregroundColor(.warmGray)
                    }
                } else if !cloudKit.isSignedInToiCloud {
                    notSignedInView
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
                                    if isSaving {
                                        Text("❄️")
                                            .font(.system(size: 20))
                                    }
                                    Spacer()
                                    Text(isSaving ? "Saving..." : "Add to Wishlist")
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                            .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving ? 0.5 : 1.0)
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
                    .disabled(isSaving)
                }
            }
        }
        .task {
            await cloudKit.checkiCloudStatus()
            await loadSharedContent()
        }
    }

    private var notSignedInView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 60))
                .foregroundColor(.warmGrayLight)

            Text("Not signed in to iCloud")
                .font(.headingMedium)
                .foregroundColor(.warmGray)

            Text("Please sign in to iCloud in Settings")
                .font(.bodyMedium)
                .foregroundColor(.warmGray)

            Button("Cancel") {
                cancel()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding()
    }

    private func loadSharedContent() async {
        print("🎁 CloudKit Share: loadSharedContent started")

        guard let extensionContext = extensionContext else {
            print("❌ CloudKit Share: extensionContext is nil")
            isLoading = false
            return
        }

        guard let item = extensionContext.inputItems.first as? NSExtensionItem else {
            print("❌ CloudKit Share: No input items found")
            isLoading = false
            return
        }

        print("🎁 CloudKit Share: Found input item")

        // Get attachments
        guard let attachments = item.attachments else {
            print("❌ CloudKit Share: No attachments found")
            isLoading = false
            return
        }

        print("🎁 CloudKit Share: Found \(attachments.count) attachments")

        await withTaskGroup(of: Void.self) { group in
            // Try to get URL
            for attachment in attachments {
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    group.addTask {
                        do {
                            let url = try await attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) as? URL
                            if let url = url {
                                await MainActor.run {
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
                        } catch {
                            print("❌ Error loading URL: \(error)")
                        }
                    }
                }

                // Try to get text (might contain title)
                if attachment.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                    group.addTask {
                        do {
                            let text = try await attachment.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) as? String
                            if let text = text, await self.name.isEmpty {
                                await MainActor.run {
                                    let lines = text.components(separatedBy: .newlines)
                                    if let firstLine = lines.first, !firstLine.isEmpty {
                                        self.name = String(firstLine.prefix(100))
                                    }
                                }
                            }
                        } catch {
                            print("❌ Error loading text: \(error)")
                        }
                    }
                }

                // Try to get image
                if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    group.addTask {
                        do {
                            if let data = try await attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) as? Data {
                                await MainActor.run {
                                    self.imageData = data
                                }
                            }
                        } catch {
                            print("❌ Error loading image: \(error)")
                        }
                    }
                }
            }
        }

        await MainActor.run {
            print("🎁 CloudKit Share: Content loading completed")
            print("🎁 CloudKit Share: Name: \(self.name)")
            print("🎁 CloudKit Share: URL: \(self.url)")
            self.isLoading = false
            self.focusedField = .name
        }
    }

    private func addItem() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isSaving = true
        print("🎁 CloudKit Share: Saving item to CloudKit...")

        Task {
            do {
                _ = try await cloudKit.saveWishlistItem(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    url: url.isEmpty ? nil : url,
                    description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
                    imageData: imageData
                )

                print("🎁 CloudKit Share: Item saved successfully!")
                HapticManager.itemAdded()

                // Close extension
                await MainActor.run {
                    extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                }
            } catch {
                print("❌ CloudKit Share: Error saving: \(error)")
                await MainActor.run {
                    isSaving = false
                    // TODO: Show error alert
                }
            }
        }
    }

    private func cancel() {
        print("🎁 CloudKit Share: User cancelled")
        extensionContext?.cancelRequest(withError: NSError(domain: "ShareExtension", code: 0, userInfo: nil))
    }
}
