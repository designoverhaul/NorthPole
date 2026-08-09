//
//  FirebaseAuthUIDelegate.swift
//  ChristmasWishlist
//
//  Created by Claude Code on 12/10/24.
//

import UIKit
import FirebaseAuth

/// Custom UI delegate for Firebase Phone Authentication
/// Presents reCAPTCHA in a nicely styled modal that matches the app's design
class FirebaseAuthUIDelegate: NSObject, AuthUIDelegate {
    weak var presentingViewController: UIViewController?
    
    init(presentingViewController: UIViewController) {
        self.presentingViewController = presentingViewController
        super.init()
    }
    
    func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)?) {
        // Wrap the Firebase web view in a custom navigation controller
        // with proper styling and presentation
        let navController = UINavigationController(rootViewController: viewControllerToPresent)
        
        // Style the navigation bar to match app design
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.96, green: 0.97, blue: 0.95, alpha: 1.0) // creamBackground
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0.18, green: 0.31, blue: 0.09, alpha: 1.0), // forestGreen
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(red: 0.18, green: 0.31, blue: 0.09, alpha: 1.0) // forestGreen
        ]
        
        navController.navigationBar.standardAppearance = appearance
        navController.navigationBar.scrollEdgeAppearance = appearance
        navController.navigationBar.compactAppearance = appearance
        navController.navigationBar.compactScrollEdgeAppearance = appearance
        
        // Set a nice title
        viewControllerToPresent.navigationItem.title = "Verification"
        viewControllerToPresent.navigationItem.largeTitleDisplayMode = .never
        
        // Add a close button
        let closeButton = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(dismissViewController)
        )
        closeButton.tintColor = UIColor(red: 0.18, green: 0.31, blue: 0.09, alpha: 1.0) // forestGreen
        viewControllerToPresent.navigationItem.rightBarButtonItem = closeButton
        
        // Set background color to match app design
        viewControllerToPresent.view.backgroundColor = UIColor(red: 0.96, green: 0.97, blue: 0.95, alpha: 1.0) // creamBackground
        
        // Configure modal presentation with proper sizing
        navController.modalPresentationStyle = .pageSheet
        navController.modalTransitionStyle = .coverVertical
        
        // Set preferred content size for better layout
        // Use large detent to ensure full screen is available
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.preferredCornerRadius = 20
            sheet.prefersGrabberVisible = true
            // Ensure the sheet takes up most of the screen so content isn't cut off
            sheet.largestUndimmedDetentIdentifier = .large
        }
        
        // Present from the root view controller to ensure it's visible
        if let presentingVC = presentingViewController {
            presentingVC.present(navController, animated: flag, completion: completion)
        } else {
            // Fallback: find the topmost view controller
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first(where: { $0.isKeyWindow }),
               let rootVC = window.rootViewController {
                var topVC = rootVC
                while let presented = topVC.presentedViewController {
                    topVC = presented
                }
                topVC.present(navController, animated: flag, completion: completion)
            }
        }
    }
    
    func dismiss(animated flag: Bool, completion: (() -> Void)?) {
        if let presentingVC = presentingViewController {
            presentingVC.dismiss(animated: flag, completion: completion)
        } else {
            // Fallback: find and dismiss from topmost view controller
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first(where: { $0.isKeyWindow }),
               let rootVC = window.rootViewController {
                var topVC = rootVC
                while let presented = topVC.presentedViewController {
                    topVC = presented
                }
                topVC.dismiss(animated: flag, completion: completion)
            }
        }
    }
    
    @objc private func dismissViewController() {
        dismiss(animated: true, completion: nil)
    }
}




