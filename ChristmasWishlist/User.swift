//
//  User.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import Foundation
import SwiftData

@Model
final class User {
    var id: UUID
    var name: String
    var phoneNumber: String?
    var email: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        phoneNumber: String? = nil,
        email: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.email = email
        self.createdAt = createdAt
    }
}
