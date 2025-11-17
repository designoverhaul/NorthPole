//
//  AskSantaView.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI

struct AskSantaView: View {
    @Binding var isActive: Bool
    @StateObject private var xaiService = XAIService.shared
    @FocusState private var isAgeFieldFocused: Bool

    // Form inputs
    @State private var age: String = ""
    @State private var selectedInterests: Set<String> = []
    @State private var selectedSex: Sex = .either

    // Results
    @State private var suggestions: [GiftSuggestion] = []
    @State private var hasSearched = false

    // Available interest categories
    private let interests = [
        "Camping & Outdoors", "Lego", "Videogames", "Cooking", "Grilling", "Smart Home",
        "Reading & Books", "Sports & Fitness", "Arts & Crafts",
        "Technology & Gadgets", "Fashion & Accessories", "Home & Garden", "Travel",
        "Photography", "Board Games & Puzzles", "DIY & Tools", "Beauty & Self-Care",
        "Stuff for Dogs", "Collectibles & Memorabilia", "Coffee & Tea"
    ]

    enum Sex: String, CaseIterable {
        case male = "Male"
        case female = "Female"
        case either = "Either"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamBackground.ignoresSafeArea()
                    .onTapGesture {
                        isAgeFieldFocused = false
                    }

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Santa Header - always show
                        santaHeader

                        // Show input form only if no results or empty results
                        if !hasSearched || (hasSearched && suggestions.isEmpty) {
                            // Input Form
                            inputSection

                            // Search Button
                            searchButton
                        }

