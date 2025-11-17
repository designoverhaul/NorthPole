//
//  Child.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import Foundation
import SwiftData

@Model
final class Child {
    var id: UUID
    var name: String
    var parentId: UUID
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        parentId: UUID,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.parentId = parentId
        self.createdAt = createdAt
    }
}
