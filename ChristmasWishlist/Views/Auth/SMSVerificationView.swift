//
//  SMSVerificationView.swift
//  ChristmasWishlist
//
//  Created by Claude Code on 12/10/24.
//

import SwiftUI

struct SMSVerificationView: View {
    let phoneNumber: String

    @ObservedObject private var authManager = FirebaseAuthManager.shared
    @State private var verificationCode: String = ""
    @State private var isLoading = false
    @State private var showError = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Background
            Color.creamBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    Spacer()
                        .frame(height: 60)

                    // Lock icon
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 70))
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
                    Text("Enter Verification Code")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.forestGreen)
                        .padding(.bottom, Spacing.xs)

                    // Phone number display
                    Text("We sent a code to")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    Text(phoneNumber)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.forestGreen)
                        .padding(.bottom, Spacing.xl)

                    // Verification code input
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("6-Digit Code")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.forestGreen)

                        TextField("000000", text: $verificationCode)
                            .keyboardType(.numberPad)
                            .font(.system(size: 24, weight: .medium, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .padding(.vertical, Spacing.md)
                            .background(Color.white)
                            .cornerRadius(CornerRadius.md)
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .stroke(Color.gold.opacity(0.2), lineWidth: 1)
                            )
                            .onChange(of: verificationCode) { _, newValue in
                                // Limit to 6 digits
                                verificationCode = String(newValue.filter { $0.isNumber }.prefix(6))

                                // Auto-verify when 6 digits entered
                                if verificationCode.count == 6 {
                                    verifyCode()
                                }
                            }
                    }
                    .padding(.horizontal, Spacing.xl)

                    // Verify button
                    Button(action: verifyCode) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Verify & Sign In")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(
                            LinearGradient(
                                colors: [Color.forestGreen, Color.forestGreen.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(CornerRadius.md)
                        .shadow(color: Color.forestGreen.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(verificationCode.count != 6 || isLoading)
                    .opacity(verificationCode.count == 6 && !isLoading ? 1.0 : 0.5)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.md)

                    // Resend code button
                    Button(action: resendCode) {
                        Text("Didn't receive a code? Resend")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.gold)
                    }
                    .padding(.top, Spacing.md)

                    Spacer()
                }
            }
        }
        .navigationBarBackButtonHidden(false)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            if let error = authManager.authError {
                Text(error)
            }
        }
    }

    // MARK: - Helper Methods

    private func verifyCode() {
        guard verificationCode.count == 6 else { return }

        isLoading = true
        HapticManager.buttonTapped()

        Task {
            do {
                try await authManager.verifyCode(verificationCode)
                isLoading = false
                HapticManager.notification(.success)

                // Success! User is now authenticated
                // The app will automatically navigate to MainTabView
                // because of the auth state listener in ChristmasWishlistApp

            } catch {
                isLoading = false
                showError = true
                HapticManager.errorOccurred()
            }
        }
    }

    private func resendCode() {
        HapticManager.buttonTapped()

        Task {
            do {
                try await authManager.sendVerificationCode(to: phoneNumber)
                HapticManager.notification(.success)
            } catch {
                showError = true
                HapticManager.errorOccurred()
            }
        }
    }
}

#Preview {
    NavigationStack {
        SMSVerificationView(phoneNumber: "(205) 292-9663")
    }
}
