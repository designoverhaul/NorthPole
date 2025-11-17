//
//  ProductImageDownloader.swift
//  ChristmasWishlist
//
//  Downloads and caches product images from extracted URLs.
//

import Foundation
import UIKit

/// Downloads and caches product images
@MainActor
class ProductImageDownloader {

    // MARK: - Singleton

    static let shared = ProductImageDownloader()
    private init() {}

    // MARK: - Properties

    /// In-memory cache for downloaded images
    private var imageCache: [String: UIImage] = [:]

    /// Maximum cache size (number of images)
    private let maxCacheSize = 20

    // MARK: - Public API

    /// Download an image from a URL and convert to JPEG data
    /// - Parameter urlString: The image URL to download
    /// - Returns: JPEG data at 0.7 compression, or nil if download failed
    func downloadImage(from urlString: String) async -> Data? {
        print("ProductImageDownloader: Attempting to download image from: \(urlString)")

        // Check cache first
        if let cachedImage = imageCache[urlString] {
            print("ProductImageDownloader: Found cached image")
            return cachedImage.jpegData(compressionQuality: 0.7)
        }

        // Validate URL
        guard let url = URL(string: urlString) else {
            print("ProductImageDownloader: Invalid URL - \(urlString)")
            return nil
        }

        // Download image
        guard let image = await fetchImage(from: url) else {
            print("ProductImageDownloader: Failed to download image")
            return nil
        }

        print("ProductImageDownloader: Successfully downloaded image (\(image.size.width)x\(image.size.height))")

        // Cache for future use
        cacheImage(image, for: urlString)

        // Convert to JPEG data (matching CloudKitAddGiftView's compression)
        return image.jpegData(compressionQuality: 0.7)
    }

    /// Download an image and return as UIImage
    /// - Parameter urlString: The image URL to download
    /// - Returns: UIImage or nil if download failed
    func downloadUIImage(from urlString: String) async -> UIImage? {
        // Check cache first
        if let cachedImage = imageCache[urlString] {
            return cachedImage
        }

        // Validate URL
        guard let url = URL(string: urlString) else {
            print("ProductImageDownloader: Invalid URL - \(urlString)")
            return nil
        }

        // Download image
        guard let image = await fetchImage(from: url) else {
            return nil
        }

        // Cache for future use
        cacheImage(image, for: urlString)

        return image
    }

    // MARK: - Private Methods

    private func fetchImage(from url: URL) async -> UIImage? {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        do {
            let (data, _) = try await URLSession.shared.data(for: request)

            guard let image = UIImage(data: data) else {
                print("ProductImageDownloader: Failed to decode image from URL - \(url)")
                return nil
            }

            return image
        } catch {
            print("ProductImageDownloader: Failed to download image - \(error.localizedDescription)")
            return nil
        }
    }

    private func cacheImage(_ image: UIImage, for urlString: String) {
        // Enforce cache size limit
        if imageCache.count >= maxCacheSize {
            // Remove oldest entry (simple FIFO)
            if let firstKey = imageCache.keys.first {
                imageCache.removeValue(forKey: firstKey)
            }
        }

        imageCache[urlString] = image
    }

    // MARK: - Cache Management

    /// Clear all cached images
    func clearCache() {
        imageCache.removeAll()
    }

    /// Remove a specific image from cache
    func removeFromCache(urlString: String) {
        imageCache.removeValue(forKey: urlString)
    }
}
