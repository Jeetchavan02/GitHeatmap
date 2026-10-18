// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ContribHeatmapLogic",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ContribHeatmapWidget", targets: ["ContribHeatmapWidget"]),
        .executable(name: "test-runner", targets: ["ContribHeatmapWidgetTests"]),
        .executable(name: "cli-heatmap", targets: ["ContribHeatmapCLI"]),
        .executable(name: "preview-app", targets: ["ContribHeatmapPreview"]),
    ],
    targets: [
        .target(
            name: "ContribHeatmapWidget",
            path: "ContribHeatmapWidget",
            exclude: [
                "Assets.xcassets",
                "Info.plist",
                "ContribHeatmapWidget.entitlements",
                "ContribHeatmapWidget.swift",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .executableTarget(
            name: "ContribHeatmapWidgetTests",
            dependencies: ["ContribHeatmapWidget"],
            path: "ContribHeatmapWidgetTests",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .executableTarget(
            name: "ContribHeatmapCLI",
            dependencies: ["ContribHeatmapWidget"],
            path: "ContribHeatmapCLI",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .executableTarget(
            name: "ContribHeatmapPreview",
            dependencies: ["ContribHeatmapWidget"],
            path: "ContribHeatmapPreview",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)

