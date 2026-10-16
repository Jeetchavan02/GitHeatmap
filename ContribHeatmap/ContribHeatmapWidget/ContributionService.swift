// ContributionService.swift
// ContribHeatmapWidget
//
// Fetches contributions from https://github-contributions-api.jogruber.de/v4/{username}
// The original deno.dev endpoint was sunset July 2026; this replacement is the live API.

import Foundation

/// Validated, percent-encoded GitHub username.
struct GitHubUsername: Sendable {
    let rawValue: String
    let encoded: String

    /// Allowed characters in a GitHub username: alphanumeric + hyphen, 1–39 chars.
    /// We construct the regex locally inside init to avoid storing a non-Sendable
    /// Regex<Substring> as a static property (Swift 6 strict concurrency).
    init?(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 39 else { return nil }
        // Local regex literal – not stored, so no Sendable / global-mutable-state issue.
        let validRegex = /^[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,37}[a-zA-Z0-9])?$|^[a-zA-Z0-9]$/
        guard (try? validRegex.wholeMatch(in: trimmed)) != nil else { return nil }
        rawValue = trimmed
        // Percent-encoding for safe URL construction (hyphens are already safe)
        encoded  = trimmed.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? trimmed
    }
}

// MARK: - Service Actor

actor ContributionService {

    static let shared = ContributionService()

    private let baseURL = "https://github-contributions-api.jogruber.de/v4/"
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest  = 10
        config.timeoutIntervalForResource = 10
        // Disable caching – WidgetKit provides its own timeline.
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        session = URLSession(configuration: config)
    }

    /// Fetches raw contribution days for `username`, sorted ascending by date.
    /// Throws `ContributionError` on any failure.
    func fetch(username: String) async throws -> [ContributionDay] {
        guard let validated = GitHubUsername(username) else {
            throw ContributionError.invalidUsername
        }

        let urlString = baseURL + validated.encoded + "?y=last"
        guard let url = URL(string: urlString) else {
            throw ContributionError.invalidUsername
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw ContributionError.network(error)
        }

        if let httpResponse = response as? HTTPURLResponse {
            let status = httpResponse.statusCode
            guard (200..<300).contains(status) else {
                throw ContributionError.badStatus(status)
            }
        }

        let apiResponse: APIResponse
        do {
            let decoder = JSONDecoder()
            apiResponse = try decoder.decode(APIResponse.self, from: data)
        } catch {
            throw ContributionError.decoding(error)
        }

        guard !apiResponse.contributions.isEmpty else {
            throw ContributionError.empty
        }

        let isoParser = Self.makeISOParser()
        let days: [ContributionDay] = apiResponse.contributions.compactMap { api in
            guard let date = isoParser.date(from: api.date) else { return nil }
            return ContributionDay(
                date: date,
                count: max(0, api.count),
                level: .none,   // level is recomputed by HeatmapGridBuilder
                isFuture: false
            )
        }.sorted { $0.date < $1.date }

        return days
    }

    // MARK: - Helpers

    private static func makeISOParser() -> DateFormatter {
        let f = DateFormatter()
        f.locale     = Locale(identifier: "en_US_POSIX")
        f.calendar   = Calendar(identifier: .gregorian)
        f.timeZone   = TimeZone(identifier: "UTC")!
        f.dateFormat = "yyyy-MM-dd"
        return f
    }
}
