//
//  Friend.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import Foundation
import SwiftData

@Model
final class Friend {
    var id: UUID
    var name: String
    var phoneNumber: String?
    var email: String?
    var hasApp: Bool
    var userId: UUID?
    var addedAt: Date
    var imageData: Data?

    init(
        id: UUID = UUID(),
        name: String,
        phoneNumber: String? = nil,
        email: String? = nil,
        hasApp: Bool = false,
        userId: UUID? = nil,
        addedAt: Date = Date(),
        imageData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.email = email
        self.hasApp = hasApp
        self.userId = userId
        self.addedAt = addedAt
        self.imageData = imageData
    }
}
