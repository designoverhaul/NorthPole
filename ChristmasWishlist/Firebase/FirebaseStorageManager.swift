//
//  FirebaseStorageManager.swift
//  ChristmasWishlist
//
//  Created by Claude Code on 12/10/24.
//

import Foundation
import Combine
import FirebaseStorage
import UIKit
import OSLog

private let logger = Logger(subsystem: "com.designoverhaul.ChristmasWishlist", category: "FirebaseStorage")

@MainActor
class FirebaseStorageManager: ObservableObject {
    static let shared = FirebaseStorageManager()

    private let storage = Storage.storage()
    private let maxImageSize: Int64 = 10 * 1024 * 1024 // 10 MB

    private init() {
        logger.info("✅ [STORAGE] FirebaseStorageManager initialized")
    }

    // MARK: - Image Upload

    /// Upload wishlist item image to Firebase Storage
    /// Returns the download URL for the uploaded image
    func uploadWishlistItemImage(itemId: String, imageData: Data) async throws -> String {
        logger.info("📤 [STORAGE] Uploading image for item: \(itemId)")

        // Compress image if needed
        guard let compressedData = compressImage(imageData) else {
            throw StorageError.compressionFailed
        }

        let storageRef = storage.reference()
        let imageRef = storageRef.child("wishlist_images/\(itemId).jpg")

        // Upload metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        do {
            // Upload image data
            let _ = try await imageRef.putDataAsync(compressedData, metadata: metadata)
            logger.info("✅ [STORAGE] Image uploaded successfully")

            // Get download URL
            let downloadURL = try await imageRef.downloadURL()
            logger.info("🔗 [STORAGE] Download URL: \(downloadURL.absoluteString)")

            return downloadURL.absoluteString

        } catch {
            logger.error("❌ [STORAGE] Failed to upload image: \(error.localizedDescription)")
            throw error
        }
    }

    /// Upload user profile image to Firebase Storage
    func uploadProfileImage(userId: String, imageData: Data) async throws -> String {
        logger.info("📤 [STORAGE] Uploading profile image for user: \(userId)")

        guard let compressedData = compressImage(imageData) else {
            throw StorageError.compressionFailed
        }

        let storageRef = storage.reference()
        let imageRef = storageRef.child("profile_images/\(userId).jpg")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        do {
            let _ = try await imageRef.putDataAsync(compressedData, metadata: metadata)
            let downloadURL = try await imageRef.downloadURL()
            logger.info("✅ [STORAGE] Profile image uploaded: \(downloadURL.absoluteString)")
            return downloadURL.absoluteString
        } catch {
            logger.error("❌ [STORAGE] Failed to upload profile image: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Image Download

    /// Download image from Firebase Storage
    func downloadImage(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw StorageError.invalidURL
        }

        logger.info("📥 [STORAGE] Downloading image from: \(urlString)")

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            logger.info("✅ [STORAGE] Image downloaded: \(data.count) bytes")
            return data
        } catch {
            logger.error("❌ [STORAGE] Failed to download image: \(error.localizedDescription)")
            throw error
        }
    }

    /// Download image and return as UIImage
    func downloadUIImage(from urlString: String) async throws -> UIImage? {
        let data = try await downloadImage(from: urlString)
        return UIImage(data: data)
    }

    // MARK: - Image Deletion

    /// Delete wishlist item image from Firebase Storage
    func deleteWishlistItemImage(itemId: String) async throws {
        logger.info("🗑️ [STORAGE] Deleting image for item: \(itemId)")

        let storageRef = storage.reference()
        let imageRef = storageRef.child("wishlist_images/\(itemId).jpg")

        do {
            try await imageRef.delete()
            logger.info("✅ [STORAGE] Image deleted successfully")
        } catch {
            logger.error("❌ [STORAGE] Failed to delete image: \(error.localizedDescription)")
            throw error
        }
    }

    /// Delete profile image from Firebase Storage
    func deleteProfileImage(userId: String) async throws {
        logger.info("🗑️ [STORAGE] Deleting profile image for user: \(userId)")

        let storageRef = storage.reference()
        let imageRef = storageRef.child("profile_images/\(userId).jpg")

        do {
            try await imageRef.delete()
            logger.info("✅ [STORAGE] Profile image deleted")
        } catch {
            logger.error("❌ [STORAGE] Failed to delete profile image: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Helper Methods

    /// Compress image data to reduce file size
    private func compressImage(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else {
            logger.error("❌ [STORAGE] Failed to create UIImage from data")
            return nil
        }

        // Calculate compression quality based on size
        var compressionQuality: CGFloat = 0.8
        var compressedData = image.jpegData(compressionQuality: compressionQuality)

        // Keep reducing quality until under max size
        while let data = compressedData, data.count > maxImageSize, compressionQuality > 0.1 {
            compressionQuality -= 0.1
            compressedData = image.jpegData(compressionQuality: compressionQuality)
        }

        if let finalData = compressedData {
            logger.info("🗜️ [STORAGE] Compressed image: \(data.count) → \(finalData.count) bytes (quality: \(compressionQuality))")
            return finalData
        }

        logger.warning("⚠️ [STORAGE] Could not compress image sufficiently")
        return nil
    }

    /// Get image size from URL without downloading
    func getImageSize(from urlString: String) async throws -> Int64 {
        guard URL(string: urlString) != nil else {
            throw StorageError.invalidURL
        }

        let storageRef = storage.reference(forURL: urlString)

        do {
            let metadata = try await storageRef.getMetadata()
            return metadata.size
        } catch {
            logger.error("❌ [STORAGE] Failed to get image size: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Storage Errors

enum StorageError: LocalizedError {
    case compressionFailed
    case invalidURL
    case uploadFailed
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .invalidURL:
            return "Invalid image URL"
        case .uploadFailed:
            return "Failed to upload image"
        case .downloadFailed:
            return "Failed to download image"
        }
    }
}
