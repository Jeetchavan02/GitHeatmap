// Main.swift
// ContribHeatmapPreview
// Standalone desktop application to live test and view the widget components

import SwiftUI
import AppKit
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
    @State private var username: String = "octocat"
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
            }
            .padding(.horizontal)
            .padding(.top, 16)

            if let error = errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
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
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.2), radius: 10, y: 4)

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(username)
                                        .font(.caption2.bold())
                                    Spacer()
                                    Text("\(HeatmapGridBuilder.totalContributions(in: smallWeeks)) contribs")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 4)

                                HeatmapGrid(weeks: smallWeeks, renderingMode: .fullColor)
                            }
                            .padding(12)
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
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.2), radius: 10, y: 4)

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(username)
                                        .font(.caption.bold())
                                    Spacer()
                                    Text("\(HeatmapGridBuilder.totalContributions(in: mediumWeeks)) contributions in last 20 weeks")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 4)

                                HeatmapGrid(weeks: mediumWeeks, renderingMode: .fullColor)
                            }
                            .padding(14)
                        }
                        .frame(width: 360, height: 170)
                    }
                }
                .padding(.horizontal)
            }

            Spacer(minLength: 12)
        }
        .frame(width: 440, height: 530)
        .task {
            await fetchContributions()
        }
    }

    private func fetchContributions() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await ContributionService.fetchContributions(for: username)
            self.days = fetched
            self.totalContributions = fetched.reduce(0) { $0 + $1.count }
        } catch {
            self.errorMessage = "Failed to load contributions: \(error.localizedDescription). Showing sample fallback."
            self.days = HeatmapGridBuilder.sampleDays(weekCount: 20)
        }
        isLoading = false
    }
}