                        // Results Section
                        if xaiService.isLoading {
                            loadingView
                        } else if hasSearched {
                            if suggestions.isEmpty {
                                emptyStateView
                            } else {
                                resultsSection

                                // Find More button
                                findMoreButton
                            }
                        }
                    }
                    .padding(Spacing.lg)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Back button when showing results
                if hasSearched && !suggestions.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            HapticManager.buttonTapped()
                            withAnimation {
                                hasSearched = false
                                suggestions = []
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundStyle(Color.forestGreen)
                        }
                    }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isAgeFieldFocused = false
                    }
                    .foregroundStyle(Color.forestGreen)
                }
            }
            .toolbarBackground(Color.creamBackground, for: .navigationBar)
            .toolbarBackground(hasSearched && !suggestions.isEmpty ? .visible : .hidden, for: .navigationBar)
        }
    }

    // MARK: - Santa Header
    private var santaHeader: some View {
        GeometryReader { geometry in
            VStack(spacing: Spacing.md) {
                Image("Santa")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: geometry.size.width * 0.6)

                Text("I know exactly what people are asking for.")
                    .font(.custom("Caveat", size: 27))
                    .foregroundStyle(Color.warmBlack)
                    .multilineTextAlignment(.center)
                    .lineSpacing(-4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, Spacing.md)
        }
        .frame(height: 200)
    }

    // MARK: - Input Section
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Age and Sex side by side
            HStack(spacing: Spacing.md) {
                // Age Input
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Age")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.warmBlack)

                    TextField("Enter age", text: $age)
                        .keyboardType(.numberPad)
                        .focused($isAgeFieldFocused)
                        .padding(Spacing.md)
                        .background(Color.creamCard)
                        .cornerRadius(CornerRadius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .stroke(Color.warmGrayLight, lineWidth: 1)
                        )
                }
                .frame(maxWidth: .infinity)

                // Sex Picker
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Sex")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.warmBlack)

                    Menu {
                        ForEach(Sex.allCases, id: \.self) { sex in
                            Button(action: {
                                selectedSex = sex
                                HapticManager.selection()
                            }) {
                                HStack {
                                    Text(sex.rawValue)
                                    if selectedSex == sex {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedSex.rawValue)
                                .foregroundStyle(Color.warmBlack)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.warmGray)
                        }
                        .padding(Spacing.md)
                        .background(Color.creamCard)
                        .cornerRadius(CornerRadius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .stroke(Color.warmGrayLight, lineWidth: 1)
                        )
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // Interests
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Interests")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.warmBlack)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sm) {
                    ForEach(interests, id: \.self) { interest in
                        InterestChip(
                            interest: interest,
                            isSelected: selectedInterests.contains(interest)
                        ) {
                            toggleInterest(interest)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Search Button
    private var searchButton: some View {
        Button(action: performSearch) {
            HStack {
                Image(systemName: "sparkles")
                Text("Find Gift Ideas")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!isFormValid || xaiService.isLoading)
        .opacity(isFormValid ? 1.0 : 0.5)
    }

    // MARK: - Find More Button
    private var findMoreButton: some View {
        Button(action: {
            HapticManager.buttonTapped()
            performSearch()
        }) {
            HStack {
                Image(systemName: "plus.circle")
                Text("Find More")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(xaiService.isLoading)
        .opacity(xaiService.isLoading ? 0.5 : 1.0)
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(Color.forestGreen)

            Text("Santa's elves are searching...")
                .font(.bodyLarge)
                .foregroundStyle(Color.warmGray)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xxl)
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color.warmGray)

            Text("No gift ideas found")
                .font(.headingMedium)
                .foregroundStyle(Color.warmBlack)

            Text("Try adjusting your search criteria")
                .font(.bodyMedium)
                .foregroundStyle(Color.warmGray)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xxl)
    }

    // MARK: - Results Section
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Santa's most requested")
                .font(.headingMedium)
                .foregroundStyle(Color.warmBlack)
                .padding(.horizontal, Spacing.xs)

            ForEach(suggestions) { suggestion in
                GiftSuggestionCard(suggestion: suggestion) {
                    XAIService.searchGoogleShopping(for: suggestion.name)
                    HapticManager.buttonTapped()
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - Helpers
    private var isFormValid: Bool {
        guard let ageValue = Int(age), ageValue > 0 && ageValue < 150 else {
            return false
        }
        return true
    }

    private func toggleInterest(_ interest: String) {
        if selectedInterests.contains(interest) {
            selectedInterests.remove(interest)
        } else {
            selectedInterests.insert(interest)
        }
        HapticManager.selection()
    }

    private func performSearch() {
        guard let ageValue = Int(age) else { return }

        HapticManager.buttonTapped()

        // If we already have suggestions, we're finding more (appending)
        let isAppending = !suggestions.isEmpty

        hasSearched = true

        // Dismiss keyboard
        isAgeFieldFocused = false

        Task {
            let newSuggestions = await xaiService.generateGiftSuggestions(
                age: ageValue,
                interests: Array(selectedInterests),
                sex: selectedSex.rawValue
            )

            if isAppending {
                // Append new suggestions to existing ones
                suggestions.append(contentsOf: newSuggestions)
            } else {
                // Replace with new suggestions
                suggestions = newSuggestions
            }
        }
    }
}

// MARK: - Interest Chip Component
struct InterestChip: View {
    let interest: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(interest)
                .font(.bodySmall)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : Color.forestGreen)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.forestGreen : Color.creamCard)
                .cornerRadius(CornerRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(Color.forestGreen, lineWidth: isSelected ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Gift Suggestion Card Component
struct GiftSuggestionCard: View {
    let suggestion: GiftSuggestion
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text(suggestion.name)
                        .font(.headingSmall)
                        .foregroundStyle(Color.forestGreen)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(Color.gold)
                }

                Text(suggestion.description)
                    .font(.bodyMedium)
                    .foregroundStyle(Color.warmBlack)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.lg)
            .background(Color.creamCard)
            .cornerRadius(CornerRadius.lg)
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .stroke(Color.gold.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Press Events Modifier
extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}

// MARK: - Preview
#Preview {
    AskSantaView(isActive: .constant(true))
}
