//
//  ImportLogsView.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI

struct ImportLogsView: View {
    @State private var attempts: [ImportAttempt] = []

    var stats: (successful: Int, failed: Int, total: Int) {
        ImportLogger.getSuccessRate()
    }

    var body: some View {
        ZStack {
            Color.creamBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Stats header
                VStack(spacing: Spacing.sm) {
                    HStack(spacing: Spacing.lg) {
                        StatBox(
                            title: "Total",
                            value: "\(stats.total)",
                            color: .forestGreen
                        )

                        StatBox(
                            title: "Success",
                            value: "\(stats.successful)",
                            color: .successGreen
                        )

                        StatBox(
                            title: "Failed",
                            value: "\(stats.failed)",
                            color: .errorRed
                        )
                    }
                    .padding(Spacing.md)

                    Button(action: clearLogs) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear All Logs")
                        }
                        .font(.bodySmall)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .background(Color.creamCard)
                .padding(.bottom, Spacing.sm)

                // Logs list
                if attempts.isEmpty {
                    VStack(spacing: Spacing.lg) {
                        Spacer()

                        Image(systemName: "doc.text")
                            .font(.system(size: 72))
                            .foregroundColor(.warmGrayLight)

                        Text("No import attempts yet")
                            .font(.headingMedium)
                            .foregroundColor(.warmGray)

                        Text("Share items from Safari or other apps\nto see logs here")
                            .font(.bodyMedium)
                            .foregroundColor(.warmGray)
                            .multilineTextAlignment(.center)

                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: Spacing.sm) {
                            ForEach(attempts) { attempt in
                                ImportAttemptRow(attempt: attempt)
                            }
                        }
                        .padding(Spacing.md)
                    }
                }
            }
        }
        .navigationTitle("")
        .goldTitle("Import Logs")
        .onAppear {
            loadAttempts()
        }
    }

    private func loadAttempts() {
        attempts = ImportLogger.getAllAttempts()
    }

    private func clearLogs() {
        ImportLogger.clearAllLogs()
        loadAttempts()
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headingMedium)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.warmGray)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.sm)
        .background(Color.white)
        .cornerRadius(CornerRadius.sm)
        .shadow(color: DesignShadow.soft, radius: 4, x: 0, y: 2)
    }
}

struct ImportAttemptRow: View {
    let attempt: ImportAttempt

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: attempt.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(attempt.success ? .successGreen : .errorRed)

                Text(attempt.formattedTimestamp)
                    .font(.caption)
                    .foregroundColor(.warmGray)

                Spacer()

                Text("\(attempt.attachmentCount) attachments")
                    .font(.caption)
                    .foregroundColor(.warmGrayLight)
            }

            if let url = attempt.url {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "link")
                        .font(.caption)
                        .foregroundColor(.forestGreen)
                    Text(url)
                        .font(.bodySmall)
                        .foregroundColor(.warmBlack)
                        .lineLimit(2)
                }
            }

            if let name = attempt.extractedName {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "tag")
                        .font(.caption)
                        .foregroundColor(.gold)
                    Text(name)
                        .font(.bodySmall)
                        .foregroundColor(.warmBlack)
                        .lineLimit(2)
                }
            }

            if let error = attempt.errorMessage {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.errorRed)
                    Text(error)
                        .font(.bodySmall)
                        .foregroundColor(.errorRed)
                        .lineLimit(3)
                }
            }
        }
        .padding(Spacing.md)
        .background(Color.creamCard)
        .cornerRadius(CornerRadius.md)
        .shadow(color: DesignShadow.soft, radius: 6, x: 0, y: 2)
    }
}

#Preview {
    NavigationStack {
        ImportLogsView()
    }
}
