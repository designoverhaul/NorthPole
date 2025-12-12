//
//  XAIService.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import Foundation
import Combine
import UIKit

// MARK: - Gift Suggestion Model
struct GiftSuggestion: Identifiable {
    let id = UUID()
    let name: String
    let description: String
}

// MARK: - XAI Service
@MainActor
class XAIService: ObservableObject {
    static let shared = XAIService()



    // Optional API key - gracefully degrade if not available
    private let apiKey: String? = {
        // Debug: Print all environment variables to help diagnose
        print("XAIService: Checking for API key...")
        print("XAIService: Environment has \(ProcessInfo.processInfo.environment.count) variables")

        // Try to get from environment variable first (for Xcode debugging)
        if let key = ProcessInfo.processInfo.environment["XAI_API_KEY"], !key.isEmpty {
            print("XAIService: Found API key in environment (length: \(key.count))")
            return key
        }

        // Fallback to Info.plist (for TestFlight/production)
        if let key = Bundle.main.object(forInfoDictionaryKey: "XAI_API_KEY") as? String, !key.isEmpty {
            print("XAIService: Found API key in Info.plist (length: \(key.count))")
            return key
        }

        print("XAIService: No API key found in environment or Info.plist")
        // No API key available - features will be disabled
        return nil
    }()
    
    
    
    private let apiURL = "https://api.x.ai/v1/chat/completions"

    @Published var isLoading = false
    @Published var errorMessage: String?

    private init() {}

