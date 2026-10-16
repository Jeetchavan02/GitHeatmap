// HeatmapGridBuilder.swift
// ContribHeatmapWidget
//
// Pure functions – no side effects, no state, fully unit-testable.

import Foundation

// MARK: - Grid Builder

enum HeatmapGridBuilder {

    // MARK: - Calendar

    /// Fixed Gregorian/UTC/en_US_POSIX calendar used for all date math.
    static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale   = Locale(identifier: "en_US_POSIX")
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    // MARK: - Level Mapping

    /// Maps raw counts to ContributionLevel using quartile thresholds within `window`.
    /// Only non-zero counts participate in the quartile calculation.
    /// Handles windows with fewer than 4 distinct non-zero values gracefully.
    static func computeLevel(count: Int, thresholds: [Int]) -> ContributionLevel {
        guard count > 0 else { return .none }
        // thresholds = [p25, p50, p75] – all non-zero
        if thresholds.isEmpty          { return .max }
        if count <= thresholds[0]      { return .low }
        if thresholds.count == 1       { return count <= thresholds[0] ? .low : .max }
        if count <= thresholds[1]      { return .medium }
        if thresholds.count == 2       { return count <= thresholds[1] ? .medium : .max }
        if count <= thresholds[2]      { return .high }
        return .max
    }

    /// Computes [p25, p50, p75] from the non-zero counts in `days`.
    /// Returns empty array if there are no non-zero days (all zeros → all `.none`).
    static func quartileThresholds(from days: [ContributionDay]) -> [Int] {
        let nonZero = days.filter { !$0.isFuture && $0.count > 0 }.map { $0.count }.sorted()
        guard !nonZero.isEmpty else { return [] }
        let n = nonZero.count

        // Nearest-rank percentile: rank = ceil(p * n) - 1
        func percentile(_ p: Double) -> Int {
            let rank = Int((p * Double(n)).rounded(.up))
            let idx = max(0, min(n - 1, rank - 1))
            return nonZero[idx]
        }

        let p25 = percentile(0.25)
        let p50 = percentile(0.50)
        let p75 = percentile(0.75)

        // Deduplicate while preserving order
        var result: [Int] = []
        for v in [p25, p50, p75] { if !result.contains(v) { result.append(v) } }
        return result
    }

    // MARK: - Window Selection

    /// Returns the last `weekCount` weeks ending with the current week (Sun-first).
    /// Days that are in the future are marked `isFuture = true`.
    /// The first week may have nil slots for days before the data starts (padding).
    static func buildGrid(
        from days: [ContributionDay],
        weekCount: Int,
        today: Date = Date()
    ) -> [ContributionWeek] {

        // 1. Find the Sunday of the current week.
        let startOfToday = calendar.startOfDay(for: today)
        let todayWeekday = calendar.component(.weekday, from: startOfToday) // 1=Sun
        let daysFromSunday = todayWeekday - 1
        guard let currentSunday = calendar.date(byAdding: .day, value: -daysFromSunday, to: startOfToday) else {
            return []
        }

        // 2. The grid starts `weekCount - 1` Sundays earlier.
        guard let gridStart = calendar.date(byAdding: .weekOfYear, value: -(weekCount - 1), to: currentSunday) else {
            return []
        }

        // 3. Build lookup: isoDate -> ContributionDay
        let isoFormatter = makeISOFormatter()
        var lookup: [String: ContributionDay] = [:]
        for day in days {
            let key = isoFormatter.string(from: day.date)
            lookup[key] = day
        }

        // 4. Compute quartile thresholds across ALL days in the window.
        let windowKeys: [String] = (0..<(weekCount * 7)).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: gridStart)
                .map { isoFormatter.string(from: $0) }
        }
        let windowDays = windowKeys.compactMap { lookup[$0] }
        let thresholds = quartileThresholds(from: windowDays)

        // 5. Build weeks.
        var weeks: [ContributionWeek] = []
        for w in 0..<weekCount {
            var slots: [ContributionDay?] = []
            for d in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: w * 7 + d, to: gridStart) else {
                    slots.append(nil)
                    continue
                }

                let isFuture = date > startOfToday
                let key = isoFormatter.string(from: date)
                let rawCount = lookup[key]?.count ?? 0

                let level: ContributionLevel = isFuture ? .none : computeLevel(count: rawCount, thresholds: thresholds)

                let cell = ContributionDay(
                    date: date,
                    count: rawCount,
                    level: level,
                    isFuture: isFuture
                )
                slots.append(cell)
            }
            weeks.append(ContributionWeek(id: w, days: slots))
        }

        return weeks
    }

    // MARK: - Stats

    /// Total contributions in the visible window (excluding future days).
    static func totalContributions(in weeks: [ContributionWeek]) -> Int {
        weeks.flatMap { $0.days }
             .compactMap { $0 }
             .filter { !$0.isFuture }
             .reduce(0) { $0 + $1.count }
    }

    // MARK: - Sample Data (deterministic, for placeholder / snapshots)

    /// Generates fake data for the widget gallery and timeline placeholder.
    static func sampleDays(weekCount: Int, today: Date = Date()) -> [ContributionDay] {
        let cal = calendar
        let startOfToday = cal.startOfDay(for: today)
        let todayWeekday  = cal.component(.weekday, from: startOfToday)
        guard let currentSunday = cal.date(byAdding: .day, value: -(todayWeekday - 1), to: startOfToday),
              let gridStart     = cal.date(byAdding: .weekOfYear, value: -(weekCount - 1), to: currentSunday) else {
            return []
        }

        // Pseudo-random pattern seeded by weekday index so it's reproducible.
        let pattern = [0, 3, 1, 4, 2, 0, 5, 3, 0, 2, 1, 4, 7, 0, 0, 2, 9, 4, 1, 0]
        var result: [ContributionDay] = []
        for offset in 0..<(weekCount * 7) {
            guard let date = cal.date(byAdding: .day, value: offset, to: gridStart) else { continue }
            let count = date <= startOfToday ? pattern[offset % pattern.count] : 0
            result.append(ContributionDay(date: date, count: count, level: .none))
        }
        return result
    }

    // MARK: - Private

    private static func makeISOFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.locale     = Locale(identifier: "en_US_POSIX")
        f.calendar   = Calendar(identifier: .gregorian)
        f.timeZone   = TimeZone(identifier: "UTC")!
        f.dateFormat = "yyyy-MM-dd"
        return f
    }
}
