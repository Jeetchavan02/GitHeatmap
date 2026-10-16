// ContributionCache.swift
// ContribHeatmapWidget
//
// Persists the last good fetch result to the extension's Application Support container.
// Falls back to cached data when the network is unavailable.

import Foundation

actor ContributionCache {

    static let shared = ContributionCache()

    private let fileName = "contributions_cache.json"

    // MARK: - Persistence Struct

    /// Lightweight envelope written to disk.
    private struct CacheEnvelope: Codable, Sendable {
        let username: String
        let fetchedAt: Date
        let days: [CachedDay]
    }

    private struct CachedDay: Codable, Sendable {
        let isoDate: String   // "yyyy-MM-dd"
        let count: Int
    }

    // MARK: - File Location

    private var cacheFileURL: URL? {
        let fm = FileManager.default
        guard let container = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = container.appendingPathComponent("ContribHeatmapWidget", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }

    // MARK: - Read

    /// Returns cached `ContributionDay` array (levels are still `.none`; HeatmapGridBuilder recomputes).
    func load(for username: String) -> (days: [ContributionDay], fetchedAt: Date)? {
        guard let url = cacheFileURL,
              let data = try? Data(contentsOf: url) else { return nil }

        guard let envelope = try? JSONDecoder().decode(CacheEnvelope.self, from: data),
              envelope.username.lowercased() == username.lowercased() else { return nil }

        let parser = Self.makeParser()
        let days: [ContributionDay] = envelope.days.compactMap { cached in
            guard let date = parser.date(from: cached.isoDate) else { return nil }
            return ContributionDay(date: date, count: max(0, cached.count), level: .none)
        }.sorted { $0.date < $1.date }

        return (days, envelope.fetchedAt)
    }

    // MARK: - Write

    func save(_ days: [ContributionDay], for username: String) {
        let cached = days.map { CachedDay(isoDate: Self.makeParser().string(from: $0.date), count: $0.count) }
        let envelope = CacheEnvelope(username: username, fetchedAt: Date(), days: cached)
        guard let url = cacheFileURL,
              let data = try? JSONEncoder().encode(envelope) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Helpers

    private static func makeParser() -> DateFormatter {
        let f = DateFormatter()
        f.locale   = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(identifier: "UTC")!
        f.dateFormat = "yyyy-MM-dd"
        return f
    }
}
