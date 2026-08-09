//
//  AskSantaView.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//
//  ⚠️ IMPORTANT: This view has multiple keyboard dismissal methods for the number pad
//  The number pad doesn't have a built-in dismiss button, so we provide:
//  1. Keyboard toolbar "Done" button (above keyboard) — must stay unconditional,
//     `.keyboard` placement already only renders while a keyboard is on screen
//  2. Scroll-to-dismiss functionality
//  3. Tap-anywhere-to-dismiss (background and scroll content)
//  4. Touching any other control (sliders, gender menu, interest chips) dismisses it
//  DO NOT REMOVE these methods - they are essential for good UX

import SwiftUI

struct AskSantaView: View {
    @Binding var isActive: Bool
    @StateObject private var xaiService = XAIService.shared
    @FocusState private var isAgeFieldFocused: Bool

    // Form inputs
    @State private var age: String = ""
    @State private var selectedInterests: Set<String> = []
    @State private var selectedSex: Sex = .either
    @State private var budget: Double = 100 // $20 - $500
    @State private var educationalLevel: Double = 0.5 // 0 = Fun, 1 = Educational

    // Results
    @State private var suggestions: [GiftSuggestion] = []
    @State private var hasSearched = false
    @State private var snowflakeRotation: Double = 0

    // Available interest categories. The raw values double as the strings sent to
    // xAI, so they stay in English; the UI renders them through the string catalog.
    private let interests = [
        "Camping & Outdoors", "Lego", "Videogames", "Cooking", "Grilling", "Smart Home",
        "Reading & Books", "Sports & Fitness", "Arts & Crafts",
        "Technology & Gadgets", "Fashion & Accessories", "Home & Garden", "Travel",
        "Photography", "Board Games & Puzzles", "DIY & Tools", "Beauty & Self-Care",
        "Stuff for Dogs", "Collectibles & Memorabilia", "Coffee & Tea"
    ]

    private let maxInterests = 8

    enum Sex: String, CaseIterable {
        case male = "Male"
        case female = "Female"
        case either = "Either"

        var label: LocalizedStringKey {
            LocalizedStringKey(rawValue)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // ⚠️ CRITICAL: Tap background to dismiss keyboard
                // DO NOT REMOVE - Allows users to dismiss by tapping outside the text field
                Color.creamBackground.ignoresSafeArea()
                    .onTapGesture {
                        dismissKeyboard()
                    }

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Santa Header - always show
                        santaHeader

                        // Loading takes priority - show it in place of input form
                        if xaiService.isLoading {
                            loadingView
                        } else if !hasSearched || (hasSearched && suggestions.isEmpty) {
                            // Input Form
                            inputSection

                            // Search Button
                            searchButton
                        }

                        // Results Section (only show when not loading)
                        if !xaiService.isLoading && hasSearched {
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
                    // ⚠️ CRITICAL: Tap anywhere in the form to dismiss the number pad.
                    // The ScrollView covers the background above, so the background's
                    // tap gesture alone is unreachable for most of the screen.
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissKeyboard()
                    }
                }
                // ⚠️ CRITICAL: Enable scroll-to-dismiss keyboard
                // DO NOT REMOVE - Allows users to dismiss keyboard by scrolling
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("")
            .goldTitle("Ask Santa")
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

