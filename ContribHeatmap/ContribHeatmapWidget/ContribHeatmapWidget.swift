// ContribHeatmapWidget.swift
// ContribHeatmapWidget
//
// Widget bundle entry point. Registers Small and Medium families.

import SwiftUI
import WidgetKit

// MARK: - Widget

struct ContribHeatmapWidget: Widget {
    let kind: String = "ContribHeatmapWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: HeatmapConfigurationIntent.self,
            provider: HeatmapProvider()
        ) { entry in
            HeatmapWidgetView(entry: entry)
        }
        .configurationDisplayName("GitHeatmap")
        .description("Your GitHub contribution heatmap.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - Bundle

@main
struct ContribHeatmapWidgetBundle: WidgetBundle {
    var body: some Widget {
        ContribHeatmapWidget()
    }
}
