// Main.swift
// ContribHeatmapCLI
// Terminal heatmap visualizer that runs directly on your Mac using the compiled widget engine

import Foundation
@testable import ContribHeatmapWidget

@main
struct ContribHeatmapCLI {
    static func main() async {
        let args = CommandLine.arguments
        let username = args.count > 1 ? args[1] : "octocat"
        let weeksToShow = args.count > 2 ? (Int(args[2]) ?? 20) : 20

        print("\n\u{001B}[1;36m===============================================================\u{001B}[0m")
        print("\u{001B}[1;32m  GitHub Contribution Heatmap — macOS Terminal Preview\u{001B}[0m")
        print("\u{001B}[1;36m===============================================================\u{001B}[0m")
        print("Fetching contributions for: \u{001B}[1;33m\(username)\u{001B}[0m ...")

        do {
            let days = try await ContributionService.shared.fetch(username: username)
            let weeks = HeatmapGridBuilder.buildGrid(from: days, weekCount: weeksToShow)
            let total = HeatmapGridBuilder.totalContributions(in: weeks)

            print("\u{001B}[1;32m✓ Loaded \(days.count) days of data from API\u{001B}[0m")
            print("Total contributions in last \(weeksToShow) weeks: \u{001B}[1;35m\(total)\u{001B}[0m\n")

            // Render Heatmap Grid
            // Days of week: Sun=0, Mon=1, Tue=2, Wed=3, Thu=4, Fri=5, Sat=6
            let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

            for dayIdx in 0..<7 {
                let label = dayLabels[dayIdx]
                var rowStr = "\(label)  "

                for week in weeks {
                    if let day = week.days[dayIdx] {
                        if day.isFuture {
                            rowStr += "  "
                        } else {
                            rowStr += symbol(for: day.level) + " "
                        }
                    } else {
                        rowStr += "  "
                    }
                }
                print(rowStr)
            }

            // Legend
            print("\nLegend:  \(symbol(for: .none)) None   \(symbol(for: .low)) Low   \(symbol(for: .medium)) Med   \(symbol(for: .high)) High   \(symbol(for: .max)) Max\n")

            // Also preview small widget window
            let smallWeeks = HeatmapGridBuilder.buildGrid(from: days, weekCount: 9)
            let smallTotal = HeatmapGridBuilder.totalContributions(in: smallWeeks)
            print("ℹ️  Small Widget (.systemSmall, 9 weeks) total: \(smallTotal) contributions")
            print("ℹ️  Medium Widget (.systemMedium, 20 weeks) total: \(total) contributions\n")

        } catch {
            print("\u{001B}[1;31m✗ Error fetching data: \(error.localizedDescription)\u{001B}[0m")
            print("Falling back to sample widget preview data:\n")

            let sample = HeatmapGridBuilder.sampleDays(weekCount: weeksToShow)
            let weeks = HeatmapGridBuilder.buildGrid(from: sample, weekCount: weeksToShow)
            let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

            for dayIdx in 0..<7 {
                var rowStr = "\(dayLabels[dayIdx])  "
                for week in weeks {
                    if let day = week.days[dayIdx] {
                        rowStr += symbol(for: day.level) + " "
                    } else {
                        rowStr += "  "
                    }
                }
                print(rowStr)
            }
        }
    }

    private static func symbol(for level: ContributionLevel) -> String {
        switch level {
        case .none:   return "\u{001B}[90m■\u{001B}[0m" // Dark gray
        case .low:    return "\u{001B}[32m■\u{001B}[0m" // Green
        case .medium: return "\u{001B}[92m■\u{001B}[0m" // Bright green
        case .high:   return "\u{001B}[33m■\u{001B}[0m" // Yellow-green
        case .max:    return "\u{001B}[1;92m■\u{001B}[0m" // Bold high-intensity green
        }
    }
}