    // MARK: - Generate Gift Suggestions
    func generateGiftSuggestions(age: Int, interests: [String], sex: String, budget: Double = 100, educationalLevel: Double = 0.5) async -> [GiftSuggestion] {
        // Check if API key is available
        guard let apiKey = apiKey else {
            print("XAIService: API key not configured - suggestions disabled")
            errorMessage = "AI suggestions require API configuration"
            return []
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        // Build the prompt
        let interestsText = interests.isEmpty ? "general interests" : interests.joined(separator: ", ")
        let sexText = sex == "Either" ? "anyone" : "a \(sex.lowercased()) person"
        let interestsGuidance = interests.isEmpty ? "" : " The user has indicated interest in \(interestsText), but you may suggest products beyond these categories."
        let budgetGuidance = " The budget is around $\(Int(budget)) per gift."

        // Educational level guidance
        let educationalGuidance: String
        switch educationalLevel {
        case 0.0:
            educationalGuidance = " Focus HEAVILY on fun, entertainment, games, toys, and recreational items. Avoid educational products."
        case 0.25:
            educationalGuidance = " Lean towards fun and entertaining gifts, but you may include a few items that have subtle learning aspects."
        case 0.5:
            educationalGuidance = " Balance between fun/entertainment and educational value. Include a mix of both types of products."
        case 0.75:
            educationalGuidance = " Lean towards educational gifts, STEM products, and items that develop skills, but you may include some fun elements."
        case 1.0:
            educationalGuidance = " Focus HEAVILY on educational products, STEM toys, learning resources, skill-building items, and intellectually stimulating gifts. Prioritize learning and development."
        default:
            educationalGuidance = " Balance between fun/entertainment and educational value."
        }

        let prompt = """
        You are a helpful gift advisor. Generate exactly 10 creative and thoughtful gift suggestions for \(sexText) who is \(age) years old.\(budgetGuidance)\(interestsGuidance)\(educationalGuidance)

        CRITICAL REQUIREMENTS:
        - ALL products MUST be REAL products that actually exist and can be purchased
        - Do NOT create fictional or made-up items
        - prioritize products that may be trending. Hot popular items that may be mentioned on on Twitter.
        - You are not limited to the interest categories - suggest any appropriate real products
        - Respect the educational preference specified above
        - Note the budget above. If it's high you may wanna look for a higher priced items.

        For each gift, provide:
        1. The gift name (should be a real product name)
        2. A 1-2 sentence description explaining why it's a great gift for this age group
        3. One appropriate emoji

        Format your response as a JSON array with this structure:
        [
            {
                "name": "Real Product Name Here",
                "description": "Brief description here."
            }
        ]

        Only return the JSON array, nothing else.
        """

        // Create the request
        guard let url = URL(string: apiURL) else {
            print("XAIService: Invalid URL")
            errorMessage = "Invalid API URL"
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let requestBody: [String: Any] = [
            "model": "grok-4-fast-non-reasoning-latest",
            "messages": [
                [
                    "role": "system",
                    "content": "You are a helpful gift advisor that provides creative gift suggestions in JSON format."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "temperature": 0.8,
            "max_tokens": 2000
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

            let (data, response) = try await URLSession.shared.data(for: request)

            // Check response status
            if let httpResponse = response as? HTTPURLResponse {
                print("XAIService: Response status code: \(httpResponse.statusCode)")

                if httpResponse.statusCode != 200 {
                    let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                    print("XAIService: API Error: \(errorText)")
                    errorMessage = "API returned error code \(httpResponse.statusCode)"
                    return []
                }
            }

            // Parse the response
            let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            guard let choices = jsonResponse?["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                print("XAIService: Failed to parse API response structure")
                errorMessage = "Failed to parse API response"
                return []
            }

            print("XAIService: Received content: \(content)")

            // Parse the JSON array from the content
            let suggestions = try parseGiftSuggestions(from: content)
            print("XAIService: Successfully parsed \(suggestions.count) suggestions")
            return suggestions

        } catch {
            print("XAIService: Error generating suggestions: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return []
        }
    }

    // MARK: - Parse Gift Suggestions
    private func parseGiftSuggestions(from content: String) throws -> [GiftSuggestion] {
        // Clean up the content - sometimes AI adds markdown code blocks
        var cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code blocks if present
        if cleanContent.hasPrefix("```json") {
            cleanContent = cleanContent.replacingOccurrences(of: "```json", with: "")
            cleanContent = cleanContent.replacingOccurrences(of: "```", with: "")
            cleanContent = cleanContent.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if cleanContent.hasPrefix("```") {
            cleanContent = cleanContent.replacingOccurrences(of: "```", with: "")
            cleanContent = cleanContent.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let jsonData = cleanContent.data(using: .utf8) else {
            throw NSError(domain: "XAIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert content to data"])
        }

        let jsonArray = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]]

        guard let suggestions = jsonArray else {
            throw NSError(domain: "XAIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Content is not a valid JSON array"])
        }

        var results: [GiftSuggestion] = []

        for item in suggestions {
            if let name = item["name"] as? String,
               let description = item["description"] as? String {
                results.append(GiftSuggestion(name: name, description: description))
            }
        }

        return results
    }

    // MARK: - Clean Product Title
    func cleanProductTitle(_ rawTitle: String) async -> String {
        // Check if API key is available
        guard let apiKey = apiKey else {
            print("XAIService: API key not configured - returning original title")
            return rawTitle // Return original title if API key not available
        }

        // Create the request
        guard let url = URL(string: apiURL) else {
            print("XAIService: Invalid URL for title cleaning")
            return rawTitle // Return original if API unavailable
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let prompt = """
        Clean up this product title to make it SHORT and concise. Aggressively remove unnecessary information like:
        - Brand names (unless they're essential to the product identity)
        - Pack sizes ("Pack of 2", "Set of 3", "Bundle")
        - Marketing fluff ("Best", "Premium", "High Quality", "Professional", "Ultimate")
        - Audience descriptors ("For beginners", "For kids", "For adults", "For women", "For men")
        - Excessive adjectives and descriptors
        - Special characters and extra punctuation
        - Year/model numbers (unless critical)
        - Material descriptions (unless it's the main feature)
        - Color/size variations (unless it's the product name itself)

        Focus on the CORE product name only. Keep it under 40 characters. Just return the cleaned title, nothing else.

        Original title: \(rawTitle)
        """

        let requestBody: [String: Any] = [
            "model": "grok-4-fast-non-reasoning-latest",
            "messages": [
                [
                    "role": "system",
                    "content": "You are a helpful assistant that cleans up product titles. Only return the cleaned title, no explanations or extra text."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "temperature": 0.3,
            "max_tokens": 100
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            let (data, response) = try await URLSession.shared.data(for: request)

            // Check response status
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    print("XAIService: Title cleaning API error: \(httpResponse.statusCode)")
                    return rawTitle
                }
            }

            // Parse the response
            let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            guard let choices = jsonResponse?["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                print("XAIService: Failed to parse title cleaning response")
                return rawTitle
            }

            let cleanedTitle = content.trimmingCharacters(in: .whitespacesAndNewlines)
            print("XAIService: Cleaned title: '\(rawTitle)' -> '\(cleanedTitle)'")
            return cleanedTitle

        } catch {
            print("XAIService: Error cleaning title: \(error.localizedDescription)")
            return rawTitle // Return original on error
        }
    }

    // MARK: - Open Google Shopping Search
    static func searchGoogleShopping(for giftName: String) {
        // Use a custom character set that properly encodes spaces and special characters
        // .urlQueryAllowed is too permissive and can leave characters that break query parsing
        var allowedCharacters = CharacterSet.alphanumerics
        allowedCharacters.insert(charactersIn: "-._~") // RFC 3986 unreserved characters

        let searchQuery = giftName.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? ""
        let urlString = "https://www.google.com/search?tbm=shop&q=\(searchQuery)"

        if let url = URL(string: urlString) {
            #if os(iOS)
            UIApplication.shared.open(url)
            #endif
        }
    }
}
