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
            Text(item.name)
                .font(.custom("Caveat", size: 32))
                .lineSpacing(-18)
                .foregroundColor(item.isPurchased ? .warmGray : .warmBlack)
                .strikethrough(item.isPurchased, color: .warmGray)
                .lineLimit(2)

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
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
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
    let itemCount: Int?
    let onInvite: () -> Void

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
                        Image(systemName: "gift.fill")
                            .font(.caption)
                            .foregroundColor(.gold)

                        if let count = itemCount {
                            Text("\(count) \(count == 1 ? "item" : "items")")
                                .font(.caption)
                                .foregroundColor(.warmGray)
                        } else {
                            Text("Loading...")
                                .font(.caption)
                                .foregroundColor(.warmGray)
                        }
                    }
                }
            }

            Spacer()

            if friend.hasApp {
                Image(systemName: "chevron.right")
                    .font(.bodySmall)
                    .foregroundColor(.warmGrayLight)
            } else {
                Button(action: onInvite) {
                    HStack(spacing: 4) {
                        Image(systemName: "paperplane.fill")
                        Text("Invite")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.forestGreen)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 6)
                    .background(Color.goldLight.opacity(0.3))
                    .cornerRadius(CornerRadius.sm)
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

// MARK: - Child Row

struct ChildRow: View {
    let child: CKChild
    let itemCount: Int?

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Child icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.goldLight.opacity(0.8), Color.gold.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                Image(systemName: "figure.child")
                    .font(.caption)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(child.name)
                    .font(.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(.warmBlack)

                HStack(spacing: 4) {
                    Image(systemName: "gift.fill")
                        .font(.caption2)
                        .foregroundColor(.gold)

                    if let count = itemCount {
                        Text("\(count) \(count == 1 ? "item" : "items")")
                            .font(.caption)
                            .foregroundColor(.warmGray)
                    } else {
                        Text("Loading...")
                            .font(.caption)
                            .foregroundColor(.warmGray)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.warmGrayLight)
        }
        .padding(Spacing.sm)
        .padding(.leading, Spacing.md)
        .background(Color.creamCard.opacity(0.6))
        .cornerRadius(CornerRadius.md)
    }
}
