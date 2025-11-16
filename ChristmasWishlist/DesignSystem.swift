//
//  DesignSystem.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI

// MARK: - Color Palette
extension Color {
    // Warm Minimalist Christmas Theme
    static let creamBackground = Color(hex: "#FAF7F2")
    static let creamCard = Color(hex: "#FFFBF5")

    // Gold accents for sparkle and highlights
    static let gold = Color(hex: "#D4AF37")
    static let goldLight = Color(hex: "#F4E4C1")
    static let goldShimmer = Color(hex: "#FFD700")

    // Forest green for primary actions
    static let forestGreen = Color(hex: "#2D5016")
    static let forestGreenLight = Color(hex: "#3A6B35")
    static let forestGreenAccent = Color(hex: "#4A7C3B")

    // Neutral tones
    static let warmGray = Color(hex: "#8B8378")
    static let warmGrayLight = Color(hex: "#C4BDB3")
    static let warmBlack = Color(hex: "#2C2A26")

    // Semantic colors
    static let successGreen = Color(hex: "#4A7C3B")
    static let errorRed = Color(hex: "#C84C3C")

    // Helper initializer for hex colors
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Typography
extension Font {
    static let headingLarge = Font.system(size: 32, weight: .bold, design: .rounded)
    static let headingMedium = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let headingSmall = Font.system(size: 20, weight: .semibold, design: .rounded)

    static let bodyLarge = Font.system(size: 17, weight: .regular, design: .rounded)
    static let bodyMedium = Font.system(size: 15, weight: .regular, design: .rounded)
    static let bodySmall = Font.system(size: 13, weight: .regular, design: .rounded)

    static let caption = Font.system(size: 12, weight: .medium, design: .rounded)
}

// MARK: - Spacing
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius
enum CornerRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

// MARK: - Shadow
struct DesignShadow {
    static let soft = Color.warmGray.opacity(0.1)
    static let medium = Color.warmGray.opacity(0.15)
    static let strong = Color.warmGray.opacity(0.2)
}

// MARK: - Gold Gradient Title
struct GoldGradientTitle: ViewModifier {
    let text: String

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(text)
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.gold, Color.goldShimmer, Color.gold],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Color.gold.opacity(0.3), radius: 2, x: 0, y: 1)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.creamBackground, for: .navigationBar)
    }
}

extension View {
    func goldTitle(_ text: String) -> some View {
        modifier(GoldGradientTitle(text: text))
    }

    func friendNameTitle(_ fullName: String) -> some View {
        modifier(FriendNameTitle(fullName: fullName))
    }
}

// MARK: - Friend Name Title (with Custom Font)
struct FriendNameTitle: ViewModifier {
    let fullName: String

    var firstName: String {
        fullName.components(separatedBy: " ").first ?? fullName
    }

    var lastName: String {
        let components = fullName.components(separatedBy: " ")
        return components.count > 1 ? components.dropFirst().joined(separator: " ") : ""
    }

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 4) {
                        Text(firstName)
                            .font(.custom("FleurDeLeah-Regular", size: 36))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.gold, Color.goldShimmer, Color.gold],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: Color.gold.opacity(0.3), radius: 2, x: 0, y: 1)

                        if !lastName.isEmpty {
                            Text(lastName)
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.gold, Color.goldShimmer, Color.gold],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: Color.gold.opacity(0.3), radius: 2, x: 0, y: 1)
                        }
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.creamBackground, for: .navigationBar)
    }
}
