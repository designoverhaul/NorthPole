//
//  ImportLogger.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import Foundation

struct ImportAttempt: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let url: String?
    let extractedName: String?
    let success: Bool
    let errorMessage: String?
    let attachmentCount: Int

    init(
        url: String? = nil,
        extractedName: String? = nil,
        success: Bool,
        errorMessage: String? = nil,
        attachmentCount: Int = 0
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.url = url
        self.extractedName = extractedName
        self.success = success
        self.errorMessage = errorMessage
        self.attachmentCount = attachmentCount
    }

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

enum ImportLogger {
    private static let maxLogs = 100
    private static let logsKey = "importAttempts"

    static func log(attempt: ImportAttempt) {
        var attempts = getAllAttempts()
        attempts.insert(attempt, at: 0) // Add to beginning

        // Keep only the most recent maxLogs
        if attempts.count > maxLogs {
            attempts = Array(attempts.prefix(maxLogs))
        }

        // Save to shared UserDefaults
        if let encoded = try? JSONEncoder().encode(attempts),
           let defaults = AppGroupContainer.sharedDefaults {
            defaults.set(encoded, forKey: logsKey)
            defaults.synchronize()
        }

        // Also print to console
        print("📊 ImportLogger: \(attempt.success ? "✅ SUCCESS" : "❌ FAILED")")
        print("📊   URL: \(attempt.url ?? "none")")
        print("📊   Name: \(attempt.extractedName ?? "none")")
        print("📊   Attachments: \(attempt.attachmentCount)")
        if let error = attempt.errorMessage {
            print("📊   Error: \(error)")
        }
    }

    static func getAllAttempts() -> [ImportAttempt] {
        guard let defaults = AppGroupContainer.sharedDefaults,
              let data = defaults.data(forKey: logsKey),
              let attempts = try? JSONDecoder().decode([ImportAttempt].self, from: data) else {
            return []
        }
        return attempts
    }

    static func clearAllLogs() {
        AppGroupContainer.sharedDefaults?.removeObject(forKey: logsKey)
        AppGroupContainer.sharedDefaults?.synchronize()
        print("📊 ImportLogger: All logs cleared")
    }

    static func getSuccessRate() -> (successful: Int, failed: Int, total: Int) {
        let attempts = getAllAttempts()
        let successful = attempts.filter { $0.success }.count
        let failed = attempts.filter { !$0.success }.count
        return (successful, failed, attempts.count)
    }
}
