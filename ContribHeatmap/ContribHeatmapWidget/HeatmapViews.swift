// HeatmapViews.swift
// ContribHeatmapWidget
//
// Single unified view layer for the GitHub Contribution Heatmap widget.
//
// Requirements:
//   - Grid fills widget width with aligned edges and large cells (>= 13pt target on Medium).
//   - Plain header: username leading, "<total> in <N>w" trailing.
//   - Monotonic GitHub green ramp sourced strictly from Color("Level\(n)"). No color literals in Swift.
//   - .widgetAccentable() strictly on Level 3–4 cells and the header total number.
//   - Single-cell strokeBorder on today's cell only (1pt, Color.primary at 0.9 opacity).
//   - Clean background: .containerBackground(.fill.tertiary, for: .widget) without custom overlays.

import SwiftUI
import WidgetKit

// MARK: - Color Support

extension ContributionLevel {

    /// Resolves the rendering color for this level based on the widget rendering mode.
    func color(for renderingMode: WidgetRenderingMode) -> Color {
        switch renderingMode {
        case .fullColor:
            return assetColor
        case .accented, .vibrant:
            return Color.primary.opacity(primaryOpacity)
        default:
            return Color.primary.opacity(primaryOpacity)
        }
    }

    /// Color sets defined in Assets.xcassets. No hex or RGB literals in Swift.
    private var assetColor: Color {
        Color("Level\(rawValue)")
    }

    /// Opacity ladder for accented and vibrant modes (Level 0 remains visible).
    private var primaryOpacity: Double {
        switch self {
        case .none:   return 0.12
        case .low:    return 0.36
        case .medium: return 0.56
        case .high:   return 0.78
        case .max:    return 1.00
        }
    }

    /// Only levels 3–4 are accented in tinted / accented modes.
    var isAccentable: Bool {
        self == .high || self == .max
    }
}

// MARK: - Cell View

struct HeatmapCell: View {
    let day: ContributionDay
    let isToday: Bool
    let size: CGFloat
    let cornerRadius: CGFloat
    let renderingMode: WidgetRenderingMode

    var body: some View {
        if day.isFuture {
            Color.clear
                .frame(width: size, height: size)
        } else {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

            shape
                .fill(day.level.color(for: renderingMode))
                .overlay {
                    if isToday {
                        shape.strokeBorder(Color.primary.opacity(0.9), lineWidth: 1)
                    }
                }
                .modifier(AccentableCellModifier(isAccentable: day.level.isAccentable))
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }
}

private struct AccentableCellModifier: ViewModifier {
    let isAccentable: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isAccentable {
            content.widgetAccentable()
        } else {
            content
        }
    }
}

// MARK: - Header View

struct HeatmapHeader: View {
    let username: String
    let totalCount: Int
    let weekCount: Int
    let isSmall: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            if isSmall {
                HStack(spacing: 0) {
                    Text("\(totalCount)")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(.primary)
                        .widgetAccentable()

                    Text(" in \(weekCount)w")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(.primary.opacity(0.85))
                }
                .lineLimit(1)
                .minimumScaleFactor(0.85)

                Spacer(minLength: 0)
            } else {
                Text(username)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                HStack(spacing: 0) {
                    Text("\(totalCount)")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(.primary)
                        .widgetAccentable()

                    Text(" in \(weekCount)w")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(.primary.opacity(0.85))
                }
                .lineLimit(1)
            }
        }
        .frame(height: 14)
        .accessibilityLabel(isSmall ? "\(username): \(totalCount) in \(weekCount)w" : "\(username), \(totalCount) contributions in \(weekCount) weeks")
    }
}

// MARK: - Main Widget View

struct HeatmapWidgetView: View {
    let entry: HeatmapEntry
    var customFamily: WidgetFamily? = nil

    @Environment(\.widgetFamily)        private var envFamily
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var family: WidgetFamily {
        customFamily ?? envFamily
    }

    private var weekCount: Int {
        family == .systemMedium ? 20 : 9
    }

