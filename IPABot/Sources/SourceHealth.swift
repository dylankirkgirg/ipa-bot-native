import Foundation

/// Tracks download/sign failures per search source (Hit.source) locally, so
/// flaky sources get a visible warning without any server-side health check.
enum SourceHealth {
    private static let key = "ipabot.sourceFailures"
    private static let window: TimeInterval = 24 * 3600
    private static let threshold = 2

    private static func load() -> [String: [TimeInterval]] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let dict = try? JSONDecoder().decode([String: [TimeInterval]].self, from: data) else { return [:] }
        return dict
    }

    private static func save(_ dict: [String: [TimeInterval]]) {
        guard let data = try? JSONEncoder().encode(dict) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func recordFailure(source: String) {
        guard !source.isEmpty else { return }
        var dict = load()
        let now = Date().timeIntervalSince1970
        var stamps = (dict[source] ?? []).filter { now - $0 < window }
        stamps.append(now)
        dict[source] = stamps
        save(dict)
    }

    static func isFlaky(source: String) -> Bool {
        let now = Date().timeIntervalSince1970
        let stamps = (load()[source] ?? []).filter { now - $0 < window }
        return stamps.count >= threshold
    }
}
