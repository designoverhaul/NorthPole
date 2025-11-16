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

    @State private var name = ""
    @State private var url = ""
    @State private var description = ""
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
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
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
                        }

                        // URL field (optional)
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

                        // Description field (optional)
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
            }
        }
    }

    private func saveItem() {
        guard isFormValid else { return }

        HapticManager.itemAdded()

        if let existingItem = itemToEdit {
            // Update existing item
            existingItem.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            existingItem.url = url.isEmpty ? nil : url.trimmingCharacters(in: .whitespacesAndNewlines)
            existingItem.itemDescription = description.isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // Create new item
            let newItem = WishlistItem(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                url: url.isEmpty ? nil : url.trimmingCharacters(in: .whitespacesAndNewlines),
                itemDescription: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
                ownerId: userId
            )
            modelContext.insert(newItem)
        }

        onItemAdded()

        dismiss()
    }
}

#Preview {
    AddGiftView(userId: UUID(), onItemAdded: {})
        .modelContainer(for: [WishlistItem.self])
}
