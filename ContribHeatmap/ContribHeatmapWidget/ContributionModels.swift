// ContributionModels.swift
// ContribHeatmapWidget
//
// API: https://github-contributions-api.jogruber.de/v4/{username}
// Real schema (verified 2026-10-17):
//   { "total": { "2026": 0, ... }, "contributions": [{ "date": "2026-01-01", "count": 0, "level": 0 }] }
//
// Note: The original deno.dev API is sunset (July 2026). We use the jogruber.de API instead.
// The API's `level` field is ignored in favour of our own quartile-based level mapping.

import Foundation

// MARK: - API Response Models

/// Top-level API response. Unknown keys are silently ignored via `unknownKeys`.
struct APIResponse: Decodable, Sendable {
    let contributions: [APIContributionDay]

    // We don't decode `total` – we compute our own window total.
    private enum CodingKeys: String, CodingKey {
        case contributions
    }
}

/// One entry in the flat `contributions` array.
struct APIContributionDay: Decodable, Sendable {
    let date: String            // "yyyy-MM-dd"
    let count: Int

    // `level` is intentionally NOT decoded; we compute our own quartile levels.
    private enum CodingKeys: String, CodingKey {
        case date, count
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date  = try c.decode(String.self, forKey: .date)
        count = (try? c.decode(Int.self, forKey: .count)) ?? 0   // default to 0 on missing
    }
}

// MARK: - Domain Models

/// Contribution level 0 (none) … 4 (highest), computed from quartiles.
enum ContributionLevel: Int, Sendable, CaseIterable {
    case none  = 0
    case low   = 1
    case medium = 2
    case high  = 3
    case max   = 4
}

/// A single day with its resolved contribution data.
struct ContributionDay: Sendable, Identifiable {
    let id: String          // ISO date string – stable & unique
    let date: Date
    let count: Int
    let level: ContributionLevel
    /// `true` for future days in the current week – rendered as invisible placeholders.
    let isFuture: Bool

    init(date: Date, count: Int, level: ContributionLevel, isFuture: Bool = false) {
        let formatter = ContributionDay.isoFormatter
        self.id = formatter.string(from: date)
        self.date = date
        self.count = count
        self.level = level
        self.isFuture = isFuture
    }

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale     = Locale(identifier: "en_US_POSIX")
        f.calendar   = Calendar(identifier: .gregorian)
        f.timeZone   = TimeZone(identifier: "UTC")!
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

/// A week column (Sun…Sat) in the heatmap grid.
struct ContributionWeek: Sendable, Identifiable {
    let id: Int             // column index
    let days: [ContributionDay?]   // 7 slots; nil = invisible padding (never rendered)

    init(id: Int, days: [ContributionDay?]) {
        precondition(days.count == 7)
        self.id = id
        self.days = days
    }
}

// MARK: - Errors

enum ContributionError: LocalizedError, Sendable {
    case invalidUsername
    case network(Error)
    case badStatus(Int)
    case decoding(Error)
    case empty

    var errorDescription: String? {
        switch self {
        case .invalidUsername:   return "Invalid username"
        case .network(let e):   return "Network error: \(e.localizedDescription)"
        case .badStatus(let c): return "HTTP \(c)"
        case .decoding(let e):  return "Decoding error: \(e.localizedDescription)"
        case .empty:             return "No contributions found"
        }
    }
}
