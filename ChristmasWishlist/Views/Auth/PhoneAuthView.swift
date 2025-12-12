//
//  PhoneAuthView.swift
//  ChristmasWishlist
//
//  Created by Claude Code on 12/10/24.
//

import SwiftUI

struct PhoneAuthView: View {
    @ObservedObject private var authManager = FirebaseAuthManager.shared
    @State private var phoneNumber: String = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var navigateToVerification = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.creamBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        Spacer()
                            .frame(height: 60)

                        // Holiday icon
                        Image(systemName: "gift.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.gold, Color.goldShimmer],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color.gold.opacity(0.3), radius: 10, x: 0, y: 5)
                            .padding(.bottom, Spacing.md)

                        // Title
                        Text("Welcome to\nChristmas Wishlist")
                            .font(.system(size: 32, weight: .bold, design: .serif))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.forestGreen)
                            .padding(.bottom, Spacing.xs)

                        // Subtitle
                        Text("Sign in with your phone number to get started")
                            .font(.system(size: 16, weight: .regular))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, Spacing.xl)
                            .padding(.bottom, Spacing.xl)

                        // Phone number input
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Phone Number")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.forestGreen)

                            HStack(spacing: Spacing.sm) {
                                // Country code
                                Text("+1")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.forestGreen)
                                    .padding(.leading, Spacing.md)

                                // Phone number text field
                                TextField("(205) 292-9663", text: $phoneNumber)
                                    .keyboardType(.phonePad)
                                    .font(.system(size: 18))
                                    .textContentType(.telephoneNumber)
                                    .autocorrectionDisabled()
                                    .padding(.vertical, Spacing.md)
                                    .onChange(of: phoneNumber) { _, newValue in
                                        // Auto-format phone number
                                        phoneNumber = formatPhoneNumber(newValue)
                                    }
                            }
                            .background(Color.white)
                            .cornerRadius(CornerRadius.md)
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .stroke(Color.gold.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, Spacing.xl)

                        // Continue button
                        Button(action: sendVerificationCode) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Continue")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(
                                LinearGradient(
                                    colors: [Color.gold, Color.goldShimmer],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(CornerRadius.md)
                            .shadow(color: Color.gold.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(phoneNumber.filter { $0.isNumber }.count != 10 || isLoading)
                        .opacity(phoneNumber.filter { $0.isNumber }.count == 10 && !isLoading ? 1.0 : 0.5)
                        .padding(.horizontal, Spacing.xl)
                        .padding(.top, Spacing.md)

                        // Privacy note
                        Text("We'll send you a verification code via SMS")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.xl)
                            .padding(.top, Spacing.sm)

                        Spacer()
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToVerification) {
                SMSVerificationView(phoneNumber: phoneNumber)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = authManager.authError {
                    Text(error)
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func formatPhoneNumber(_ input: String) -> String {
        // Remove any leading +1 or + 1 that might be auto-added by iOS
        var cleaned = input.trimmingCharacters(in: .whitespaces)
        if cleaned.hasPrefix("+1") {
            cleaned = String(cleaned.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        } else if cleaned.hasPrefix("+ 1") {
            cleaned = String(cleaned.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        }
        
        // Remove all non-digit characters
        let digits = cleaned.filter { $0.isNumber }

        // Limit to 10 digits (US phone numbers only)
        let limited = String(digits.prefix(10))

        // Format as (XXX) XXX-XXXX
        if limited.count <= 3 {
            return limited
        } else if limited.count <= 6 {
            let areaCode = limited.prefix(3)
            let middle = limited.dropFirst(3)
            return "(\(areaCode)) \(middle)"
        } else {
            let areaCode = limited.prefix(3)
            let middle = limited.dropFirst(3).prefix(3)
            let last = limited.dropFirst(6)
            return "(\(areaCode)) \(middle)-\(last)"
        }
    }

    private func sendVerificationCode() {
        isLoading = true
        HapticManager.buttonTapped()

        Task {
            do {
                try await authManager.sendVerificationCode(to: phoneNumber)
                isLoading = false
                navigateToVerification = true
                HapticManager.notification(.success)
            } catch {
                isLoading = false
                showError = true
                HapticManager.errorOccurred()
            }
        }
    }
}

#Preview {
    PhoneAuthView()
}
