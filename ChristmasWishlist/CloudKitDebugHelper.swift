//
//  CloudKitDebugHelper.swift
//  ChristmasWishlist
//
//  Debug helper for troubleshooting wishlist visibility issues
//

import SwiftUI
import CloudKit
import SwiftData

struct CloudKitDebugView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Friend.name) private var friends: [Friend]
    
    @ObservedObject private var cloudKit = CloudKitManager.shared
    @State private var debugOutput: String = "Tap 'Run Debug' to start"
    @State private var isRunning = false
    @State private var testUserRecordID: String = ""
    
    // Force Link State
    @State private var selectedFriend: Friend?
    @State private var manualRecordID: String = ""
    @State private var showingForceLinkAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Current User Info
                    GroupBox("Current User") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Signed In: \(cloudKit.isSignedInToiCloud ? "✅ Yes" : "❌ No")")
                                if !cloudKit.isSignedInToiCloud {
                                    Button("Retry") {
                                        Task {
                                            await cloudKit.checkiCloudStatus()
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            
                            if let recordID = cloudKit.currentUserRecordID {
                                Text("Record ID:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(recordID.recordName)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Test Friend Visibility
                    GroupBox("Test Friend Visibility") {
                        VStack(spacing: 12) {
                            TextField("Friend's Record ID", text: $testUserRecordID)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.caption, design: .monospaced))
                            
                            Button(action: {
                                Task {
                                    await testFriendVisibility()
                                }
                            }) {
                                HStack {
                                    if isRunning {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                    Text("Test Visibility")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(testUserRecordID.isEmpty || isRunning)
                        }
                    }
                    
                    // Friends Connection Status
                    GroupBox("Friends Connection Status") {
                        VStack(spacing: 8) {
                            if friends.isEmpty {
                                Text("No friends added yet")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(friends) { friend in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(friend.name)
                                                .font(.subheadline)
                                                .fontWeight(.medium)

                                            if friend.hasApp, let recordID = friend.friendUserRecordID {
                                                Text(recordID)
                                                    .font(.system(.caption2, design: .monospaced))
                                                    .foregroundColor(.secondary)
                                            } else {
                                                Text("No connection")
                                                    .font(.caption)
                                                    .foregroundColor(.orange)
                                            }

                                            if let phone = friend.phoneNumber {
                                                Text("📱 \(phone)")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                            if let email = friend.email {
                                                Text("📧 \(email)")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }

                                        Spacer()

                                        if friend.hasApp {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                        } else {
                                            Button(action: {
                                                Task { await retryDiscovery(for: friend) }
                                            }) {
                                                Image(systemName: "arrow.clockwise")
                                                    .foregroundColor(.blue)
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                            .disabled(isRunning)
                                        }
                                    }
                                    .padding(.vertical, 4)

                                    if friend.id != friends.last?.id {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }

                    // Force Link Friend
                    GroupBox("Force Link Friend (Manual Override)") {
                        VStack(spacing: 12) {
                            Text("Use this if automatic discovery fails. Select a friend and paste their Record ID.")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Picker("Select Friend", selection: $selectedFriend) {
                                Text("Select a friend...").tag(nil as Friend?)
                                ForEach(friends) { friend in
                                    Text(friend.name).tag(friend as Friend?)
                                }
                            }

                            TextField("Record ID (e.g. _b8383...)", text: $manualRecordID)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.caption, design: .monospaced))

                            Button(action: {
                                showingForceLinkAlert = true
                            }) {
                                Text("Force Link Friend")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .disabled(selectedFriend == nil || manualRecordID.isEmpty)
                        }
                    }
                    
                    // Quick Actions
                    GroupBox("Quick Debug Actions") {
                        VStack(spacing: 8) {
                            Button("Check My Items") {
                                Task { await checkMyItems() }
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)

                            Button("Debug: Show ALL Items") {
                                Task { await debugShowAllItems() }
                            }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                            .frame(maxWidth: .infinity)
                            .disabled(isRunning)

                            Button("Check My Friends") {
                                Task { await checkMyFriends() }
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)

                            Button("Sync All Friends to CloudKit") {
                                Task { await syncAllFriendsToCloudKit() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .frame(maxWidth: .infinity)
                            .disabled(isRunning)

                            Button("Clean Stale Items") {
                                Task { await cleanStaleItems() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .frame(maxWidth: .infinity)
                            .disabled(isRunning)

                            Button("List All Subscriptions") {
                                Task { await listSubscriptions() }
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)

                            Button("Check Permissions") {
                                Task { await checkPermissions() }
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    
                    // Debug Output
                    GroupBox("Debug Output") {
                        ScrollView {
                            Text(debugOutput)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 300)
                    }
                    
                    // Copy Button
                    Button("Copy Output") {
                        UIPasteboard.general.string = debugOutput
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
                .padding()
            }
            .navigationTitle("CloudKit Debug")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Confirm Force Link", isPresented: $showingForceLinkAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Link", role: .destructive) {
                    forceLinkFriend()
                }
            } message: {
                if let friend = selectedFriend {
                    Text("Are you sure you want to link \(friend.name) to record ID:\n\n\(manualRecordID)\n\nThis will overwrite any existing link.")
                }
            }
            .onChange(of: selectedFriend) { _, newValue in
                if let friend = newValue, let recordID = friend.friendUserRecordID {
                    manualRecordID = recordID
                } else {
                    manualRecordID = ""
                }
            }
        }
    }
    
    private func retryDiscovery(for friend: Friend) async {
        isRunning = true
        clearLog()
        log("🔄 [RETRY] Retrying discovery for: \(friend.name)")

        guard cloudKit.isSignedInToiCloud else {
            log("❌ Not signed in to iCloud")
            isRunning = false
            return
        }

        let phoneNumbers = friend.phoneNumber.map { [$0] } ?? []
        let emails = friend.email.map { [$0] } ?? []

        log("📱 Phone numbers to try: \(phoneNumbers)")
        log("📧 Emails to try: \(emails)")

        if phoneNumbers.isEmpty && emails.isEmpty {
            log("⚠️ No phone or email on file for this friend")
            log("💡 Use 'Link to Contact' to add contact info first")
            isRunning = false
            return
        }

        do {
            if let recordID = try await cloudKit.discoverUser(
                phoneNumbers: phoneNumbers,
                emails: emails
            ) {
                log("✅ Discovery SUCCESS! Record ID: \(recordID.recordName)")

                await MainActor.run {
                    friend.friendUserRecordID = recordID.recordName
                    friend.hasApp = true
                    do {
                        try modelContext.save()
                        log("✅ Updated friend record")
                    } catch {
                        log("❌ Failed to save: \(error.localizedDescription)")
                    }
                }
            } else {
                log("❌ Discovery failed - user not found")
                log("")
                log("💡 Possible solutions:")
                log("1. Ask \(friend.name) to open the app at least once")
                log("   (Creates CloudKit user record)")
                log("2. Ask them to enable iCloud discovery:")
                log("   Settings > [Apple ID] > iCloud > 'Look Me Up by Email' ON")
                log("3. Check if phone/email matches their Apple ID")
                log("4. Ask them to share their Record ID:")
                log("   Settings > Debug CloudKit (in the app)")
            }
        } catch {
            log("❌ Error during discovery: \(error.localizedDescription)")
        }

        isRunning = false
    }

    private func forceLinkFriend() {
        guard let friend = selectedFriend else { return }

        // Update friend record
        friend.friendUserRecordID = manualRecordID
        friend.hasApp = !manualRecordID.isEmpty

        do {
            try modelContext.save()
            log("✅ Successfully linked \(friend.name) to \(manualRecordID)")

            // Trigger refresh
            Task {
                await cloudKit.checkiCloudStatus()
            }
        } catch {
            log("❌ Failed to save friend: \(error.localizedDescription)")
        }
    }
    
    private func log(_ message: String) {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        debugOutput += "\n[\(timestamp)] \(message)"
    }
    
    private func clearLog() {
        debugOutput = ""
    }
    
    private func checkMyItems() async {
        isRunning = true
        clearLog()
        log("🔍 Checking my wishlist items...")
        
        guard cloudKit.isSignedInToiCloud else {
            log("❌ Not signed in to iCloud")
            isRunning = false
            return
        }
        
        guard let myRecordID = cloudKit.currentUserRecordID else {
            log("❌ No user record ID")
            isRunning = false
            return
        }
        
        log("✅ My Record ID: \(myRecordID.recordName)")
        
        do {
            let items = try await cloudKit.fetchMyWishlistItems()
            log("✅ Found \(items.count) items")
            
            for (index, item) in items.enumerated() {
                let name = item["name"] as? String ?? "Unknown"
                let ownerID = item["ownerID"] as? String ?? "Unknown"
                let createdAt = item["createdAt"] as? Date ?? Date()
                
                log("\n📦 Item \(index + 1): \(name)")
                log("   ownerID: \(ownerID)")
                log("   created: \(createdAt.formatted())")
                log("   recordID: \(item.recordID.recordName)")
                
                // Check if ownerID matches
                if ownerID != myRecordID.recordName {
                    log("   ⚠️ WARNING: ownerID doesn't match my recordID!")
                }
            }
            
            if items.isEmpty {
                log("\nℹ️ No items found. Add some items to your wishlist first.")
            }
        } catch {
            log("❌ Error fetching items: \(error.localizedDescription)")
        }
        
        isRunning = false
    }
    
    private func testFriendVisibility() async {
        isRunning = true
        clearLog()
        log("🔍 Testing visibility for friend: \(testUserRecordID)")
        
        guard cloudKit.isSignedInToiCloud else {
            log("❌ Not signed in to iCloud")
            isRunning = false
            return
        }
        
        do {
            let items = try await cloudKit.fetchFriendWishlistItems(friendRecordID: testUserRecordID)
            log("✅ Found \(items.count) items for friend")
            
            if items.isEmpty {
                log("\n⚠️ No items found. Possible reasons:")
                log("   1. Friend has no wishlist items")
                log("   2. Record ID is incorrect")
                log("   3. CloudKit permissions not set correctly")
                log("   4. Items have different ownerID")
            } else {
                for (index, item) in items.enumerated() {
                    let name = item["name"] as? String ?? "Unknown"
                    let ownerID = item["ownerID"] as? String ?? "Unknown"
                    let createdAt = item["createdAt"] as? Date ?? Date()
                    
                    log("\n📦 Item \(index + 1): \(name)")
                    log("   ownerID: \(ownerID)")
                    log("   created: \(createdAt.formatted())")
                    
                    // Verify ownerID matches
                    if ownerID == testUserRecordID {
                        log("   ✅ ownerID matches!")
                    } else {
                        log("   ❌ ownerID mismatch! Expected: \(testUserRecordID)")
                    }
                }
            }
        } catch {
            log("❌ Error: \(error.localizedDescription)")
            if let ckError = error as? CKError {
                log("   CloudKit Error Code: \(ckError.code.rawValue)")
                log("   \(ckError)")
            }
        }
        
        isRunning = false
    }
    
    private func listSubscriptions() async {
        isRunning = true
        clearLog()
        log("🔍 Fetching active subscriptions...")
        
        do {
            let subscriptions = try await cloudKit.fetchAllSubscriptions()
            log("✅ Found \(subscriptions.count) subscriptions")
            
            for sub in subscriptions {
                log("\n📢 \(sub.subscriptionID)")
                if let querySub = sub as? CKQuerySubscription {
                    log("   Type: Query Subscription")
                    log("   Record Type: \(querySub.recordType ?? "Unknown")")
                    log("   Predicate: \(querySub.predicate)")
                }
            }
            
            if subscriptions.isEmpty {
                log("\nℹ️ No active subscriptions")
            }
        } catch {
            log("❌ Error: \(error.localizedDescription)")
        }
        
        isRunning = false
    }
    
    private func checkPermissions() async {
        isRunning = true
        clearLog()
        log("🔍 Checking CloudKit permissions...")
        log("\nℹ️ This check is limited. For full permission check:")
        log("   1. Go to icloud.developer.apple.com/dashboard")
        log("   2. Select: iCloud.com.designoverhaul.ChristmasWishlist")
        log("   3. Go to Schema → Security Roles")
        log("   4. Check WishlistItem permissions:")
        log("      - World: Read ✅")
        log("      - Authenticated: Read ✅")
        log("      - Creator: Write ✅")

        // Try to fetch a record to test read permissions
        do {
            let items = try await cloudKit.fetchMyWishlistItems()
            log("\n✅ Can read my items (\(items.count) found)")
        } catch {
            log("\n❌ Cannot read items: \(error.localizedDescription)")
        }

        isRunning = false
    }

    private func checkMyFriends() async {
        isRunning = true
        clearLog()
        log("🔍 Checking my friends in CloudKit...")

        guard cloudKit.isSignedInToiCloud else {
            log("❌ Not signed in to iCloud")
            isRunning = false
            return
        }

        guard let myRecordID = cloudKit.currentUserRecordID else {
            log("❌ No user record ID")
            isRunning = false
            return
        }

        log("✅ My Record ID: \(myRecordID.recordName)")

        do {
            let friendRecords = try await cloudKit.fetchMyFriends()
            log("✅ Found \(friendRecords.count) friends in CloudKit PRIVATE database")

            for (index, record) in friendRecords.enumerated() {
                let name = record["name"] as? String ?? "Unknown"
                let phoneNumber = record["phoneNumber"] as? String ?? ""
                let email = record["email"] as? String ?? ""
                let friendUserRecordID = record["friendUserRecordID"] as? String ?? ""
                let addedAt = record["addedAt"] as? Date ?? Date()

                log("\n👤 Friend \(index + 1): \(name)")
                log("   recordID: \(record.recordID.recordName)")
                log("   phone: \(phoneNumber.isEmpty ? "none" : phoneNumber)")
                log("   email: \(email.isEmpty ? "none" : email)")
                log("   friendUserRecordID: \(friendUserRecordID.isEmpty ? "none" : friendUserRecordID)")
                log("   added: \(addedAt.formatted())")
            }

            if friendRecords.isEmpty {
                log("\nℹ️ No friends found in CloudKit")
                log("   Add friends from Contacts to sync them to CloudKit")
            }
        } catch {
            log("❌ Error fetching friends: \(error.localizedDescription)")
        }

        isRunning = false
    }

    private func cleanStaleItems() async {
        isRunning = true
        clearLog()
        log("🧹 Checking for stale wishlist items...")

        guard cloudKit.isSignedInToiCloud else {
            log("❌ Not signed in to iCloud")
            isRunning = false
            return
        }

        guard let myRecordID = cloudKit.currentUserRecordID else {
            log("❌ No user record ID")
            isRunning = false
            return
        }

        log("✅ My Record ID: \(myRecordID.recordName)")

        do {
            let items = try await cloudKit.fetchMyWishlistItems()
            log("📦 Found \(items.count) items")

            var staleCount = 0
            var oldItems: [(record: CKRecord, age: TimeInterval)] = []

            // Find items older than 1 week that might be stale
            let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)

            for item in items {
                if let createdAt = item["createdAt"] as? Date {
                    let age = Date().timeIntervalSince(createdAt)
                    let daysOld = Int(age / (24 * 60 * 60))

                    if createdAt < oneWeekAgo {
                        oldItems.append((record: item, age: age))
                        log("\n⚠️ Old item found:")
                        log("   name: \(item["name"] as? String ?? "Unknown")")
                        log("   age: \(daysOld) days")
                        log("   created: \(createdAt.formatted())")
                        log("   ownerID: \(item["ownerID"] as? String ?? "Unknown")")
                    }
                }
            }

            if oldItems.isEmpty {
                log("\n✅ No stale items found!")
            } else {
                log("\n📊 Summary:")
                log("   Total items: \(items.count)")
                log("   Items > 7 days old: \(oldItems.count)")
                log("\nℹ️ These items are NOT automatically deleted.")
                log("   Review them manually and delete if needed.")
            }

        } catch {
            log("❌ Error checking items: \(error.localizedDescription)")
        }

        isRunning = false
    }

    private func debugShowAllItems() async {
        isRunning = true
        clearLog()
        log("🔍 DEBUG: Fetching ALL wishlist items from PUBLIC database...")

        guard cloudKit.isSignedInToiCloud else {
            log("❌ Not signed in to iCloud")
            isRunning = false
            return
        }

        guard let myRecordID = cloudKit.currentUserRecordID else {
            log("❌ No user record ID")
            isRunning = false
            return
        }

        log("✅ My Record ID: \(myRecordID.recordName)")
        log("")

        do {
            // Fetch ALL items (no filter) via CloudKitManager
            let allItems = try await cloudKit.fetchAllWishlistItems()

            log("📦 Found \(allItems.count) TOTAL items in PUBLIC database")
            log("")

            var myItemCount = 0
            var otherItemCount = 0

            for (index, item) in allItems.enumerated() {
                let name = item["name"] as? String ?? "Unknown"
                let ownerID = item["ownerID"] as? String ?? "Unknown"
                let createdAt = item["createdAt"] as? Date ?? Date()
                let recordName = item.recordID.recordName

                let isMine = ownerID == myRecordID.recordName

                if isMine {
                    myItemCount += 1
                    log("📦 [\(myItemCount)] MY ITEM: \(name)")
                } else {
                    otherItemCount += 1
                    log("🔸 [\(otherItemCount)] OTHER: \(name)")
                }

                log("   ownerID: \(ownerID)")
                log("   created: \(createdAt.formatted())")
                log("   recordID: \(recordName)")
                log("")
            }

            log("📊 Summary:")
            log("   MY items: \(myItemCount)")
            log("   OTHER items: \(otherItemCount)")
            log("   TOTAL: \(allItems.count)")

        } catch {
            log("❌ Error: \(error.localizedDescription)")
        }

        isRunning = false
    }

    private func syncAllFriendsToCloudKit() async {
        isRunning = true
        clearLog()
        log("🔄 Syncing all local friends to CloudKit...")

        guard cloudKit.isSignedInToiCloud else {
            log("❌ Not signed in to iCloud")
            isRunning = false
            return
        }

        // Count local vs CloudKit friends
        let localFriendsCount = friends.count
        log("📱 Local friends: \(localFriendsCount)")

        do {
            let cloudKitFriends = try await cloudKit.fetchMyFriends()
            log("☁️ CloudKit friends: \(cloudKitFriends.count)")

            if localFriendsCount == cloudKitFriends.count {
                log("\n✅ All friends already synced!")
                isRunning = false
                return
            }

            log("\n🔄 Syncing \(localFriendsCount - cloudKitFriends.count) missing friends...")

            // Get CloudKit record IDs that already exist
            let existingRecordIDs = Set(cloudKitFriends.map { $0.recordID.recordName })

            var syncedCount = 0
            for friend in friends {
                // Skip if already in CloudKit
                if let ckRecordID = friend.cloudKitRecordID, existingRecordIDs.contains(ckRecordID) {
                    log("⏭️ Skipping \(friend.name) - already in CloudKit")
                    continue
                }

                // Sync to CloudKit
                do {
                    log("\n📤 Syncing: \(friend.name)")
                    let savedRecord = try await cloudKit.saveFriend(
                        name: friend.name,
                        phoneNumber: friend.phoneNumber,
                        email: friend.email,
                        friendUserRecordID: friend.friendUserRecordID,
                        imageData: friend.imageData
                    )

                    // Update local friend with CloudKit record ID
                    friend.cloudKitRecordID = savedRecord.recordID.recordName
                    try? modelContext.save()

                    syncedCount += 1
                    log("✅ Synced: \(friend.name)")
                } catch {
                    log("❌ Failed to sync \(friend.name): \(error.localizedDescription)")
                }
            }

            log("\n🎉 Sync complete!")
            log("   Synced: \(syncedCount) friends")
            log("   Total in CloudKit: \(cloudKitFriends.count + syncedCount)")

        } catch {
            log("❌ Error: \(error.localizedDescription)")
        }

        isRunning = false
    }
}

// MARK: - Extension for CloudKitManager

extension CloudKitManager {
    /// Debug function to check wishlist visibility
    func debugWishlistVisibility(userRecordID: String) async -> String {
        var output = "🔍 [DEBUG] ===== WISHLIST VISIBILITY DEBUG =====\n"
        output += "🔍 [DEBUG] Current user: \(currentUserRecordID?.recordName ?? "nil")\n"
        output += "🔍 [DEBUG] Querying for user: \(userRecordID)\n\n"
        
        do {
            let items = try await fetchFriendWishlistItems(friendRecordID: userRecordID)
            output += "🔍 [DEBUG] Found \(items.count) items\n"
            
            for (index, item) in items.enumerated() {
                output += "\n📦 Item \(index + 1):\n"
                output += "   name: \(item["name"] ?? "?")\n"
                output += "   ownerID: \(item["ownerID"] ?? "?")\n"
                output += "   createdAt: \(item["createdAt"] ?? "?")\n"
                output += "   recordID: \(item.recordID.recordName)\n"
            }
            
            if items.isEmpty {
                output += "\n⚠️ No items found. Check:\n"
                output += "   1. Does user have items?\n"
                output += "   2. Is ownerID set correctly?\n"
                output += "   3. Are CloudKit permissions correct?\n"
            }
        } catch {
            output += "❌ [DEBUG] Error: \(error)\n"
            if let ckError = error as? CKError {
                output += "   Code: \(ckError.code.rawValue)\n"
            }
        }
        
        output += "\n🔍 [DEBUG] ===== END DEBUG =====\n"
        return output
    }
}

#Preview {
    CloudKitDebugView()
}
