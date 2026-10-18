# Architecture & Developer Guidance

This document provides technical guidance, architecture overviews, and troubleshooting tips for developers working on the **macOS GitHub Contribution Heatmap Widget**.

---

## 🏗️ Project Architecture

```
Macos-Github-Widget/
├── ContribHeatmap/                      # Primary Xcode project & Swift package
│   ├── ContribHeatmap/                  # Host macOS companion application
│   │   ├── ContribHeatmapApp.swift      # App lifecycle & URL forwarder
│   │   ├── Info.plist                   # App configuration & bundle metadata
│   │   └── Assets.xcassets/             # AppIcon, AccentColor & Level0-4 colors
│   ├── ContribHeatmapWidget/            # WidgetKit extension bundle
│   │   ├── ContribHeatmapWidget.swift   # Widget bundle registration
│   │   ├── HeatmapProvider.swift        # AppIntentTimelineProvider (refreshes & caching)
│   │   ├── HeatmapViews.swift           # Unified SwiftUI view rendering layer
│   │   ├── HeatmapGridBuilder.swift     # Calendar math, quartiles, and grid builder
│   │   ├── HeatmapIntent.swift          # AppIntent user configuration parameter
│   │   ├── ContributionService.swift    # Swift 6 Actor network fetching
│   │   ├── ContributionCache.swift      # Disk persistence & offline fallback
│   │   ├── ContributionModels.swift     # Decodable API models & domain types
│   │   └── Assets.xcassets/             # Widget-specific colorsets
│   ├── ContribHeatmapCLI/               # Terminal visualizer
│   │   └── Main.swift                   # Terminal ANSI color renderer
│   ├── ContribHeatmapPreview/           # Standalone development canvas
│   │   └── Main.swift                   # Swift canvas previewer
│   ├── ContribHeatmapWidgetTests/       # Unit test suite
│   │   └── HeatmapGridBuilderTests.swift# 39 validation assertions
│   └── Package.swift                    # Swift Package Manager manifest
├── screenshots/                         # Documentation visual assets
├── README.md                            # Primary project documentation
└── GUIDANCE.md                          # Developer architecture and debugging guide
```

---

## ⚙️ Core Components Explained

### 1. `ContributionService` (Networking)
- Implemented as a Swift `actor` ensuring strict data-race safety.
- Endpoint: `https://github-contributions-api.jogruber.de/v4/<username>?y=last`
- Uses ephemeral `URLSession` configuration (`timeoutInterval = 10s`) with client-side cache bypass since WidgetKit manages its own timeline snapshots.

### 2. `HeatmapGridBuilder` (Pure Functional Math)
- Uses an immutable Gregorian calendar pinned to UTC and `en_US_POSIX` locale to prevent date discrepancies across time zones.
- **Window Slicing**:
  - Finds the Sunday of the current week.
  - Slices backwards by `(weekCount - 1)` weeks.
  - Generates full 7-slot week columns (Sunday through Saturday).
- **Quartile Level Calculation**:
  - Non-zero contributions across the visible window are sorted to compute 25th, 50th, and 75th percentiles dynamically.
  - Prevents distortion for users with unusually high single-day commit spikes.

### 3. `HeatmapViews` (Presentation Layer)
- **Cell Geometry**:
  - Dynamically calculates cell size based on widget bounds (`GeometryReader`).
  - Medium widget maintains a $\ge 13\text{pt}$ cell target with a $2\text{pt}$ gap.
- **Color Palettes**:
  - Pure vector asset catalogs (`Level0` to `Level4`).
  - Employs an opacity ladder in `.accented` / monochrome mode so levels remain distinguishable against custom wallpaper tints.
- **Current Day Highlighting**:
  - Today's cell is identified by the last non-future cell in the final column and outlined with a $1\text{pt}$ stroke border.

### 4. `ContributionCache` & App Group Container
- Location: Checks for `group.com.yourname.ContribHeatmap` via `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)`.
- If running under ad-hoc local development without an active Apple Developer certificate, automatically falls back to `Application Support/ContribHeatmapWidget`.

---

## 🔧 Common Troubleshooting & FAQ

### 1. The widget doesn't show up in the macOS Widget Gallery
- Ensure you have built and run `ContribHeatmap.app` at least once from Xcode. macOS needs to register the `.appex` extension via LaunchServices.
- If it still doesn't appear, run this in Terminal:
  ```bash
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R /path/to/ContribHeatmap.app
  ```

### 2. The Dock icon appears as a generic placeholder
- macOS caches Dock icons heavily in `com.apple.dock.iconcache`.
- To clear the cache and force a fresh reload:
  ```bash
  rm -rf /var/folders/*/*/*/com.apple.dock.iconcache 2>/dev/null
  killall Dock
  ```

### 3. How often does WidgetKit refresh the data?
- `HeatmapProvider.swift` requests a timeline reload policy of `.after(Date().addingTimeInterval(30 * 60))` (every 30 minutes).
- Note that macOS WidgetKit applies system budgeting and power heuristics. If you need an instant manual refresh, open `ContribHeatmap.app`, enter your username, and hit **Fetch** — this triggers `WidgetCenter.shared.reloadAllTimelines()`.

---

## 🚀 Releasing a Distribution Build

To archive and export a universal binary for distribution:

```bash
cd ContribHeatmap
xcodebuild archive \
  -scheme ContribHeatmap \
  -configuration Release \
  -archivePath ./build/ContribHeatmap.xcarchive

xcodebuild -exportArchive \
  -archivePath ./build/ContribHeatmap.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath ./build/Export
```
