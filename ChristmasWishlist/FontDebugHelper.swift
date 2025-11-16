//
//  FontDebugHelper.swift
//  ChristmasWishlist
//
//  Temporary file to debug font names
//

import UIKit

func printAllAvailableFonts() {
    print("=== Available Font Families ===")
    for family in UIFont.familyNames.sorted() {
        print("\nFamily: \(family)")
        for name in UIFont.fontNames(forFamilyName: family) {
            print("  - \(name)")
        }
    }
    print("\n=== End of Font List ===")
}
