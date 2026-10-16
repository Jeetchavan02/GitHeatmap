// HeatmapGridBuilderTests.swift
// ContribHeatmapWidgetTests
// Clean standalone test runner verifying model decoding and grid algorithms

import Foundation
@testable import ContribHeatmapWidget

@main
@MainActor
struct HeatmapTestsRunner {
    static var passed = 0
    static var failed = 0

    static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "", file: String = #fileID, line: Int = #line) {
        if actual == expected {
            passed += 1
        } else {
            failed += 1
            print("❌ Assertion Failed at \(file):\(line): Expected '\(expected)', got '\(actual)'. \(message)")
        }
    }

    static func assertTrue(_ condition: Bool, _ message: String = "", file: String = #fileID, line: Int = #line) {
        if condition {
            passed += 1
        } else {
            failed += 1
            print("❌ Assertion Failed at \(file):\(line): Condition was false. \(message)")
        }
    }

    static func main() {
        print("🚀 Running ContribHeatmap Widget Tests...")

        let referenceDate: Date = {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "UTC")!
            return cal.date(from: DateComponents(year: 2024, month: 1, day: 17))!
        }()

        // MARK: - Week Count
        let smallGrid = HeatmapGridBuilder.buildGrid(from: [], weekCount: 9, today: referenceDate)
        assertEqual(smallGrid.count, 9, "Small grid should have 9 weeks")

        let mediumGrid = HeatmapGridBuilder.buildGrid(from: [], weekCount: 20, today: referenceDate)
        assertEqual(mediumGrid.count, 20, "Medium grid should have 20 weeks")

        // MARK: - Week Alignment
        if let lastWeek = smallGrid.last, let sunday = lastWeek.days[0] {
            let cal = HeatmapGridBuilder.calendar
            let weekday = cal.component(.weekday, from: sunday.date)
            assertEqual(weekday, 1, "First day of last column should be Sunday (weekday=1)")

            let components = cal.dateComponents([.year, .month, .day], from: sunday.date)
            assertEqual(components.year, 2024)
            assertEqual(components.month, 1)
            assertEqual(components.day, 14)
        } else {
            failed += 1
            print("❌ Last week or first day is nil")
        }

        // MARK: - Future Days
        if let lastWeek = smallGrid.last {
            for idx in 0...3 {
                if let day = lastWeek.days[idx] {
                    assertTrue(!day.isFuture, "Day idx \(idx) should not be future")
                }
            }
            for idx in 4...6 {
                if let day = lastWeek.days[idx] {
                    assertTrue(day.isFuture, "Day idx \(idx) should be future")
                    assertEqual(day.count, 0, "Future day count must be 0")
                }
            }
        }

        // MARK: - Slot Count
        for week in smallGrid {
            assertEqual(week.days.count, 7, "Week must have 7 slots")
        }

        // MARK: - Level Mapping
        let emptyThresholds = HeatmapGridBuilder.quartileThresholds(from: [])
        assertTrue(emptyThresholds.isEmpty, "Empty data should have empty thresholds")
        assertEqual(HeatmapGridBuilder.computeLevel(count: 0, thresholds: emptyThresholds), .none)
        assertEqual(HeatmapGridBuilder.computeLevel(count: 5, thresholds: emptyThresholds), .max)

        let sampleDays: [ContributionDay] = {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "UTC")!
            let base = cal.date(from: DateComponents(year: 2024, month: 1, day: 1))!
            return [1, 2, 3, 4].enumerated().map { idx, count in
                let date = cal.date(byAdding: .day, value: idx, to: base)!
                return ContributionDay(date: date, count: count, level: .none)
            }
        }()

        let thresholds = HeatmapGridBuilder.quartileThresholds(from: sampleDays)
        assertTrue(!thresholds.isEmpty, "Thresholds should not be empty")
        assertEqual(HeatmapGridBuilder.computeLevel(count: 0, thresholds: thresholds), .none)
        assertEqual(HeatmapGridBuilder.computeLevel(count: 1, thresholds: thresholds), .low)
        assertEqual(HeatmapGridBuilder.computeLevel(count: 2, thresholds: thresholds), .medium)
        assertEqual(HeatmapGridBuilder.computeLevel(count: 3, thresholds: thresholds), .high)
        assertEqual(HeatmapGridBuilder.computeLevel(count: 4, thresholds: thresholds), .max)

        // MARK: - JSON Decoding
        let validJson = """
        {
            "total": { "2024": 42 },
            "contributions": [
                { "date": "2024-01-01", "count": 3, "level": 2 },
                { "date": "2024-01-02", "count": 0, "level": 0 },
                { "date": "2024-01-03", "count": 10, "level": 4, "extra_future_key": "ignored" }
            ]
        }
        """
        do {
            let res = try JSONDecoder().decode(APIResponse.self, from: Data(validJson.utf8))
            assertEqual(res.contributions.count, 3)
            assertEqual(res.contributions[0].count, 3)
            assertEqual(res.contributions[1].count, 0)
            assertEqual(res.contributions[2].count, 10)
        } catch {
            failed += 1
            print("❌ Decoding failed: \(error)")
        }

        let missingCountJson = """
        {
            "contributions": [
                { "date": "2024-06-15" }
            ]
        }
        """
        do {
            let res = try JSONDecoder().decode(APIResponse.self, from: Data(missingCountJson.utf8))
            assertEqual(res.contributions.first?.count, 0)
        } catch {
            failed += 1
            print("❌ Missing count decoding failed: \(error)")
        }

        print("🏁 Test Run Finished!")
        print("✅ Passed: \(passed)")
        print("❌ Failed: \(failed)")

        if failed > 0 {
            exit(1)
        }
    }
}
