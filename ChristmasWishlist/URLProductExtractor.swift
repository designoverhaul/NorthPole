//
//  URLProductExtractor.swift
//  ChristmasWishlist
//
//  URL-based product data extraction for auto-filling wishlist items.
//  Supports Open Graph tags and JSON-LD structured data.
//

import Foundation
import UIKit

/// Product data extracted from a URL
struct ProductData {
    var name: String?
    var imageURL: String?
    var description: String?
    var price: String?

    /// Whether any data was successfully extracted
    var hasData: Bool {
        name != nil || imageURL != nil || description != nil || price != nil
    }
}

/// Extracts product information from product URLs
@MainActor
class URLProductExtractor {

    // MARK: - Public API

    /// Extract product data from a URL
    /// - Parameter urlString: The product URL to extract from
    /// - Returns: ProductData with whatever fields could be extracted
    static func extract(from urlString: String) async -> ProductData {
        // Validate and normalize URL
        guard let url = normalizeURL(urlString) else {
            print("URLProductExtractor: Invalid URL - \(urlString)")
            return ProductData()
        }

        // Fetch HTML content
        guard let html = await fetchHTML(from: url) else {
            return ProductData()
        }

        // Parse Open Graph tags
        var data = parseOpenGraph(html: html, baseURL: url)

        // Parse JSON-LD structured data for price
        if let price = parseJSONLD(html: html) {
            data.price = price
        }

        // Debug logging
        print("URLProductExtractor: Extracted data:")
        print("  - Name: \(data.name ?? "nil")")
        print("  - Image URL: \(data.imageURL ?? "nil")")
        print("  - Description: \(data.description ?? "nil")")
        print("  - Price: \(data.price ?? "nil")")

        return data
    }

    // MARK: - URL Normalization

    private static func normalizeURL(_ urlString: String) -> URL? {
        var cleaned = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Add https:// if no scheme
        if !cleaned.lowercased().hasPrefix("http://") && !cleaned.lowercased().hasPrefix("https://") {
            cleaned = "https://" + cleaned
        }

        return URL(string: cleaned)
    }

    // MARK: - HTML Fetching

    private static func fetchHTML(from url: URL) async -> String? {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return String(data: data, encoding: .utf8)
        } catch {
            print("URLProductExtractor: Failed to fetch URL - \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Open Graph Parsing

    private static func parseOpenGraph(html: String, baseURL: URL) -> ProductData {
        var data = ProductData()

        // Extract Open Graph meta tags
        let ogTags = extractMetaTags(from: html, prefix: "og:")

        // Title
        if let title = ogTags["og:title"] {
            data.name = cleanText(title)
        }

        // Image - convert relative URLs to absolute
        if let imageURLString = ogTags["og:image"] {
            data.imageURL = absoluteURL(from: imageURLString, baseURL: baseURL)
        }

        // Description
        if let description = ogTags["og:description"] {
            data.description = cleanText(description)
        }

        // Fallback to standard meta tags if OG not found
        if data.name == nil {
            let standardTags = extractMetaTags(from: html, prefix: "")
            if let title = standardTags["title"] {
                data.name = cleanText(title)
            }
        }

        if data.description == nil {
            let standardTags = extractMetaTags(from: html, prefix: "")
            if let description = standardTags["description"] {
                data.description = cleanText(description)
            }
        }

        // Fallback: Try to find image in standard meta tags
        if data.imageURL == nil {
            let standardTags = extractMetaTags(from: html, prefix: "")
            if let imageURLString = standardTags["image"] {
                data.imageURL = absoluteURL(from: imageURLString, baseURL: baseURL)
            }
        }

        return data
    }

    /// Convert a potentially relative URL to an absolute URL
    private static func absoluteURL(from urlString: String, baseURL: URL) -> String {
        // Already absolute
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return urlString
        }

        // Protocol-relative URL (//example.com/image.jpg)
        if urlString.hasPrefix("//") {
            return "https:" + urlString
        }

        // Relative URL - construct absolute URL
        if urlString.hasPrefix("/") {
            // Absolute path (e.g., /images/product.jpg)
            if let scheme = baseURL.scheme, let host = baseURL.host {
                return "\(scheme)://\(host)\(urlString)"
            }
        } else {
            // Relative path (e.g., images/product.jpg)
            if let scheme = baseURL.scheme, let host = baseURL.host {
                let path = baseURL.path
                let basePath = (path as NSString).deletingLastPathComponent
                return "\(scheme)://\(host)\(basePath)/\(urlString)"
            }
        }

        // Fallback: return as-is
        return urlString
    }

    private static func extractMetaTags(from html: String, prefix: String) -> [String: String] {
        var tags: [String: String] = [:]

        // Pattern for meta tags: <meta property="og:title" content="Product Name">
        // Also supports <meta name="description" content="...">
        let patterns = [
            #"<meta\s+property=["\'](\#(prefix)[^"\']+)["\']\s+content=["\']([^"\']+)["\']"#,
            #"<meta\s+content=["\']([^"\']+)["\']\s+property=["\'](\#(prefix)[^"\']+)["\']"#,
            #"<meta\s+name=["\']([^"\']+)["\']\s+content=["\']([^"\']+)["\']"#,
            #"<meta\s+content=["\']([^"\']+)["\']\s+name=["\']([^"\']+)["\']"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let nsString = html as NSString
                let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsString.length))

                for match in matches {
                    if match.numberOfRanges == 3 {
                        let key = nsString.substring(with: match.range(at: 1))
                        let value = nsString.substring(with: match.range(at: 2))

                        // For name/content pattern, swap if needed
                        if pattern.contains("name=") && prefix.isEmpty {
                            tags[key] = value
                        } else if pattern.contains("property=") {
                            tags[key] = value
                        }
                    }
                }
            }
        }

        return tags
    }

    // MARK: - JSON-LD Parsing

    private static func parseJSONLD(html: String) -> String? {
        // Extract JSON-LD script tag: <script type="application/ld+json">
        guard let regex = try? NSRegularExpression(
            pattern: #"<script[^>]*type=["\']application/ld\+json["\'][^>]*>(.*?)</script>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return nil
        }

        let nsString = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsString.length))

        for match in matches {
            if match.numberOfRanges == 2 {
                let jsonString = nsString.substring(with: match.range(at: 1))

                if let price = extractPrice(from: jsonString) {
                    return price
                }
            }
        }

        return nil
    }

    private static func extractPrice(from jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Common JSON-LD price locations
        if let offers = json["offers"] as? [String: Any],
           let price = offers["price"] as? Double ?? Double(offers["price"] as? String ?? "") {
            let currency = offers["priceCurrency"] as? String ?? "USD"
            return formatPrice(price, currency: currency)
        }

        if let offers = json["offers"] as? [[String: Any]],
           let firstOffer = offers.first,
           let price = firstOffer["price"] as? Double ?? Double(firstOffer["price"] as? String ?? "") {
            let currency = firstOffer["priceCurrency"] as? String ?? "USD"
            return formatPrice(price, currency: currency)
        }

        return nil
    }

    private static func formatPrice(_ price: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: price)) ?? "$\(String(format: "%.2f", price))"
    }

    // MARK: - Text Cleaning

    private static func cleanText(_ text: String) -> String {
        // Remove HTML entities
        var cleaned = text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&#39;", with: "'")

        // Trim whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Collapse multiple spaces
        while cleaned.contains("  ") {
            cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        }

        return cleaned
    }
}
