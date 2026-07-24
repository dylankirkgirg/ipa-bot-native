import AppIntents
import WidgetKit

/// Clears both decrypt and inject queues straight from the widget — for a
/// stuck job you'd otherwise have to open the app, go to Diagnostics, and
/// tap into each queue separately to clear.
@available(iOS 17.0, *)
struct ClearQueueIntent: AppIntent {
    static var title: LocalizedStringResource = "Clear IPABot Queues"

    func perform() async throws -> some IntentResult {
        if let cfg = SharedConfig.read() {
            for type in ["decrypt", "inject"] {
                _ = try? await post("/api/queue-clear", body: ["type": type], cfg: cfg)
            }
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "StatusWidget")
        return .result()
    }

    private func post(_ path: String, body: [String: Any], cfg: (baseURL: String, secret: String)) async throws {
        guard let url = URL(string: cfg.baseURL + path) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        var payload = body
        payload["k"] = cfg.secret
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        _ = try? await URLSession.shared.data(for: req)
    }
}
