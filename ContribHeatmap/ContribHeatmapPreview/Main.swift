// Main.swift
// ContribHeatmapPreview
// Standalone desktop application to live test and view the widget components

import SwiftUI
import AppKit
import WidgetKit
@testable import ContribHeatmapWidget

@main
@MainActor
struct ContribHeatmapPreviewApp: App {
    var body: some Scene {
        WindowGroup("GitHub Contribution Heatmap Preview") {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    @State private var username: String = "Jeetchavan02"
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var days: [ContributionDay] = []
    @State private var totalContributions: Int = 0

    var smallWeeks: [ContributionWeek] {
        HeatmapGridBuilder.buildGrid(from: days, weekCount: 9)
    }

    var mediumWeeks: [ContributionWeek] {
        HeatmapGridBuilder.buildGrid(from: days, weekCount: 20)
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header / Controls
            HStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(.green)

                Text("Heatmap Live Tester")
                    .font(.title2.bold())

                Spacer()

                TextField("GitHub Username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                    .onSubmit {
                        Task { await fetchContributions() }
                    }

                Button(action: {
                    Task { await fetchContributions() }
                }) {
                    if isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Fetch", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isLoading || username.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding(.horizontal)
            .padding(.top, 16)

            if let error = errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .padding(.horizontal)
            }

            Divider()

            // Preview Sections
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    // Small Widget Preview
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Small Widget (.systemSmall)")
                                .font(.headline)
                            Spacer()
                            Text("9 Weeks (Sunday–Saturday)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ZStack {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.85))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.2), radius: 12, y: 5)

                            HeatmapWidgetView(
                                entry: HeatmapEntry(
                                    date: Date(),
                                    configuration: HeatmapConfigurationIntent(username: username),
                                    weeks: smallWeeks,
                                    totalCount: HeatmapGridBuilder.totalContributions(in: smallWeeks),
                                    isStale: false,
                                    staleSince: nil,
                                    errorMessage: nil
                                ),
                                customFamily: .systemSmall
                            )
                        }
                        .frame(width: 170, height: 170)
                    }

                    // Medium Widget Preview
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Medium Widget (.systemMedium)")
                                .font(.headline)
                            Spacer()
                            Text("20 Weeks (Sunday–Saturday)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ZStack {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.85))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.2), radius: 12, y: 5)

                            HeatmapWidgetView(
                                entry: HeatmapEntry(
                                    date: Date(),
                                    configuration: HeatmapConfigurationIntent(username: username),
                                    weeks: mediumWeeks,
                                    totalCount: HeatmapGridBuilder.totalContributions(in: mediumWeeks),
                                    isStale: false,
                                    staleSince: nil,
                                    errorMessage: nil
                                ),
                                customFamily: .systemMedium
                            )
                        }
                        .frame(width: 360, height: 170)
                    }
                }
                .padding(.horizontal)
            }

            Spacer(minLength: 12)
        }
        .frame(width: 500, height: 550)
        .task {
            await fetchContributions()
        }
    }

    private func fetchContributions() async {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await ContributionService.shared.fetch(username: trimmed)
            self.days = fetched
            self.totalContributions = fetched.reduce(0) { $0 + $1.count }
        } catch {
            self.errorMessage = "Failed to load contributions: \(error.localizedDescription). Showing sample fallback."
            self.days = HeatmapGridBuilder.sampleDays(weekCount: 20)
        }
        isLoading = false
    }
}