                // ⚠️ CRITICAL: Done button above keyboard (iOS standard position)
                // DO NOT REMOVE - Primary method to dismiss number pad
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(action: {
                        HapticManager.buttonTapped()
                        dismissKeyboard()
                    }) {
                        Text("Done")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.forestGreen)
                    }
                }
            }
            .toolbarBackground(Color.creamBackground, for: .navigationBar)
            .toolbarBackground(hasSearched && !suggestions.isEmpty ? .visible : .hidden, for: .navigationBar)
        }
    }

    /// Year without digit grouping, so it never renders as "2,026".
    private var currentYear: String {
        Calendar.current.component(.year, from: Date()).formatted(.number.grouping(.never))
    }

    // MARK: - Santa Header
    private var santaHeader: some View {
        GeometryReader { geometry in
            VStack(spacing: Spacing.md) {
                Image("Santa")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: geometry.size.width * 0.6)

                Text("I know what people want in \(currentYear)!")
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
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
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
                    Text("Gender")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.warmBlack)

                    Menu {
                        ForEach(Sex.allCases, id: \.self) { sex in
                            Button(action: {
                                dismissKeyboard()
                                selectedSex = sex
                                HapticManager.selection()
                            }) {
                                HStack {
                                    Text(sex.label)
                                    if selectedSex == sex {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedSex.label)
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

            // Budget Slider
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Budget")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.warmBlack)

                    Spacer()

                    Text(budgetText(budget))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.forestGreen)
                }

                HStack(spacing: Spacing.sm) {
                    Text(budgetText(25))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.warmGray)

                    Slider(value: $budget, in: 25...250, step: 5)
                        .tint(Color.forestGreen)
                        .onChange(of: budget) { _, _ in
                            dismissKeyboard()
                            HapticManager.selection()
                        }

                    Text(budgetText(250))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.warmGray)
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.md)
                .background(Color.creamCard)
                .cornerRadius(CornerRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(Color.warmGrayLight, lineWidth: 1)
                )
            }

            // Educational Level Slider
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Gift Type")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.warmBlack)

                    Spacer()

                    Text(educationalLevelLabel)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.forestGreen)
                }

                HStack(spacing: Spacing.sm) {
                    Text("🎮")
                        .font(.system(size: 20))

                    Slider(value: $educationalLevel, in: 0...1, step: 0.25)
                        .tint(Color.forestGreen)
                        .onChange(of: educationalLevel) { _, _ in
                            dismissKeyboard()
                            HapticManager.selection()
                        }

                    Text("📚")
                        .font(.system(size: 20))
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.md)
                .background(Color.creamCard)
                .cornerRadius(CornerRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(Color.warmGrayLight, lineWidth: 1)
                )
            }

            // Interests
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Interests")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.warmBlack)

                    Spacer()

                    Text("\(selectedInterests.count)/\(maxInterests)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(selectedInterests.count >= maxInterests ? Color.forestGreen : Color.warmGray)
                        .contentTransition(.numericText())
                }
                .animation(.easeInOut(duration: 0.2), value: selectedInterests.count)

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
            Text("❄️")
                .font(.system(size: 60))
                .rotationEffect(.degrees(snowflakeRotation))
                .onAppear {
                    snowflakeRotation = 0
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        snowflakeRotation = 360
                    }
                }
                .onDisappear {
                    snowflakeRotation = 0
                }
                .accessibilityLabel("Searching for gift ideas")
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xxl)
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: xaiService.errorMessage == nil ? "questionmark.circle" : "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(Color.warmGray)

            Group {
                if let error = xaiService.errorMessage {
                    Text("Santa couldn't reach the workshop")
                        .font(.headingMedium)
                        .foregroundStyle(Color.warmBlack)

                    Text(error)
                        .font(.bodyMedium)
                        .foregroundStyle(Color.warmGray)
                } else {
                    Text("No gift ideas found")
                        .font(.headingMedium)
                        .foregroundStyle(Color.warmBlack)

                    Text("Try adjusting your search criteria")
                        .font(.bodyMedium)
                        .foregroundStyle(Color.warmGray)
                }
            }
            .multilineTextAlignment(.center)
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

    private var educationalLevelLabel: LocalizedStringKey {
        switch educationalLevel {
        case 0.0:
            return "Fun & Entertainment"
        case 0.25:
            return "Mostly Fun"
        case 0.5:
            return "Balanced"
        case 0.75:
            return "Mostly Educational"
        case 1.0:
            return "Highly Educational"
        default:
            return "Balanced"
        }
    }

    /// Budget is always a USD amount; `.currency` only places the symbol per locale.
    private func budgetText(_ amount: Double) -> String {
        amount.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    private func dismissKeyboard() {
        guard isAgeFieldFocused else { return }
        isAgeFieldFocused = false
    }

    private func toggleInterest(_ interest: String) {
        dismissKeyboard()

        if selectedInterests.contains(interest) {
            selectedInterests.remove(interest)
            HapticManager.selection()
        } else if selectedInterests.count < maxInterests {
            selectedInterests.insert(interest)
            HapticManager.selection()
        } else {
            HapticManager.errorOccurred()
        }
    }

    private func performSearch() {
        guard let ageValue = Int(age) else { return }

        HapticManager.buttonTapped()
        dismissKeyboard()

        // Nothing may change until the paywall lets the search through, otherwise the form
        // would be swapped for an empty results state behind the paywall.
        SuperwallManager.shared.requestAskSantaSearch(isRefining: !suggestions.isEmpty) {
            runSearch(age: ageValue)
        }
    }

    private func runSearch(age ageValue: Int) {
        // If we already have suggestions, we're finding more (appending)
        let isAppending = !suggestions.isEmpty

        hasSearched = true

        Task {
            let newSuggestions = await xaiService.generateGiftSuggestions(
                age: ageValue,
                interests: Array(selectedInterests),
                sex: selectedSex.rawValue,
                budget: budget,
                educationalLevel: educationalLevel
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
            Text(LocalizedStringKey(interest))
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
