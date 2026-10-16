// HeatmapIntent.swift
// ContribHeatmapWidget

import AppIntents
import WidgetKit

struct HeatmapConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "GitHub Heatmap"
    static let description = IntentDescription("Shows your GitHub contribution heatmap.")

    @Parameter(title: "GitHub Username", default: "Jeetchavan02")
    var username: String

    init() {
        self.username = "Jeetchavan02"
    }

    init(username: String) {
        self.username = username
    }
}