    var body: some View {
        GeometryReader { geo in
            let cols = weekCount
            let rows = 7
            let gap: CGFloat = 2.0
            let headerHeight: CGFloat = 14.0
            let headerSpacing: CGFloat = 6.0

            let isMedium = family == .systemMedium
            let labelColWidth: CGFloat = 12.0
            let labelSpacing: CGFloat = 3.0
            let labelReserve: CGFloat = isMedium ? (labelColWidth + labelSpacing) : 0.0

            // Step 5: Layout calculation
            // Base padding: 12pt horizontal, 10pt vertical
            let availW = geo.size.width - 24.0
            let availH = geo.size.height - 20.0 - headerHeight - headerSpacing

            let rawGridW = availW - labelReserve
            let rawCellW = (rawGridW - gap * CGFloat(cols - 1)) / CGFloat(cols)
            let rawCellH = (availH - gap * CGFloat(rows - 1)) / CGFloat(rows)
            let calculatedCell = floor(min(rawCellW, rawCellH))

            // Ensure cell is at least 13pt on Medium by adjusting padding if necessary
            let cell = isMedium ? max(13.0, calculatedCell) : calculatedCell
            let cornerRadius = (cell * 0.22).rounded()

            let actualGridW = CGFloat(cols) * cell + gap * CGFloat(cols - 1)
            let actualGridH = CGFloat(rows) * cell + gap * CGFloat(rows - 1)
            let totalContentW = actualGridW + labelReserve

            // Today is the last non-future cell in the final column
            let todayCellId: String? = entry.weeks.last?.days.compactMap({ $0 }).filter({ !$0.isFuture }).last?.id

            VStack(spacing: headerSpacing) {
                // Header: leading and trailing edges align exactly with the grid below
                HeatmapHeader(
                    username: entry.configuration.username,
                    totalCount: entry.totalCount,
                    weekCount: weekCount,
                    isSmall: !isMedium
                )
                .frame(width: totalContentW)

                // Grid Area
                HStack(alignment: .top, spacing: labelSpacing) {
                    if isMedium {
                        VStack(spacing: gap) {
                            ForEach(0..<rows, id: \.self) { r in
                                Text(weekdayLabel(for: r))
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .frame(width: labelColWidth, height: cell, alignment: .trailing)
                                    .accessibilityHidden(true)
                            }
                        }
                    }

                    HStack(alignment: .top, spacing: gap) {
                        ForEach(entry.weeks) { week in
                            VStack(spacing: gap) {
                                ForEach(0..<rows, id: \.self) { rowIdx in
                                    if let day = week.days[rowIdx] {
                                        let isToday = (day.id == todayCellId)
                                        HeatmapCell(
                                            day: day,
                                            isToday: isToday,
                                            size: cell,
                                            cornerRadius: cornerRadius,
                                            renderingMode: renderingMode
                                        )
                                    } else {
                                        Color.clear.frame(width: cell, height: cell)
                                    }
                                }
                            }
                        }
                    }
                    .frame(width: actualGridW, height: actualGridH)
                }
                .frame(width: totalContentW, height: actualGridH)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(entry.configuration.username): \(entry.totalCount) contributions in the last \(weekCount) weeks")
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func weekdayLabel(for row: Int) -> String {
        // Rows: 0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat
        switch row {
        case 1: return "M"
        case 3: return "W"
        case 5: return "F"
        default: return ""
        }
    }
}

// MARK: - Previews

#Preview("Small - Full Color") {
    HeatmapWidgetView(entry: previewEntry(weekCount: 9))
        .environment(\.widgetRenderingMode, .fullColor)
}

#Preview("Small - Accented") {
    HeatmapWidgetView(entry: previewEntry(weekCount: 9))
        .environment(\.widgetRenderingMode, .accented)
}

#Preview("Medium - Full Color") {
    HeatmapWidgetView(entry: previewEntry(weekCount: 20))
        .environment(\.widgetRenderingMode, .fullColor)
}

#Preview("Medium - Accented") {
    HeatmapWidgetView(entry: previewEntry(weekCount: 20))
        .environment(\.widgetRenderingMode, .accented)
}

private func previewEntry(weekCount: Int) -> HeatmapEntry {
    let days = HeatmapGridBuilder.sampleDays(weekCount: weekCount)
    let weeks = HeatmapGridBuilder.buildGrid(from: days, weekCount: weekCount)
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
