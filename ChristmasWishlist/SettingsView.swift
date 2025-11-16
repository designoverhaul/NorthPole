//
//  SettingsView.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI

struct SettingsView: View {
    @State private var name = ""
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @State private var showingPermissionAlert = false

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
                            .onChange(of: notificationsEnabled) { oldValue, newValue in
                                if newValue {
                                    requestNotificationPermissions()
                                }
                            }
                    } header: {
                        Text("Notifications")
                            .foregroundColor(.forestGreen)
                    } footer: {
                        Text("Get notified when someone marks an item as purchased from your wishlist")
                            .foregroundColor(.warmGray)
                            .font(.caption)
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
            .alert("Notifications Disabled", isPresented: $showingPermissionAlert) {
                Button("Open Settings", role: .none) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {
                    notificationsEnabled = false
                }
            } message: {
                Text("Notification permissions were denied. Please enable them in Settings to receive purchase notifications.")
            }
        }
    }

    // MARK: - Functions

    private func requestNotificationPermissions() {
        Task {
            let granted = await NotificationManager.shared.requestAuthorization()
            if !granted {
                await MainActor.run {
                    showingPermissionAlert = true
                }
            }
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
