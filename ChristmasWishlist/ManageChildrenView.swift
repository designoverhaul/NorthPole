//
//  ManageChildrenView.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI
import CloudKit
import SwiftData

struct ManageChildrenView: View {
    @ObservedObject private var cloudKit = CloudKitManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var children: [CKChild] = []
    @State private var isLoading = false
    @State private var isAdding = false
    @State private var newChildName = ""
    @State private var showingAddSheet = false
    @State private var error: CloudKitError?
    @State private var showingError = false
    @State private var childToDelete: CKChild?
    @State private var showingDeleteConfirmation = false
    @State private var currentUserId: UUID = {
        if let existingId = AppGroupContainer.getCurrentUserId() {
            return existingId
        } else {
            let newId = UUID()
            AppGroupContainer.saveCurrentUserId(newId)
            return newId
        }
    }()

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
            let records = try await cloudKit.fetchMyChildren()
            await MainActor.run {
                children = records.map { CKChild(from: $0) }
                print("✅ [MANAGE_CHILDREN] Loaded \(children.count) children from CloudKit")
            }
        } catch let error as CKError where error.code == .unknownItem {
            // Record type doesn't exist yet - this is normal on first run
            print("☁️ [MANAGE_CHILDREN] Child record type not created yet")
            await MainActor.run {
                children = []
            }
        } catch {
            print("❌ [MANAGE_CHILDREN] Error loading children: \(error)")
            await MainActor.run {
                // Don't show error for unknown record type
                if let ckError = error as? CKError, ckError.code != .unknownItem {
                    self.error = error as? CloudKitError
                    showingError = true
                }
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
                let record = try await cloudKit.saveChild(name: newChildName)
                let newChild = CKChild(from: record)
                
                children.append(newChild)
                children.sort { $0.name < $1.name }

                newChildName = ""
                // Don't dismiss - keep user on the add sheet so they can add more or manually navigate back
                HapticManager.itemAdded()
                
                print("✅ [MANAGE_CHILDREN] Added child '\(newChild.name)' (ID: \(newChild.id))")
                
                // Trigger refresh in other views
                cloudKit.shouldRefreshChildren.toggle()
                print("✅ [MANAGE_CHILDREN] Triggered shouldRefreshChildren")
            } catch {
                print("❌ [MANAGE_CHILDREN] Error adding child: \(error)")
                self.error = error as? CloudKitError
                showingError = true
                HapticManager.errorOccurred()
            }
            isAdding = false
        }
    }

    private func deleteChild(_ child: CKChild) {
        print("🗑️ [MANAGE_CHILDREN] Delete button tapped for child '\(child.name)'")
        
        Task { @MainActor in
            do {
                print("🗑️ [MANAGE_CHILDREN] Deleting child '\(child.name)' (ID: \(child.id)) from CloudKit...")
                
                // Delete from CloudKit (this also deletes all their wishlist items)
                try await cloudKit.deleteChild(child.record.recordID)
                print("✅ [MANAGE_CHILDREN] Successfully deleted from CloudKit")
                
                // Remove from local state
                children.removeAll { $0.id == child.id }
                print("✅ [MANAGE_CHILDREN] Removed from local state, now have \(children.count) children")

                // Trigger refresh in other views
                cloudKit.shouldRefreshChildren.toggle()
                print("✅ [MANAGE_CHILDREN] Triggered refresh")
                
                HapticManager.itemDeleted()
            } catch {
                print("❌ [MANAGE_CHILDREN] CloudKit delete failed: \(error)")
                
                // Reload children to restore UI if delete failed
                await loadChildren()
                
                self.error = error as? CloudKitError
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
