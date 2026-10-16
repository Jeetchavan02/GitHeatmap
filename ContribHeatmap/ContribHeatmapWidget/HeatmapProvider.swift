// HeatmapProvider.swift
// ContribHeatmapWidget

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline Entry

struct HeatmapEntry: TimelineEntry {
    let date: Date
    let configuration: HeatmapConfigurationIntent
    let weeks: [ContributionWeek]
    let totalCount: Int
    let isStale: Bool
    let staleSince: Date?
    let errorMessage: String?
}

// MARK: - Provider

struct HeatmapProvider: AppIntentTimelineProvider {

    typealias Intent = HeatmapConfigurationIntent
    typealias Entry  = HeatmapEntry

    // MARK: - Placeholder

    func placeholder(in context: Context) -> HeatmapEntry {
        let weekCount = weekCount(for: context.family)
        let sampleDays = HeatmapGridBuilder.sampleDays(weekCount: weekCount)
        let weeks = HeatmapGridBuilder.buildGrid(from: sampleDays, weekCount: weekCount)
        return HeatmapEntry(
            date: Date(),
            configuration: HeatmapConfigurationIntent(),
            weeks: weeks,
            totalCount: HeatmapGridBuilder.totalContributions(in: weeks),
            isStale: false,
            staleSince: nil,
            errorMessage: nil
        )
    }

    // MARK: - Snapshot

    func snapshot(for configuration: HeatmapConfigurationIntent, in context: Context) async -> HeatmapEntry {
        let weekCount = weekCount(for: context.family)
        let sampleDays = HeatmapGridBuilder.sampleDays(weekCount: weekCount)
        let weeks = HeatmapGridBuilder.buildGrid(from: sampleDays, weekCount: weekCount)
        return HeatmapEntry(
            date: Date(),
            configuration: configuration,
            weeks: weeks,
            totalCount: HeatmapGridBuilder.totalContributions(in: weeks),
            isStale: false,
            staleSince: nil,
            errorMessage: nil
        )
    }

    // MARK: - Timeline

    /// Returns a single entry and schedules a refresh every 30 minutes.
    /// WidgetKit may throttle reloads depending on usage – the actual cadence can be
    /// longer in practice (typically 15–60 min for background widgets on macOS).
    func timeline(for configuration: HeatmapConfigurationIntent, in context: Context) async -> Timeline<HeatmapEntry> {
        let weekCount = weekCount(for: context.family)
        let username  = configuration.username.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextRefresh = Date().addingTimeInterval(30 * 60)

        do {
            let rawDays = try await ContributionService.shared.fetch(username: username)
            let weeks = HeatmapGridBuilder.buildGrid(from: rawDays, weekCount: weekCount)
            let total = HeatmapGridBuilder.totalContributions(in: weeks)

            // Persist success to cache.
            await ContributionCache.shared.save(rawDays, for: username)

            let entry = HeatmapEntry(
                date: Date(),
                configuration: configuration,
                weeks: weeks,
                totalCount: total,
                isStale: false,
                staleSince: nil,
                errorMessage: nil
            )
            return Timeline(entries: [entry], policy: .after(nextRefresh))

        } catch {
            // Fall back to cache.
            if let cached = await ContributionCache.shared.load(for: username) {
                let weeks = HeatmapGridBuilder.buildGrid(from: cached.days, weekCount: weekCount)
                let total = HeatmapGridBuilder.totalContributions(in: weeks)
                let entry = HeatmapEntry(
                    date: Date(),
                    configuration: configuration,
                    weeks: weeks,
                    totalCount: total,
                    isStale: true,
                    staleSince: cached.fetchedAt,
                    errorMessage: nil
                )
                return Timeline(entries: [entry], policy: .after(nextRefresh))
            }

            // No cache – show error.
            let errorMessage = (error as? ContributionError)?.errorDescription ?? error.localizedDescription
            let entry = HeatmapEntry(
                date: Date(),
                configuration: configuration,
                weeks: [],
                totalCount: 0,
                isStale: false,
                staleSince: nil,
                errorMessage: errorMessage
            )
            return Timeline(entries: [entry], policy: .after(nextRefresh))
        }
    }

    // MARK: - Helpers

    private func weekCount(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall:  return 9
        case .systemMedium: return 20
        default:            return 9
        }
    }
}
