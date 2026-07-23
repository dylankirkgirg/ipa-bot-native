import Foundation

enum APIError: Error, LocalizedError {
    case notConfigured
    case http(Int)
    case decode

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Set your server URL and secret in Settings first."
        case .http(let code): return "Server returned HTTP \(code)."
        case .decode: return "Couldn't parse the server's response."
        }
    }
}

@MainActor
final class APIClient: ObservableObject {
    static let shared = APIClient()

    @Published var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: "ipabot.baseURL") }
    }
    @Published var secret: String {
        didSet { UserDefaults.standard.set(secret, forKey: "ipabot.secret") }
    }

    var isConfigured: Bool { !baseURL.isEmpty && !secret.isEmpty }

    private init() {
        baseURL = UserDefaults.standard.string(forKey: "ipabot.baseURL") ?? "https://ipa-bot.dihblud1.workers.dev"
        secret = UserDefaults.standard.string(forKey: "ipabot.secret") ?? ""
    }

    private func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        guard isConfigured, var comps = URLComponents(string: baseURL + path) else { throw APIError.notConfigured }
        comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        var req = URLRequest(url: comps.url!)
        req.setValue(secret, forHTTPHeaderField: "X-Inject-Secret")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.http((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        do { return try JSONDecoder().decode(T.self, from: data) } catch { throw APIError.decode }
    }

    @discardableResult
    private func post<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        guard isConfigured, let url = URL(string: baseURL + path) else { throw APIError.notConfigured }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        var payload = body
        payload["k"] = secret
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.http((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        do { return try JSONDecoder().decode(T.self, from: data) } catch { throw APIError.decode }
    }

    private func post(_ path: String, body: [String: Any]) async throws {
        let _: EmptyResponse = try await post(path, body: body)
    }

    func search(_ query: String) async throws -> SearchResponse {
        try await get("/api/search", query: ["q": query])
    }

    func recent() async throws -> SearchResponse {
        try await get("/api/recent")
    }

    func library() async throws -> LibraryResponse {
        try await get("/api/library")
    }

    func status() async throws -> StatusResponse {
        try await get("/api/status")
    }

    func setStar(bundleId: String, on: Bool) async throws {
        try await post("/api/star", body: ["bundle_id": bundleId, "on": on])
    }

    func addWatch(term: String) async throws {
        try await post("/api/watch-add", body: ["term": term])
    }

    func removeWatch(term: String) async throws {
        try await post("/api/watch-remove", body: ["term": term])
    }

    func signed() async throws -> SignedResponse {
        try await get("/api/signed")
    }

    func tweaks() async throws -> TweaksResponse {
        try await get("/api/tweaks")
    }

    func removePreset(name: String) async throws {
        try await post("/api/preset-delete", body: ["name": name])
    }

    func removeNote(bundle: String) async throws {
        try await post("/api/note-delete", body: ["bundle": bundle])
    }

    func removePin(bundle: String) async throws {
        try await post("/api/pin-delete", body: ["bundle": bundle])
    }

    func removeAlias(short: String) async throws {
        try await post("/api/alias-delete", body: ["short": short])
    }

    func removeTfWatch(id: String) async throws {
        try await post("/api/tfwatch-remove", body: ["id": id])
    }

    func removeSource(name: String) async throws {
        try await post("/api/source-remove", body: ["name": name])
    }
}
