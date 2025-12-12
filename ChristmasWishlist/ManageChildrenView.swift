//
//  ManageChildrenView.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData

struct ManageChildrenView: View {
    @ObservedObject private var firebase = FirebaseManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Child.name) private var children: [Child]

    @State private var isLoading = false
    @State private var isAdding = false
    @State private var newChildName = ""
    @State private var showingAddSheet = false
    @State private var error: Error?
    @State private var showingError = false
    @State private var childToDelete: Child?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamBackground
                    .ignoresSafeArea()

                if isLoading {
                    SnowflakeLoadingView("Loading children...")
                } else {
                    List {
                        Section(header: Text("Add children to manage their wishlists. When friends add you, they'll see your children too.")
                            .foregroundColor(.warmGray)
                            .font(.caption)
                            .textCase(nil)
                            .padding(.bottom, 8)
                        ) {
                            if children.isEmpty {
                                Text("No children added yet")
                                    .foregroundColor(.warmGray)
                                    .italic()
                                    .listRowBackground(Color.creamCard)
                            } else {
                                ForEach(children) { child in
                                    HStack {
                                        Text(child.name)
                                            .foregroundColor(.warmBlack)
                                            .font(.body)

                                        Spacer()

                                        Button {
                                            childToDelete = child
                                            showingDeleteConfirmation = true
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .listRowBackground(Color.creamCard)
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Manage Children")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.forestGreen)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddChildSheet(
                    newChildName: $newChildName,
                    isAdding: $isAdding,
                    onAdd: addChild
                )
            }
            .alert("Delete Child", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let child = childToDelete {
                        deleteChild(child)
                    }
                }
            } message: {
                if let child = childToDelete {
                    Text("Are you sure you want to delete \(child.name)? This will also delete all their wishlist items.")
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let error = error {
                    Text(error.localizedDescription)
                }
            }
            .task {
                await loadChildren()
            }
        }
    }

    private func loadChildren() async {
        isLoading = true
        do {
            // Fetch children from Firebase (returns local immediately, syncs in background)
            _ = try await firebase.fetchMyChildren(context: modelContext)
            print("✅ [MANAGE_CHILDREN] Loaded children from Firebase")
        } catch {
            print("❌ [MANAGE_CHILDREN] Error loading children: \(error)")
            await MainActor.run {
                self.error = error
                showingError = true
            }
        }
        await MainActor.run {
            isLoading = false
        }
    }

    private func addChild() {
        guard !newChildName.isEmpty else { return }

        isAdding = true
        Task { @MainActor in
            do {
                print("➕ [MANAGE_CHILDREN] Adding child '\(newChildName)'...")

                // Save to Firebase (also saves to SwiftData)
                let childId = try await firebase.saveChild(name: newChildName)

                // Create local SwiftData child
                let newChild = Child(
                    name: newChildName,
                    parentId: UUID(), // Firebase will determine parent from auth
                    cloudKitRecordID: childId
                )
                modelContext.insert(newChild)
                try modelContext.save()

                newChildName = ""
                HapticManager.itemAdded()

                print("✅ [MANAGE_CHILDREN] Added child '\(newChild.name)'")

                // Trigger refresh in other views
                firebase.shouldRefreshChildren.toggle()
            } catch {
                print("❌ [MANAGE_CHILDREN] Error adding child: \(error)")
                self.error = error
                showingError = true
                HapticManager.errorOccurred()
            }
            isAdding = false
        }
    }

    private func deleteChild(_ child: Child) {
        print("🗑️ [MANAGE_CHILDREN] Delete button tapped for child '\(child.name)'")

        Task { @MainActor in
            do {
                print("🗑️ [MANAGE_CHILDREN] Deleting child '\(child.name)' from Firebase...")

                // Delete from Firebase (this also deletes all their wishlist items)
                if let firestoreId = child.cloudKitRecordID {
                    try await firebase.deleteChild(childId: firestoreId)
                }

                // Delete from local SwiftData
                modelContext.delete(child)
                try modelContext.save()

                print("✅ [MANAGE_CHILDREN] Successfully deleted child")

                // Trigger refresh in other views
                firebase.shouldRefreshChildren.toggle()

                HapticManager.itemDeleted()
            } catch {
                print("❌ [MANAGE_CHILDREN] Firebase delete failed: \(error)")

                // Reload children to restore UI if delete failed
                await loadChildren()

                self.error = error
                showingError = true
                HapticManager.errorOccurred()
            }
        }
    }

}

struct AddChildSheet: View {
    @Binding var newChildName: String
    @Binding var isAdding: Bool
    var onAdd: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamBackground
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    TextField("Child's name", text: $newChildName)
                        .textFieldStyle(.roundedBorder)
                        .padding()

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Add Child")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                        newChildName = ""
                    }
                    .foregroundColor(.forestGreen)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if isAdding {
                        Text("❄️")
                            .font(.system(size: 20))
                    } else {
                        Button("Add") {
                            onAdd()
                        }
                        .foregroundColor(.forestGreen)
                        .disabled(newChildName.isEmpty)
                    }
                }
            }
        }
    }
}

#Preview {
    ManageChildrenView()
}
