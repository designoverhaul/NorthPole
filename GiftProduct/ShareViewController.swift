//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Claude Code
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit
import SwiftData

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        print("🎁 ShareViewController: viewDidLoad started (Firebase version)")

        let hostingController = UIHostingController(
            rootView: ShareExtensionView(
                extensionContext: self.extensionContext
            )
            .modelContainer(AppGroupContainer.modelContainer)
        )

        print("☁️ ShareViewController: Adding hosting controller...")
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostingController.didMove(toParent: self)

        print("🎁 ShareViewController: Setup completed successfully!")
    }
}
