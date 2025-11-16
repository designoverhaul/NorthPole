//
//  HapticManager.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import UIKit

enum HapticManager {
    // Haptic feedback for different interactions
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    // Convenience methods for common app actions
    static func itemAdded() {
        notification(.success)
    }

    static func itemDeleted() {
        impact(.medium)
    }

    static func itemMarkedPurchased() {
        notification(.success)
    }

    static func buttonTapped() {
        impact(.light)
    }

    static func errorOccurred() {
        notification(.error)
    }
}
