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
        // Use desktop User-Agent for better meta tag support
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.timeoutInterval = 15

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else {
                print("URLProductExtractor: Failed to decode HTML")
                return nil
            }

            print("URLProductExtractor: Fetched HTML (\(html.count) chars)")

            // Debug: Print a sample of meta tags found
            let metaSample = html.components(separatedBy: "<meta").prefix(5).joined(separator: "\n<meta")
            print("URLProductExtractor: Sample meta tags:\n\(metaSample)")

            return html
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

        print("URLProductExtractor: Found \(ogTags.count) og: tags")

        // Title
        if let title = ogTags["og:title"] {
            data.name = cleanText(title)
        }

        // Image - convert relative URLs to absolute
        if let imageURLString = ogTags["og:image"] {
            print("URLProductExtractor: Found og:image = \(imageURLString)")
            data.imageURL = absoluteURL(from: imageURLString, baseURL: baseURL)
        }

        // Description
        if let description = ogTags["og:description"] {
            data.description = cleanText(description)
        }

        // Fallback to Twitter meta tags for image
        if data.imageURL == nil {
            let twitterTags = extractMetaTags(from: html, prefix: "twitter:")
            print("URLProductExtractor: Found \(twitterTags.count) twitter: tags")
            if let imageURLString = twitterTags["twitter:image"] {
                print("URLProductExtractor: Found twitter:image = \(imageURLString)")
                data.imageURL = absoluteURL(from: imageURLString, baseURL: baseURL)
            }
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
                print("URLProductExtractor: Found meta image = \(imageURLString)")
                data.imageURL = absoluteURL(from: imageURLString, baseURL: baseURL)
            }
        }

        // Last resort: Try itemprop="image"
        if data.imageURL == nil {
            if let imageURL = extractItempropImage(from: html, baseURL: baseURL) {
                print("URLProductExtractor: Found itemprop image = \(imageURL)")
                data.imageURL = imageURL
            }
        }

        // Final fallback: Look for main product images in common patterns
        if data.imageURL == nil {
            if let imageURL = extractMainProductImage(from: html, baseURL: baseURL) {
                print("URLProductExtractor: Found main product image = \(imageURL)")
                data.imageURL = imageURL
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

        // More flexible patterns that allow for any attributes between <meta and the key attributes
        // This handles cases like: <meta data-react-helmet="true" property="og:image" content="...">
        let patterns: [(String, String)] = [
            // property="..." content="..." (with any attributes in between)
            (#"<meta[^>]*?property=["\'](\#(prefix)[^"\']+)["\'][^>]*?content=["\']([^"\']+)["\']"#, "property"),
            // content="..." property="..." (reversed order)
            (#"<meta[^>]*?content=["\']([^"\']+)["\'][^>]*?property=["\'](\#(prefix)[^"\']+)["\']"#, "property-reverse"),
            // name="..." content="..." (for standard meta tags)
            (#"<meta[^>]*?name=["\']([^"\']+)["\'][^>]*?content=["\']([^"\']+)["\']"#, "name"),
            // content="..." name="..." (reversed)
            (#"<meta[^>]*?content=["\']([^"\']+)["\'][^>]*?name=["\']([^"\']+)["\']"#, "name-reverse")
        ]

        for (pattern, type) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                let nsString = html as NSString
                let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsString.length))

                for match in matches {
                    if match.numberOfRanges == 3 {
                        let firstCapture = nsString.substring(with: match.range(at: 1))
                        let secondCapture = nsString.substring(with: match.range(at: 2))

                        // Determine key and value based on pattern type
                        let (key, value) = type.hasSuffix("-reverse") ? (secondCapture, firstCapture) : (firstCapture, secondCapture)

                        // Only add if prefix matches or prefix is empty
                        if prefix.isEmpty || key.hasPrefix(prefix) {
                            tags[key] = value
                        }
                    }
                }
            }
        }

        return tags
    }

    /// Extract image from itemprop="image" attributes
    private static func extractItempropImage(from html: String, baseURL: URL) -> String? {
        // Pattern: <img itemprop="image" src="..." /> or <meta itemprop="image" content="..." />
        let patterns = [
            #"<img[^>]*?itemprop=["\']image["\'][^>]*?src=["\']([^"\']+)["\']"#,
            #"<meta[^>]*?itemprop=["\']image["\'][^>]*?content=["\']([^"\']+)["\']"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                let nsString = html as NSString
                if let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: nsString.length)),
                   match.numberOfRanges == 2 {
                    let imageURLString = nsString.substring(with: match.range(at: 1))
                    return absoluteURL(from: imageURLString, baseURL: baseURL)
                }
            }
        }

        return nil
    }

    /// Extract main product image from common e-commerce patterns
    private static func extractMainProductImage(from html: String, baseURL: URL) -> String? {
        // Amazon-specific patterns
        let amazonPatterns = [
            // data-old-hires attribute (high-res image)
            #"data-old-hires=["\']([^"\']+)["\']"#,
            // data-a-dynamic-image (contains JSON with image URLs)
            #"data-a-dynamic-image=["\'](\{[^\}]*?https?://[^\}]+\})["\']"#,
            // landingImage id
            #"id=["\']landingImage["\'][^>]*?src=["\']([^"\']+)["\']"#,
            // imgTagWrapper class
            #"class=["\'][^"\']*imgTagWrapper[^"\']*["\'][^>]*?<img[^>]*?src=["\']([^"\']+)["\']"#
        ]

        for pattern in amazonPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                let nsString = html as NSString
                if let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: nsString.length)),
                   match.numberOfRanges == 2 {
                    let imageURLString = nsString.substring(with: match.range(at: 1))

                    // If it's the dynamic-image JSON, extract the first URL
                    if imageURLString.hasPrefix("{") {
                        if let firstURL = extractFirstURLFromJSON(imageURLString) {
                            return absoluteURL(from: firstURL, baseURL: baseURL)
                        }
                    } else {
                        return absoluteURL(from: imageURLString, baseURL: baseURL)
                    }
                }
            }
        }

        // Generic patterns for other sites
        let genericPatterns = [
            // Large product images (common class names)
            #"class=["\'][^"\']*product[_-]?image[^"\']*["\'][^>]*?src=["\']([^"\']+)["\']"#,
            #"class=["\'][^"\']*main[_-]?image[^"\']*["\'][^>]*?src=["\']([^"\']+)["\']"#,
            // High-resolution images (often >500px)
            #"<img[^>]*?src=["\']([^"\']*(?:large|big|main|product)[^"\']*\.(?:jpg|jpeg|png|webp)[^"\']*)["\']"#
        ]

        for pattern in genericPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                let nsString = html as NSString
                if let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: nsString.length)),
                   match.numberOfRanges == 2 {
                    let imageURLString = nsString.substring(with: match.range(at: 1))
                    // Filter out tiny images (likely thumbnails/icons)
                    if !imageURLString.contains("icon") && !imageURLString.contains("thumb") {
                        return absoluteURL(from: imageURLString, baseURL: baseURL)
                    }
                }
            }
        }

        return nil
    }

    /// Extract first URL from Amazon's dynamic-image JSON format
    private static func extractFirstURLFromJSON(_ jsonString: String) -> String? {
        // Amazon's data-a-dynamic-image contains URLs as keys in JSON
        // Example: {"https://m.media-amazon.com/images/I/71abc.jpg":[500,500],"https://..."}
        if let regex = try? NSRegularExpression(pattern: #"(https?://[^"\']+\.(?:jpg|jpeg|png|webp))"#, options: [.caseInsensitive]) {
            let nsString = jsonString as NSString
            if let match = regex.firstMatch(in: jsonString, range: NSRange(location: 0, length: nsString.length)),
               match.numberOfRanges == 2 {
                return nsString.substring(with: match.range(at: 1))
            }
        }
        return nil
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

        print("URLProductExtractor: Found \(matches.count) JSON-LD blocks")

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
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        // Handle both single object and array of objects (some sites wrap in @graph)
        let objects: [[String: Any]]
        if let singleObject = json as? [String: Any] {
            objects = [singleObject]
        } else if let array = json as? [[String: Any]] {
            objects = array
        } else {
            return nil
        }

        // Search through all JSON-LD objects
        for object in objects {
            // Check if this is a Product type
            if let type = object["@type"] as? String, type.lowercased().contains("product") {
                if let price = extractPriceFromObject(object) {
                    return price
                }
            }

            // Also check nested @graph array
            if let graph = object["@graph"] as? [[String: Any]] {
                for item in graph {
                    if let type = item["@type"] as? String, type.lowercased().contains("product") {
                        if let price = extractPriceFromObject(item) {
                            return price
                        }
                    }
                }
            }
        }

        return nil
    }

    private static func extractPriceFromObject(_ object: [String: Any]) -> String? {
        // Single offers object
        if let offers = object["offers"] as? [String: Any] {
            if let price = extractPriceValue(from: offers) {
                return price
            }
        }

        // Array of offers
        if let offers = object["offers"] as? [[String: Any]] {
            for offer in offers {
                if let price = extractPriceValue(from: offer) {
                    return price
                }
            }
        }

        return nil
    }

    private static func extractPriceValue(from offer: [String: Any]) -> String? {
        // Try to get price as number
        if let price = offer["price"] as? Double {
            let currency = offer["priceCurrency"] as? String ?? "USD"
            return formatPrice(price, currency: currency)
        }

        // Try to get price as string
        if let priceString = offer["price"] as? String {
            // Remove currency symbols and parse
            let cleaned = priceString.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
            if let price = Double(cleaned) {
                let currency = offer["priceCurrency"] as? String ?? "USD"
                return formatPrice(price, currency: currency)
            }
        }

        // Amazon sometimes uses lowPrice/highPrice
        if let lowPrice = offer["lowPrice"] as? Double ?? Double(offer["lowPrice"] as? String ?? "") {
            let currency = offer["priceCurrency"] as? String ?? "USD"
            return formatPrice(lowPrice, currency: currency)
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
