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
    @StateObject private var cloudKit = CloudKitManager.shared
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
                    ProgressView("Loading children...")
                        .tint(.forestGreen)
                } else {
                    List {
                        Section {
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
                        } footer: {
                            Text("Add children to manage their wishlists. When friends add you, they'll see your children too.")
                                .foregroundColor(.warmGray)
                                .font(.caption)
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
            children = records.map { CKChild(from: $0) }

            // Sync to SwiftData for local access
            await syncChildrenToSwiftData(children)
        } catch let error as CKError where error.code == .unknownItem {
            // Record type doesn't exist yet - this is normal on first run
            print("☁️ CloudKit: Child record type not created yet")
            children = []
        } catch {
            print("Error loading children: \(error)")
            // Don't show error for unknown record type
            if let ckError = error as? CKError, ckError.code != .unknownItem {
                self.error = error as? CloudKitError
                showingError = true
            }
        }
        isLoading = false
    }

    private func addChild() {
        guard !newChildName.isEmpty else { return }

        isAdding = true
        Task {
            do {
                let record = try await cloudKit.saveChild(name: newChildName)
                let newChild = CKChild(from: record)
                children.append(newChild)
                children.sort { $0.name < $1.name }

                // Save to SwiftData
                await addChildToSwiftData(newChild)

                newChildName = ""
                showingAddSheet = false
                HapticManager.itemAdded()

                // Small delay for CloudKit consistency
                try await Task.sleep(nanoseconds: 500_000_000)
            } catch {
                print("Error adding child: \(error)")
                self.error = error as? CloudKitError
                showingError = true
            }
            isAdding = false
        }
    }

    private func deleteChild(_ child: CKChild) {
        Task {
            do {
                try await cloudKit.deleteChild(child.record.recordID)
                children.removeAll { $0.id == child.id }

                // Remove from SwiftData
                await deleteChildFromSwiftData(childId: child.id)

                HapticManager.buttonTapped()
            } catch {
                print("Error deleting child: \(error)")
                self.error = error as? CloudKitError
                showingError = true
            }
        }
    }

    // MARK: - SwiftData Sync Helpers

    @MainActor
    private func syncChildrenToSwiftData(_ ckChildren: [CKChild]) async {
        // Fetch all existing SwiftData children for this user
        let descriptor = FetchDescriptor<Child>(
            predicate: #Predicate { $0.parentId == currentUserId }
        )

        do {
            let existingChildren = try modelContext.fetch(descriptor)

            // Create a set of CloudKit child IDs (as strings)
            let cloudKitChildIds = Set(ckChildren.map { $0.id })

            // Remove SwiftData children that no longer exist in CloudKit
            for existingChild in existingChildren {
                if !cloudKitChildIds.contains(existingChild.id.uuidString) {
                    modelContext.delete(existingChild)
                }
            }

            // Add or update children from CloudKit
            let existingChildIds = Set(existingChildren.map { $0.id.uuidString })

            for ckChild in ckChildren {
                if !existingChildIds.contains(ckChild.id) {
                    // New child - add to SwiftData
                    let newChild = Child(
                        id: UUID(uuidString: ckChild.id) ?? UUID(),
                        name: ckChild.name,
                        parentId: currentUserId,
                        createdAt: ckChild.createdAt
                    )
                    modelContext.insert(newChild)
                } else {
                    // Existing child - update name if changed
                    if let existingChild = existingChildren.first(where: { $0.id.uuidString == ckChild.id }) {
                        existingChild.name = ckChild.name
                    }
                }
            }

            try modelContext.save()
        } catch {
            print("Error syncing children to SwiftData: \(error)")
        }
    }

    @MainActor
    private func addChildToSwiftData(_ ckChild: CKChild) async {
        let newChild = Child(
            id: UUID(uuidString: ckChild.id) ?? UUID(),
            name: ckChild.name,
            parentId: currentUserId,
            createdAt: ckChild.createdAt
        )
        modelContext.insert(newChild)

        do {
            try modelContext.save()
        } catch {
            print("Error saving child to SwiftData: \(error)")
        }
    }

    @MainActor
    private func deleteChildFromSwiftData(childId: String) async {
        let descriptor = FetchDescriptor<Child>(
            predicate: #Predicate { child in
                child.id.uuidString == childId && child.parentId == currentUserId
            }
        )

        do {
            let childrenToDelete = try modelContext.fetch(descriptor)
            for child in childrenToDelete {
                modelContext.delete(child)
            }
            try modelContext.save()
        } catch {
            print("Error deleting child from SwiftData: \(error)")
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
                        ProgressView()
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
