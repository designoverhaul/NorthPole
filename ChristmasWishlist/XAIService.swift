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

    private let apiKey = "REMOVED_API_KEY"
    private let apiURL = "https://api.x.ai/v1/chat/completions"

    @Published var isLoading = false
    @Published var errorMessage: String?

    private init() {}

    // MARK: - Generate Gift Suggestions
    func generateGiftSuggestions(age: Int, interests: [String], sex: String, budget: Double = 100, educationalLevel: Double = 0.5) async -> [GiftSuggestion] {
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
