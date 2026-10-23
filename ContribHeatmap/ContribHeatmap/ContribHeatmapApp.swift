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
                .onOpenURL { url in
                    // When widget is tapped, forward URL to default browser
                    if url.scheme == "https" || url.scheme == "http" {
                        NSWorkspace.shared.open(url)
                    }
                }
        }
        .windowResizability(.contentSize)
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @AppStorage("savedGitHubUsername") private var savedUsername: String = "Jeetchavan02"
    @State private var activeWidgetUsername: String = "Jeetchavan02"
    @State private var inputUsername: String = ""
    @State private var previewUsername: String = "Jeetchavan02"
    @State private var days: [ContributionDay] = []
    @State private var isLoading: Bool = false
    @State private var isConfirming: Bool = false
    @State private var errorMessage: String? = nil
    @State private var statusMessage: String? = nil

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
        VStack(spacing: 16) {
            // Header / Username input & Controls
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "flame.fill")
                        .font(.title2)
                        .foregroundStyle(.green)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("GitHub Heatmap")
                            .font(.title2.bold())

                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 7, height: 7)
                            Text("Active Widget:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("@\(activeWidgetUsername)")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                        }
                    }

                    Spacer()

                    // Quick Switch Presets
                    HStack(spacing: 6) {
                        Button {
                            switchTo(username: "Jeetchavan02")
                        } label: {
                            Text("@Jeetchavan02")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button {
                            switchTo(username: "torvalds")
                        } label: {
                            Text("@torvalds")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    HStack(spacing: 8) {
                        TextField("GitHub Username", text: $inputUsername)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 150)
                            .onSubmit {
                                fetch(username: inputUsername)
                            }

                        Button {
                            fetch(username: inputUsername)
                        } label: {
                            if isLoading && !isConfirming {
                                ProgressView().controlSize(.small)
                            } else {
                                Label("Preview", systemImage: "arrow.clockwise")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isLoading || inputUsername.trimmingCharacters(in: .whitespaces).isEmpty)

                        // Confirm Button to apply to desktop widget
                        Button {
                            confirmWidget(username: inputUsername)
                        } label: {
                            if isConfirming {
                                ProgressView().controlSize(.small)
                            } else {
                                Label("Confirm", systemImage: "checkmark.circle.fill")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(isLoading || inputUsername.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                if let status = statusMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(status)
                            .font(.callout.bold())
                            .foregroundStyle(.green)
                        Spacer()
                    }
                }

                if let error = errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)

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
                                configuration: HeatmapConfigurationIntent(username: previewUsername),
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
                                configuration: HeatmapConfigurationIntent(username: previewUsername),
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
                    Text("Click 'Confirm' to immediately update your macOS desktop widget.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Force Widget Reload") {
                        ContributionCache.setActiveUsername(activeWidgetUsername)
                        WidgetCenter.shared.reloadAllTimelines()
                        WidgetCenter.shared.reloadTimelines(ofKind: "ContribHeatmapWidget")
                        statusMessage = "Widget reload signal sent to macOS!"
                    }
                    .buttonStyle(.link)
                    .font(.footnote)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .frame(width: 650, height: 380)
        .onAppear {
            let active = ContributionCache.getActiveUsername() ?? savedUsername
            activeWidgetUsername = active
            savedUsername = active
            inputUsername = active
            previewUsername = active
            fetch(username: active)
        }
    }

    private func switchTo(username: String) {
        inputUsername = username
        fetch(username: username)
    }

    private func fetch(username: String) {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        statusMessage = nil

        Task {
            do {
                let fetched = try await ContributionService.shared.fetch(username: trimmed)
                await MainActor.run {
                    self.days = fetched
                    self.previewUsername = trimmed
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Could not fetch @\(trimmed): \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    private func confirmWidget(username: String) {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isConfirming = true
        errorMessage = nil
        statusMessage = nil

        Task {
            do {
                let fetched: [ContributionDay]
                if !days.isEmpty && previewUsername.lowercased() == trimmed.lowercased() {
                    fetched = days
                } else {
                    fetched = try await ContributionService.shared.fetch(username: trimmed)
                }

                // Persist active username and cached days to shared storage FIRST
                ContributionCache.setActiveUsername(trimmed)
                await ContributionCache.shared.save(fetched, for: trimmed)

                await MainActor.run {
                    self.days = fetched
                    self.previewUsername = trimmed
                    self.activeWidgetUsername = trimmed
                    self.savedUsername = trimmed
                    self.inputUsername = trimmed

                    // Force WidgetKit to reload all desktop widgets immediately
                    WidgetCenter.shared.reloadAllTimelines()
                    WidgetCenter.shared.reloadTimelines(ofKind: "ContribHeatmapWidget")

                    self.isConfirming = false
                    self.statusMessage = "✓ Desktop Widget successfully updated to @\(trimmed)!"
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Could not update widget for @\(trimmed): \(error.localizedDescription)"
                    self.isConfirming = false
                }
            }
        }
    }
}
