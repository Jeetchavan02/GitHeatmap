// ContribHeatmapApp.swift
// ContribHeatmap (Host Application)
// Interactive Dashboard & Widget Preview Manager

import SwiftUI
import WidgetKit

@main
struct ContribHeatmapApp: App {
    var body: some Scene {
        WindowGroup("GitHub Contribution Heatmap") {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @AppStorage("savedGitHubUsername") private var savedUsername: String = "Jeetchavan02"
    @State private var inputUsername: String = ""
    @State private var days: [ContributionDay] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    private var smallWeeks: [ContributionWeek] {
        HeatmapGridBuilder.buildGrid(from: days, weekCount: 9)
    }

    private var mediumWeeks: [ContributionWeek] {
        HeatmapGridBuilder.buildGrid(from: days, weekCount: 20)
    }

    private var totalContributions: Int {
        days.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header / Username input
            HStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(.green)

                Text("GitHub Heatmap")
                    .font(.title2.bold())

                Spacer()

                HStack(spacing: 8) {
                    TextField("Enter GitHub Username", text: $inputUsername)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .onSubmit {
                            fetch(username: inputUsername)
                        }

                    Button {
                        fetch(username: inputUsername)
                    } label: {
                        if isLoading {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Fetch", systemImage: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(isLoading || inputUsername.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)

            if let error = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
            }

            Divider()

            // Previews of both Widget sizes
            HStack(alignment: .top, spacing: 24) {
                // Small Widget View (9 weeks)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Small Widget")
                            .font(.headline)
                        Spacer()
                        Text("9 Weeks")
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
                                configuration: HeatmapConfigurationIntent(username: savedUsername),
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

                // Medium Widget View (20 weeks)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Medium Widget")
                            .font(.headline)
                        Spacer()
                        Text("20 Weeks")
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
                                configuration: HeatmapConfigurationIntent(username: savedUsername),
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

            Divider()

            // Instructions / Info
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Live Widget Synced: Enter any GitHub username above to instantly test & inspect their live contributions.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .frame(width: 600, height: 350)
        .onAppear {
            inputUsername = savedUsername
            fetch(username: savedUsername)
        }
    }

    private func fetch(username: String) {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let fetched = try await ContributionService.shared.fetch(username: trimmed)
                await MainActor.run {
                    self.days = fetched
                    self.savedUsername = trimmed
                    self.isLoading = false
                    // Reload all timeline widgets so the Notification Center updates
                    WidgetCenter.shared.reloadAllTimelines()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Could not fetch @\(trimmed): \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}
