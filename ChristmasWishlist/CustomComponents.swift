//
//  CustomComponents.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI

// MARK: - Primary Button Style
struct PrimaryButtonStyle: ButtonStyle {
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bodyLarge)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(
                isDestructive ? Color.errorRed : Color.forestGreen
            )
            .cornerRadius(CornerRadius.md)
            .shadow(
                color: DesignShadow.medium,
                radius: 8,
                x: 0,
                y: 4
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bodyMedium)
            .fontWeight(.medium)
            .foregroundColor(.forestGreen)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.creamCard)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .stroke(Color.forestGreenLight, lineWidth: 1.5)
            )
            .cornerRadius(CornerRadius.sm)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Card Container
struct CardContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(Color.creamCard)
            .cornerRadius(CornerRadius.lg)
            .shadow(
                color: DesignShadow.soft,
                radius: 12,
                x: 0,
                y: 4
            )
    }
}

// MARK: - Floating Action Button
struct FloatingActionButton: View {
    let action: () -> Void
    let icon: String
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            action()
        }) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.gold, Color.goldLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(
                        color: Color.gold.opacity(0.4),
                        radius: 12,
                        x: 0,
                        y: 6
                    )

                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Wishlist Item Row
struct WishlistItemRow: View {
    let item: WishlistItem
    let showPurchaseButton: Bool
    let onDelete: (() -> Void)?
    let onTogglePurchase: (() -> Void)?

    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(item.name)
                    .font(.bodyLarge)
                    .fontWeight(.medium)
                    .foregroundColor(item.isPurchased ? .warmGray : .warmBlack)
                    .strikethrough(item.isPurchased, color: .warmGray)

                if let url = item.url, !url.isEmpty {
                    Text(url)
                        .font(.caption)
                        .foregroundColor(.warmGray)
                        .lineLimit(1)
                }

                if let description = item.itemDescription, !description.isEmpty {
                    Text(description)
                        .font(.bodySmall)
                        .foregroundColor(.warmGray)
                        .lineLimit(2)
                }
            }

            Spacer()

            if showPurchaseButton {
                Button(action: {
                    onTogglePurchase?()
                }) {
                    Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 28))
                        .foregroundColor(item.isPurchased ? .successGreen : .warmGrayLight)
                }
                .buttonStyle(PlainButtonStyle())
            } else if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 20))
                        .foregroundColor(.warmGray)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(Spacing.md)
        .background(Color.creamCard)
        .cornerRadius(CornerRadius.md)
        .shadow(
            color: DesignShadow.soft,
            radius: 6,
            x: 0,
            y: 2
        )
    }
}

// MARK: - Friend Row
struct FriendRow: View {
    let friend: CKFriend

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Avatar - photo if available, otherwise first initial
            Group {
                if let imageData = friend.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                } else {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.forestGreenLight, Color.forestGreen],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)

                        Text(String(friend.name.prefix(1)))
                            .font(.headingSmall)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(friend.name)
                    .font(.bodyLarge)
                    .fontWeight(.medium)
                    .foregroundColor(.warmBlack)

                if friend.hasApp {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.gold)

                        Text("Has app")
                            .font(.caption)
                            .foregroundColor(.warmGray)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.bodySmall)
                .foregroundColor(.warmGrayLight)
        }
        .padding(Spacing.md)
        .background(Color.creamCard)
        .cornerRadius(CornerRadius.md)
        .shadow(
            color: DesignShadow.soft,
            radius: 6,
            x: 0,
            y: 2
        )
    }
}
