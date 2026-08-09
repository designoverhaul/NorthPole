//
//  PhoneNumber.swift
//  ChristmasWishlist
//
//  Single place for phone normalization. Canonical form is digits-only with
//  US country code when the number is 10 digits (e.g. 12055551234).
//

import Foundation

nonisolated enum PhoneNumber {
    /// Canonical digits-only phone used as Firestore identity keys.
    static func normalize(_ phone: String) -> String {
        var digits = phone.filter(\.isNumber)
        if digits.count == 10 {
            digits = "1" + digits
        }
        return digits
    }

    /// Canonical form plus common alternate (10-digit without leading 1).
    static func variants(_ phone: String) -> [String] {
        let canonical = normalize(phone)
        guard !canonical.isEmpty else { return [] }

        var result = [canonical]
        if canonical.count == 11, canonical.hasPrefix("1") {
            result.append(String(canonical.dropFirst()))
        }
        return result
    }

    static func matches(_ lhs: String, _ rhs: String) -> Bool {
        let a = normalize(lhs)
        let b = normalize(rhs)
        guard !a.isEmpty, !b.isEmpty else { return false }
        return a == b
    }

    /// Deterministic friendship document id for userPhone → friendPhone.
    static func friendshipDocumentId(userPhone: String, friendPhone: String) -> String {
        "\(normalize(userPhone))_\(normalize(friendPhone))"
    }
}
