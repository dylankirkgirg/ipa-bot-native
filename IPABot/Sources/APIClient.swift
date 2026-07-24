import Foundation
import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

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
        didSet {
            UserDefaults.standard.set(baseURL, forKey: "ipabot.baseURL")
            SharedConfig.write(baseURL: baseURL, secret: secret)
        }
    }
    @Published var secret: String {
        didSet {
            Keychain.set(secret, for: "ipabot.secret")
            SharedConfig.write(baseURL: baseURL, secret: secret)
        }
    }
    @Published var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "ipabot.theme") }
    }

    var isConfigured: Bool {
        !baseURL.isEmpty && !secret.isEmpty && baseURL.lowercased().hasPrefix("https://")
    }

    private init() {
        baseURL = UserDefaults.standard.string(forKey: "ipabot.baseURL") ?? "https://ipa-bot.dihblud1.workers.dev"
        if let migrated = UserDefaults.standard.string(forKey: "ipabot.secret") {
            Keychain.set(migrated, for: "ipabot.secret")
            UserDefaults.standard.removeObject(forKey: "ipabot.secret")
        }
        secret = Keychain.get("ipabot.secret") ?? ""
        theme = AppTheme(rawValue: UserDefaults.standard.string(forKey: "ipabot.theme") ?? "") ?? .system
        SharedConfig.write(baseURL: baseURL, secret: secret)
    }

    private func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        guard isConfigured, var comps = URLComponents(string: baseURL + path) else { throw APIError.notConfigured }
        comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = comps.url else { throw APIError.notConfigured }
        var req = URLRequest(url: url)
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

    func inject(hit: Hit, tweakIds: [String]) async throws -> InjectResult {
        let hitData = try JSONEncoder().encode(hit)
        let hitDict = try JSONSerialization.jsonObject(with: hitData) as? [String: Any] ?? [:]
        return try await post("/api/inject", body: ["hit": hitDict, "tweak_ids": tweakIds])
    }

    func injectCustom(hit: Hit, customUrl: String) async throws -> InjectResult {
        let hitData = try JSONEncoder().encode(hit)
        let hitDict = try JSONSerialization.jsonObject(with: hitData) as? [String: Any] ?? [:]
        return try await post("/api/inject", body: ["hit": hitDict, "custom_url": customUrl])
    }

    func addTweak(id: String, bundle: String, name: String, repo: String, emoji: String) async throws -> ActionResult {
        try await post("/api/tweak-add", body: ["id": id, "bundle": bundle, "name": name, "repo": repo, "emoji": emoji])
    }

    func removeTweak(id: String) async throws -> ActionResult {
        try await post("/api/tweak-remove", body: ["id": id])
    }

    func injectResult(id: String) async throws -> JobPollResult {
        try await get("/api/inject-result", query: ["id": id])
    }

    func sign(ipaUrl: String, ipaName: String, options: SignOptions, vaultMsgId: Int? = nil) async throws -> SignResult {
        let optData = try JSONEncoder().encode(options)
        let optDict = try JSONSerialization.jsonObject(with: optData) as? [String: Any] ?? [:]
        var body: [String: Any] = ["ipa_url": ipaUrl, "ipa_name": ipaName, "options": optDict]
        if let vaultMsgId { body["vault_msg_id"] = vaultMsgId }
        return try await post("/api/sign", body: body)
    }

    func certs() async throws -> CertsResponse {
        try await get("/api/certs")
    }

    func inspect(ipaUrl: String, ipaName: String, vaultMsgId: Int? = nil) async throws -> TextJobQueued {
        var body: [String: Any] = ["ipa_url": ipaUrl, "ipa_name": ipaName]
        if let vaultMsgId { body["vault_msg_id"] = vaultMsgId }
        return try await post("/api/inspect", body: body)
    }

    func entitlements(ipaUrl: String, ipaName: String, vaultMsgId: Int? = nil) async throws -> TextJobQueued {
        var body: [String: Any] = ["ipa_url": ipaUrl, "ipa_name": ipaName]
        if let vaultMsgId { body["vault_msg_id"] = vaultMsgId }
        return try await post("/api/entitlements", body: body)
    }

    func textJobResult(id: String) async throws -> TextJobResult {
        try await get("/api/textjob-result", query: ["id": id])
    }

    func decrypt(url: String) async throws -> InjectResult {
        try await post("/api/decrypt", body: ["url": url])
    }

    func decryptResult(id: String) async throws -> JobPollResult {
        try await get("/api/decrypt-result", query: ["id": id])
    }

    func addNote(bundle: String, text: String) async throws -> ActionResult {
        try await post("/api/note-save", body: ["bundle": bundle, "text": text])
    }

    func addPin(bundle: String, version: String) async throws -> ActionResult {
        try await post("/api/pin-save", body: ["bundle": bundle, "version": version])
    }

    func addAlias(short: String, full: String) async throws -> ActionResult {
        try await post("/api/alias-save", body: ["short": short, "full": full])
    }

    func addTfWatch(url: String) async throws -> ActionResult {
        try await post("/api/tfwatch-add", body: ["url": url])
    }

    func addSource(name: String, url: String, emoji: String) async throws -> ActionResult {
        try await post("/api/source-add", body: ["name": name, "url": url, "emoji": emoji])
    }

    func savePreset(name: String, tweakIds: [String]) async throws -> ActionResult {
        try await post("/api/preset-save", body: ["name": name, "tweak_ids": tweakIds])
    }

    func searchHistory() async throws -> SearchHistoryResponse {
        try await get("/api/search-history")
    }

    func clearHistory() async throws {
        try await post("/api/clearhistory", body: [:])
    }

    func about(bundle: String) async throws -> AboutInfo {
        try await get("/api/about", query: ["bundle": bundle])
    }

    func rebuildAll() async throws -> BulkActionResult {
        try await post("/api/rebuildall", body: [:])
    }

    func resignAll() async throws -> BulkActionResult {
        try await post("/api/resignall", body: [:])
    }

    func setAutosign(_ on: Bool) async throws -> ActionResult {
        try await post("/api/autosign", body: ["on": on])
    }

    func setIosVersion(_ version: String) async throws -> ActionResult {
        try await post("/api/ios-set", body: ["version": version])
    }

    func decryptBot() async throws -> DecryptBotResponse {
        try await get("/api/decrypt-bot")
    }

    func forks(id: String) async throws -> ForksResponse {
        try await get("/api/forks", query: ["id": id])
    }

    func setDecryptBot(_ handle: String) async throws -> ActionResultWithBot {
        try await post("/api/decrypt-bot-set", body: ["handle": handle])
    }

    func diff(query: String) async throws -> DiffResponse {
        try await get("/api/diff", query: ["q": query])
    }

    func changelog(query: String) async throws -> ChangelogResponse {
        try await get("/api/changelog", query: ["q": query])
    }

    func random(moddedOnly: Bool = false) async throws -> SearchResponse {
        try await get("/api/random", query: moddedOnly ? ["mod": "1"] : [:])
    }

    func discover(bundle: String) async throws -> DiscoverResponse {
        try await get("/api/discover", query: ["bundle": bundle])
    }

    func trending() async throws -> TrendingResponse {
        try await get("/api/trending")
    }

    func tweakCheck() async throws -> TweakCheckResponse {
        try await get("/api/tweakcheck")
    }

    func channel(_ q: String) async throws -> ChannelResponse {
        try await get("/api/channel", query: q.isEmpty ? [:] : ["q": q])
    }

    func sniper() async throws -> SniperResponse {
        try await get("/api/sniper")
    }

    func queue(type: String) async throws -> QueueResponse {
        try await get("/api/queue", query: ["type": type])
    }

    func cancelQueueJob(type: String, id: String) async throws -> ActionResult {
        try await post("/api/queue-cancel", body: ["type": type, "id": id])
    }

    func clearQueue(type: String) async throws -> ActionResult {
        try await post("/api/queue-clear", body: ["type": type])
    }

    func backupNow() async throws -> SignResult {
        try await post("/api/backup-now", body: [:])
    }

    func restartService(_ service: String) async throws -> ActionResult {
        try await post("/api/restart", body: ["service": service])
    }

    func exportDump() async throws -> URL {
        guard isConfigured, let url = URL(string: baseURL + "/api/export") else { throw APIError.notConfigured }
        var req = URLRequest(url: url)
        req.setValue(secret, forHTTPHeaderField: "X-Inject-Secret")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.http((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let stamp = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("ipabot-export-\(stamp).json")
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    // Files upload straight to the Oracle VM's control daemon, same endpoint the
    // web app uses — the Worker caps request bodies at 100MB, this bypasses it.
    private static let uploadEndpoint = URL(string: "https://129-80-130-200.sslip.io/control/upload")!

    func uploadFile(data: Data, filename: String) async throws -> UploadResponse {
        guard isConfigured else { throw APIError.notConfigured }
        var req = URLRequest(url: Self.uploadEndpoint)
        req.httpMethod = "POST"
        req.setValue(secret, forHTTPHeaderField: "X-Inject-Secret")
        req.setValue(filename, forHTTPHeaderField: "X-Filename")
        let (data, resp) = try await URLSession.shared.upload(for: req, from: data)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.http((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(UploadResponse.self, from: data)
    }

    func submitCertPart(part: String, ipaUrl: String? = nil, fileName: String? = nil, password: String? = nil) async throws -> ActionResult {
        var body: [String: Any] = ["part": part]
        if let ipaUrl { body["ipa_url"] = ipaUrl }
        if let fileName { body["file_name"] = fileName }
        if let password { body["password"] = password }
        return try await post("/api/cert-upload", body: body)
    }

    // Streams the raw .ipa bytes back — used for TG-vault hits, which carry no
    // public download_url and must be resolved server-side via vault_msg_id.
    func downloadFile(url: String? = nil, vaultMsgId: Int? = nil, name: String) async throws -> URL {
        guard isConfigured, let endpoint = URL(string: baseURL + "/api/download") else { throw APIError.notConfigured }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        var payload: [String: Any] = ["k": secret, "name": name]
        if let url { payload["url"] = url }
        if let vaultMsgId { payload["vault_msg_id"] = vaultMsgId }
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.http((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        if let contentType = http.value(forHTTPHeaderField: "content-type"), contentType.contains("json") {
            struct Err: Codable { var ok: Bool; var error: String? }
            let e = try? JSONDecoder().decode(Err.self, from: data)
            throw NSError(domain: "IPABot", code: -1, userInfo: [NSLocalizedDescriptionKey: e?.error ?? "Download failed."])
        }
        let safeName = name.isEmpty ? "app.ipa" : name
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(safeName)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}
