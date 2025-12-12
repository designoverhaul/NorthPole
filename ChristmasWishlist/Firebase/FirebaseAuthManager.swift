//
//  FirebaseAuthManager.swift
//  ChristmasWishlist
//
//  Created by Claude Code on 12/10/24.
//

import Foundation
import Combine
import FirebaseAuth
import OSLog
import SwiftUI
import UIKit

private let logger = Logger(subsystem: "com.designoverhaul.ChristmasWishlist", category: "FirebaseAuth")

@MainActor
class FirebaseAuthManager: ObservableObject {
    static let shared = FirebaseAuthManager()

    @Published var currentUser: FirebaseAuth.User?
    @Published var isAuthenticated = false
    @Published var phoneNumber: String?
    @Published var verificationID: String?
    @Published var authError: String?
    
    // Store the current UI delegate for reCAPTCHA presentation
    private var currentUIDelegate: FirebaseAuthUIDelegate?

    private init() {
        // Check if user is already signed in
        if let user = Auth.auth().currentUser {
            self.currentUser = user
            self.isAuthenticated = true
            self.phoneNumber = normalizePhoneNumber(user.phoneNumber ?? "")
            logger.info("✅ [AUTH] User already signed in: \(user.phoneNumber ?? "unknown")")
        }

        // Listen for auth state changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
                self?.phoneNumber = self?.normalizePhoneNumber(user?.phoneNumber ?? "")
                logger.info("🔄 [AUTH] Auth state changed: \(user?.phoneNumber ?? "signed out")")
            }
        }
    }

    // MARK: - Phone Number Formatting

    /// Normalize phone number to digits only (for Firestore document IDs)
    /// Example: "(205)-292-9663" → "2052929663"
    func normalizePhoneNumber(_ phone: String) -> String {
        return phone.filter { $0.isNumber }
    }

    /// Format phone number for Firebase Auth (E.164 format)
    /// Example: "2052929663" → "+12052929663"
    /// Handles various input formats: "(205) 555-1001", "+1 205-555-1001", "12055551001", etc.
    func formatPhoneForAuth(_ phone: String) -> String {
        // First, remove any leading +1 or + 1 that might have been included
        // This handles cases where iOS autofill or paste might include country code
        var cleanedPhone = phone.trimmingCharacters(in: .whitespaces)
        
        // Remove leading +1, + 1, +1, etc. (with or without spaces)
        if cleanedPhone.hasPrefix("+1") || cleanedPhone.hasPrefix("+ 1") {
            // Find where the actual phone number starts (after +1)
            if let range = cleanedPhone.range(of: "+1") {
                cleanedPhone = String(cleanedPhone[range.upperBound...])
            } else if let range = cleanedPhone.range(of: "+ 1") {
                cleanedPhone = String(cleanedPhone[range.upperBound...])
            }
            cleanedPhone = cleanedPhone.trimmingCharacters(in: .whitespaces)
        }
        
        // Remove ALL non-digit characters (spaces, dashes, parentheses, plus signs, etc.)
        // This ensures we only have digits to work with
        let digits = cleanedPhone.filter { $0.isNumber }
        
        // Validate we have digits
        guard !digits.isEmpty else {
            logger.error("❌ [AUTH] No digits found in phone number: \(phone)")
            return phone // Return original if no digits found (will fail validation later)
        }

        // Handle 10-digit US phone numbers (most common case)
        // Example: "2055551001" → "+12055551001"
        if digits.count == 10 {
            let formatted = "+1\(digits)"
            logger.debug("📱 [AUTH] Formatted 10-digit number: \(phone) → \(formatted)")
            return formatted
        }

        // Handle 11-digit numbers that already include country code
        // Example: "12055551001" → "+12055551001"
        if digits.count == 11 && digits.hasPrefix("1") {
            let formatted = "+\(digits)"
            logger.debug("📱 [AUTH] Formatted 11-digit number: \(phone) → \(formatted)")
            return formatted
        }

        // If we have an unexpected number of digits, try to handle it
        // For US numbers, we expect 10 or 11 digits
        if digits.count < 10 {
            logger.warning("⚠️ [AUTH] Phone number has fewer than 10 digits: \(digits.count) digits from \(phone)")
            // Still try to format it, but it will likely fail Firebase validation
            return "+1\(digits)"
        } else if digits.count > 11 {
            logger.warning("⚠️ [AUTH] Phone number has more than 11 digits: \(digits.count) digits from \(phone)")
            // Take first 11 digits if it starts with 1, otherwise take last 10
            if digits.hasPrefix("1") {
                let first11 = String(digits.prefix(11))
                return "+\(first11)"
            } else {
                let last10 = String(digits.suffix(10))
                return "+1\(last10)"
            }
        }

        // Final fallback: assume US number and add +1
        let formatted = "+1\(digits)"
        logger.warning("⚠️ [AUTH] Unexpected phone format, using fallback: \(phone) → \(formatted)")
        return formatted
    }

    // MARK: - Authentication Flow

    /// Step 1: Send SMS verification code to phone number
    func sendVerificationCode(to phoneNumber: String) async throws {
        logger.info("📱 [AUTH] Sending verification code to: \(phoneNumber)")
        authError = nil

        let formattedPhone = formatPhoneForAuth(phoneNumber)
        logger.info("📱 [AUTH] Formatted phone for Firebase: \(formattedPhone)")
        
        // Validate E.164 format: must start with + and contain only digits after country code
        guard formattedPhone.hasPrefix("+") && formattedPhone.count >= 12 else {
            let error = NSError(
                domain: "FirebaseAuth",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid phone number format. Expected E.164 format (e.g., +12055551001)"]
            )
            logger.error("❌ [AUTH] Invalid formatted phone: \(formattedPhone)")
            authError = "Invalid phone number format. Please enter a valid 10-digit US phone number."
            throw error
        }

        do {
            // Get the current view controller for presenting reCAPTCHA
            let presentingVC = await getCurrentViewController()
            
            // Create UI delegate with proper styling
            let uiDelegate = FirebaseAuthUIDelegate(presentingViewController: presentingVC)
            self.currentUIDelegate = uiDelegate
            
            logger.info("📱 [AUTH] Calling Firebase verifyPhoneNumber with: \(formattedPhone)")
            let verificationID = try await PhoneAuthProvider.provider()
                .verifyPhoneNumber(formattedPhone, uiDelegate: uiDelegate)

            self.verificationID = verificationID
            self.phoneNumber = normalizePhoneNumber(phoneNumber)
            logger.info("✅ [AUTH] Verification code sent successfully")
        } catch {
            logger.error("❌ [AUTH] Failed to send verification code: \(error.localizedDescription)")
            logger.error("❌ [AUTH] Input phone: \(phoneNumber)")
            logger.error("❌ [AUTH] Formatted phone: \(formattedPhone)")
            authError = "Failed to send verification code: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Get the current view controller from the window hierarchy
    private func getCurrentViewController() async -> UIViewController {
        return await MainActor.run {
            // Find the key window's root view controller
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first(where: { $0.isKeyWindow }),
               let rootViewController = window.rootViewController {
                return findTopViewController(from: rootViewController)
            }
            
            // Fallback: create a temporary view controller
            return UIViewController()
        }
    }
    
    /// Recursively find the topmost view controller
    private func findTopViewController(from viewController: UIViewController) -> UIViewController {
        if let presented = viewController.presentedViewController {
            return findTopViewController(from: presented)
        }
        
        if let nav = viewController as? UINavigationController,
           let top = nav.topViewController {
            return findTopViewController(from: top)
        }
        
        if let tab = viewController as? UITabBarController,
           let selected = tab.selectedViewController {
            return findTopViewController(from: selected)
        }
        
        return viewController
    }

    /// Step 2: Verify SMS code and sign in
    func verifyCode(_ code: String) async throws {
        logger.info("🔐 [AUTH] Verifying code...")
        authError = nil

        guard let verificationID = verificationID else {
            let error = NSError(domain: "FirebaseAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No verification ID found"])
            logger.error("❌ [AUTH] No verification ID")
            authError = "No verification ID. Please request a new code."
            throw error
        }

        do {
            let credential = PhoneAuthProvider.provider()
                .credential(withVerificationID: verificationID, verificationCode: code)

            let result = try await Auth.auth().signIn(with: credential)

            self.currentUser = result.user
            self.isAuthenticated = true
            self.phoneNumber = normalizePhoneNumber(result.user.phoneNumber ?? "")

            logger.info("✅ [AUTH] Successfully signed in: \(result.user.phoneNumber ?? "unknown")")
            logger.info("🆔 [AUTH] User UID: \(result.user.uid)")

        } catch {
            logger.error("❌ [AUTH] Failed to verify code: \(error.localizedDescription)")
            authError = "Invalid verification code. Please try again."
            throw error
        }
    }

    /// Sign out current user
    func signOut() throws {
        logger.info("👋 [AUTH] Signing out...")

        do {
            try Auth.auth().signOut()

            self.currentUser = nil
            self.isAuthenticated = false
            self.phoneNumber = nil
            self.verificationID = nil
            self.authError = nil

            logger.info("✅ [AUTH] Successfully signed out")
        } catch {
            logger.error("❌ [AUTH] Failed to sign out: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Helper Methods

    /// Check if user is signed in
    var isSignedIn: Bool {
        return Auth.auth().currentUser != nil
    }

    /// Get current user's normalized phone number
    var currentUserPhone: String? {
        guard let user = Auth.auth().currentUser,
              let phone = user.phoneNumber else {
            return nil
        }
        return normalizePhoneNumber(phone)
    }

    /// Get current user's UID
    var currentUserUID: String? {
        return Auth.auth().currentUser?.uid
    }
}
