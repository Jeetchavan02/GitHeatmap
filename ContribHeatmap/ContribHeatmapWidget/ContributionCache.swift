// ContributionCache.swift
// ContribHeatmapWidget
//
// Persists the last good fetch result and active user selection.
// Works seamlessly across host companion app and widget extension sandbox.

import Foundation

actor ContributionCache {

    static let shared = ContributionCache()

    private let fileName = "contributions_cache.json"
    private static let activeUserFileName = "active_username.txt"

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

    // MARK: - Directory Locations

    /// All directories where cache/user files can be read from or written to.
    /// Supports direct widget extension sandbox container and app support fallback.
    static var allStorageDirectories: [URL] {
        let fm = FileManager.default
        var dirs: [URL] = []

        // 1. Widget Extension Container (direct filesystem path)
        let pw = getpwuid(getuid())
        let realHome: URL
        if let pw = pw, let dir = pw.pointee.pw_dir {
            realHome = URL(fileURLWithPath: String(cString: dir))
        } else {
            realHome = fm.homeDirectoryForCurrentUser
        }

        let widgetContainerDir = realHome
            .appendingPathComponent("Library/Containers/com.yourname.ContribHeatmap.ContribHeatmapWidget/Data/Library/Application Support/ContribHeatmapWidget", isDirectory: true)
        dirs.append(widgetContainerDir)

        // 2. Extension / App sandbox Application Support
        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let appSupportDir = appSupport.appendingPathComponent("ContribHeatmapWidget", isDirectory: true)
            if !dirs.contains(appSupportDir) {
                dirs.append(appSupportDir)
            }
        }

        // 3. App Group container (if present and directory exists)
        let appGroupID = "group.com.yourname.ContribHeatmap"
        if let groupURL = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            if fm.fileExists(atPath: groupURL.path) && !dirs.contains(groupURL) {
                dirs.append(groupURL)
            }
        }

        return dirs
    }

    // MARK: - Active Username Management

    static func getActiveUsername() -> String? {
        let fm = FileManager.default
        for dir in allStorageDirectories {
            let fileURL = dir.appendingPathComponent(activeUserFileName)
            if fm.fileExists(atPath: fileURL.path),
               let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }

    static func setActiveUsername(_ username: String) {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let fm = FileManager.default

        for dir in allStorageDirectories {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let fileURL = dir.appendingPathComponent(activeUserFileName)
            try? trimmed.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Read

    /// Returns cached `ContributionDay` array.
    func load(for username: String) -> (days: [ContributionDay], fetchedAt: Date)? {
        let fm = FileManager.default
        for dir in Self.allStorageDirectories {
            let fileURL = dir.appendingPathComponent(fileName)
            guard fm.fileExists(atPath: fileURL.path),
                  let data = try? Data(contentsOf: fileURL),
                  let envelope = try? JSONDecoder().decode(CacheEnvelope.self, from: data),
                  envelope.username.lowercased() == username.lowercased() else {
                continue
            }

            let parser = Self.makeParser()
            let days: [ContributionDay] = envelope.days.compactMap { cached in
                guard let date = parser.date(from: cached.isoDate) else { return nil }
                return ContributionDay(date: date, count: max(0, cached.count), level: .none)
            }.sorted { $0.date < $1.date }

            return (days, envelope.fetchedAt)
        }
        return nil
    }

    // MARK: - Write

    func save(_ days: [ContributionDay], for username: String) {
        let fm = FileManager.default
        let cached = days.map { CachedDay(isoDate: Self.makeParser().string(from: $0.date), count: $0.count) }
        let envelope = CacheEnvelope(username: username, fetchedAt: Date(), days: cached)
        guard let data = try? JSONEncoder().encode(envelope) else { return }

        for dir in Self.allStorageDirectories {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let fileURL = dir.appendingPathComponent(fileName)
            try? data.write(to: fileURL, options: .atomic)
        }
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
