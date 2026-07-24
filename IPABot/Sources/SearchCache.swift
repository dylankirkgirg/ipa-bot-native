import Foundation

/// Caches the last successful /api/recent or /api/search result set so
/// Search shows something instead of a bare error when the Worker's
/// unreachable. Keyed by query ("" for recent) so a repeat search of the
/// same term still benefits, capped to keep UserDefaults small.
enum SearchCache {
    private static let key = "ipabot.searchCache"
    private static let maxHits = 40

    private struct Cached: Codable {
        var query: String
        var hits: [Hit]
        var savedAt: Date
    }

    static func save(query: String, hits: [Hit]) {
        let entry = Cached(query: query, hits: Array(hits.prefix(maxHits)), savedAt: Date())
        guard let data = try? JSONEncoder().encode(entry) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    /// Returns cached hits for `query` plus how long ago they were saved, or
    /// nil if there's no cache or it's for a different query.
    static func load(query: String) -> (hits: [Hit], age: TimeInterval)? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let entry = try? JSONDecoder().decode(Cached.self, from: data),
              entry.query == query else { return nil }
        return (entry.hits, Date().timeIntervalSince(entry.savedAt))
    }
}
