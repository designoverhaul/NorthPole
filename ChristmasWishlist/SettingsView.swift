//
//  SettingsView.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI

struct SettingsView: View {
    @State private var name = ""
    @State private var notificationsEnabled = true

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamBackground
                    .ignoresSafeArea()

                Form {
                    Section {
                        HStack {
                            Text("Name")
                                .foregroundColor(.warmBlack)
                            Spacer()
                            TextField("Your name", text: $name)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(.warmBlack)
                        }
                        .listRowBackground(Color.creamCard)
                    } header: {
                        Text("Profile")
                            .foregroundColor(.forestGreen)
                    }

                    Section {
                        Toggle("Purchase notifications", isOn: $notificationsEnabled)
                            .tint(.forestGreen)
                            .foregroundColor(.warmBlack)
                            .listRowBackground(Color.creamCard)
                    } header: {
                        Text("Notifications")
                            .foregroundColor(.forestGreen)
                    }

                    Section {
                        NavigationLink {
                            ImportLogsView()
                        } label: {
                            HStack {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .foregroundColor(.forestGreen)
                                Text("Import Logs")
                                    .foregroundColor(.warmBlack)
                            }
                        }
                        .listRowBackground(Color.creamCard)
                    } header: {
                        Text("Debugging")
                            .foregroundColor(.forestGreen)
                    }

                    Section {
                        NavigationLink {
                            AboutView()
                        } label: {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.forestGreen)
                                Text("About")
                                    .foregroundColor(.warmBlack)
                            }
                        }
                        .listRowBackground(Color.creamCard)

                        NavigationLink {
                            Text("Privacy Policy")
                                .font(.bodyLarge)
                        } label: {
                            HStack {
                                Image(systemName: "hand.raised")
                                    .foregroundColor(.forestGreen)
                                Text("Privacy Policy")
                                    .foregroundColor(.warmBlack)
                            }
                        }
                        .listRowBackground(Color.creamCard)
                    } header: {
                        Text("About")
                            .foregroundColor(.forestGreen)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("")
            .goldTitle("Settings")
        }
    }
}

struct AboutView: View {
    var body: some View {
        ZStack {
            Color.creamBackground
                .ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.gold)
                    .padding(.top, Spacing.xxl)

                Text("Christmas Wishlist")
                    .font(.headingLarge)
                    .foregroundColor(.warmBlack)

                Text("Version 1.0")
                    .font(.bodyMedium)
                    .foregroundColor(.warmGray)

                Text("Share your holiday wishes with friends and family")
                    .font(.bodyMedium)
                    .foregroundColor(.warmGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)

                Spacer()

                Text("Made with ❄️ for the holidays")
                    .font(.caption)
                    .foregroundColor(.warmGrayLight)
                    .padding(.bottom, Spacing.lg)
            }
        }
        .navigationTitle("")
        .goldTitle("About")
    }
}

#Preview {
    SettingsView()
}
