//
//  CustomComponents.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI
import ContactsUI

// MARK: - Contact Picker Wrapper
struct ContactPickerView: UIViewControllerRepresentable {
    let onContactsSelected: ([CNContact]) -> Void
    let multiSelect: Bool

    init(multiSelect: Bool = true, onContactsSelected: @escaping ([CNContact]) -> Void) {
        self.multiSelect = multiSelect
        self.onContactsSelected = onContactsSelected
    }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        // Explicitly allow selection of any contact to prevent "details mode"
        picker.predicateForSelectionOfContact = NSPredicate(value: true)
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: ContactPickerView

        init(parent: ContactPickerView) {
            self.parent = parent
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            parent.onContactsSelected(contacts)
        }
        
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            if !parent.multiSelect {
                parent.onContactsSelected([contact])
            }
        }
        
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.onContactsSelected([])
        }
    }
}

// MARK: - Wishlist Item Photo
struct WishlistItemPhoto: View {
    let imageData: Data?
    let isPurchased: Bool
    let randomRotation: Double
    let giftImageName: String

    init(imageData: Data?, isPurchased: Bool = false, itemId: String? = nil, giftIndex: Int? = nil) {
        self.imageData = imageData
        self.isPurchased = isPurchased

        // Generate random rotation between -5 and 5 degrees
        // Use imageData hash for consistent rotation per image, or itemId if no image
        let hashValue: Int
        if let data = imageData {
            hashValue = data.hashValue
        } else if let itemId = itemId {
            // Use itemId hash for rotation if no image data
            hashValue = itemId.hashValue
        } else {
            hashValue = 0
        }
        self.randomRotation = Double((hashValue % 11) - 5) // Range: -5 to 5
        
        // Select gift image (1-4) - cycle through in order if giftIndex provided, otherwise use hash
        let selectedGiftIndex: Int
        if let giftIndex = giftIndex {
            // Cycle through gifts 1-4 based on position among purchased items
            selectedGiftIndex = (giftIndex % 4) + 1 // 1, 2, 3, or 4
        } else {
            // Fallback: use hash if giftIndex not provided
            let giftHash: Int
            if let itemId = itemId {
                giftHash = itemId.hashValue
            } else if let data = imageData {
                giftHash = data.hashValue
            } else {
                giftHash = 0
            }
            selectedGiftIndex = abs(giftHash % 4) + 1 // 1, 2, 3, or 4
        }
        self.giftImageName = "gift\(selectedGiftIndex)"
    }

    var body: some View {
        ZStack(alignment: .center) {
            if isPurchased {
                // Show wrapped gift image when purchased
                Image(giftImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 76)
                    .rotationEffect(.degrees(randomRotation))
            } else if let imageData = imageData,
               let uiImage = UIImage(data: imageData) {
                // Show original image when not purchased
                Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color.white, lineWidth: 5)
                        )
                        .shadow(
                            color: Color.black.opacity(0.15),
                            radius: 4,
                            x: randomRotation > 0 ? 2 : -2,
                            y: 3
                        )
                        .rotationEffect(.degrees(randomRotation))
            }
        }
        .frame(height: 84) // Extra space for rotation and border, variable width
    }
}

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

// MARK: - Gold Button Style
/// Full-width capsule sibling of `FloatingActionButton` — same gold gradient,
/// shadow and press spring, so gold actions read as one family.
struct GoldButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [Color.gold, Color.goldLight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )
            .shadow(color: Color.gold.opacity(0.4), radius: 12, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: configuration.isPressed)
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
    let giftIndex: Int? // Index among purchased items (0-based) for cycling through gifts
    let showSparkle: Bool
    let onSparkleComplete: () -> Void
    @AppStorage("showPurchasedItems") private var showPurchasedItems = false

    init(
        item: WishlistItem,
        showPurchaseButton: Bool,
        onDelete: (() -> Void)? = nil,
        onTogglePurchase: (() -> Void)? = nil,
        giftIndex: Int? = nil,
        showSparkle: Bool = false,
        onSparkleComplete: @escaping () -> Void = {}
    ) {
        self.item = item
        self.showPurchaseButton = showPurchaseButton
        self.onDelete = onDelete
        self.onTogglePurchase = onTogglePurchase
        self.giftIndex = giftIndex
        self.showSparkle = showSparkle
        self.onSparkleComplete = onSparkleComplete
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Photo on the left (or spacer to maintain alignment)
            // Own/child list (!showPurchaseButton): items the owner checked off themselves
            // always wrap into a gift; friend claims only wrap when showPurchasedItems is ON
            // so friends' purchases stay secret by default.
            let visiblyPurchased = item.purchasedByOwner || (showPurchasedItems && item.isPurchased)
            let shouldShowAsGift = visiblyPurchased && !showPurchaseButton
            if item.imageData != nil || shouldShowAsGift {
                ZStack(alignment: .center) {
                    WishlistItemPhoto(
                        imageData: item.imageData,
                        isPurchased: shouldShowAsGift,
                        itemId: item.id.uuidString,
                        giftIndex: giftIndex
                    )
                    
                    // Sparkle overlay on the gift image
                    if showSparkle {
                        SuccessSparkle {
                            onSparkleComplete()
                        }
                        .allowsHitTesting(false)
                    }
                }
            } else {
                // Reserve space to keep text aligned
                Color.clear
                    .frame(width: 84, height: 84)
            }

            Text(item.name)
                .font(.custom("Caveat", size: 27))
                .lineSpacing(-18)
                .foregroundColor(.warmBlack)
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
            } else if (item.purchasedByOwner || (showPurchasedItems && item.isPurchased)) && item.imageData == nil {
                // Show non-interactive checkmark for user's own purchased items (only if no photo)
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.successGreen)
            }
        }
        .padding(.leading, Spacing.md)
        .padding(.trailing, Spacing.xs)
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
    let friend: Friend
    let itemCount: Int?
    let onInvite: (() -> Void)?

    init(friend: Friend, itemCount: Int? = nil, onInvite: (() -> Void)? = nil) {
        self.friend = friend
        self.itemCount = itemCount
        self.onInvite = onInvite
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Avatar - photo if available, otherwise Christmas emoji
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
                            .fill(Color.goldLight.opacity(0.3))
                            .frame(width: 48, height: 48)

                        Text(ChristmasEmojis.emoji(for: friend.name))
                            .font(.system(size: 28))
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
                            Text("\(count) items")
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
            } else if let onInvite = onInvite {
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
    let child: Child
    let itemCount: Int?

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Child icon - Christmas emoji
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

                Text(ChristmasEmojis.emoji(for: child.name))
                    .font(.system(size: 20))
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
                        Text("\(count) items")
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

// MARK: - Snowflake Loading View

struct SnowflakeLoadingView: View {
    let message: LocalizedStringKey?
    @State private var isRotating = false

    init(_ message: LocalizedStringKey? = nil) {
        self.message = message
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            Text("❄️")
                .font(.system(size: 36))
                .rotationEffect(.degrees(isRotating ? 360 : 0))
                .animation(
                    .linear(duration: 5)
                    .repeatForever(autoreverses: false),
                    value: isRotating
                )
                .onAppear {
                    isRotating = true
                }

            if let message = message {
                Text(message)
                    .font(.bodyMedium)
                    .foregroundColor(.warmGray)
            }
        }
    }
}

// MARK: - Identifiable URL Wrapper

/// Wrapper to make URL conform to Identifiable for use with .sheet(item:)
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}
