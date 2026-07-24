import Foundation

/// Star toggles made while the Worker's unreachable queue here instead of
/// silently reverting — flushed on the next successful network call.
enum PendingStarQueue {
    private static let key = "ipabot.pendingStars"

    struct Entry: Codable {
        var bundleId: String
        var on: Bool
    }

    private static func load() -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        return entries
    }

    private static func save(_ entries: [Entry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func enqueue(bundleId: String, on: Bool) {
        var entries = load().filter { $0.bundleId != bundleId }
        entries.append(Entry(bundleId: bundleId, on: on))
        save(entries)
    }

    static var count: Int { load().count }

    /// Replays every queued toggle against the API, dropping each on success
    /// and leaving failures queued for the next flush.
    static func flush(api: APIClient) async {
        let entries = load()
        guard !entries.isEmpty else { return }
        var remaining: [Entry] = []
        for entry in entries {
            do {
                try await api.setStar(bundleId: entry.bundleId, on: entry.on)
            } catch {
                remaining.append(entry)
            }
        }
        save(remaining)
    }
}
