import Foundation

struct Hit: Codable, Identifiable {
    var source: String
    var emoji: String
    var app_name: String
    var bundle_id: String
    var version: String
    var date_iso: String
    var download_url: String
    var size_mb: Double
    var icon_url: String?
    var vault_msg_id: Int?
    var file_name: String?
    var is_modded: Bool?
    var starred: Bool?

    var id: String { "\(bundle_id)|\(version)|\(download_url)|\(vault_msg_id ?? 0)" }
}

struct SearchResponse: Codable {
    var hits: [Hit]
    var query: String
    var nl: [String]?
    var suggestions: [String]?
    var error: String?
}

struct ChannelResponse: Codable {
    var hits: [Hit]
    var available: [String]?
}

struct StarEntry: Codable, Identifiable {
    var app_name: String
    var bundle_id: String
    var version: String
    var icon_url: String?
    var source: String?
    var size_mb: Double?
    var download_url: String?
    var vault_msg_id: Int?
    var file_name: String?

    var id: String { bundle_id }
}

struct WatchEntry: Codable, Identifiable {
    var term: String
    var minVersion: String?
    var id: String { term }
}

struct PresetEntry: Codable, Identifiable {
    var id: String
    var name: String
    var tweaks: [String]
}

struct SourceEntry: Codable, Identifiable {
    var name: String
    var url: String?
    var emoji: String?
    var builtin: Bool?
    var blacklisted: Bool?
    var id: String { name }
}

struct NoteEntry: Codable, Identifiable {
    var bundle: String
    var text: String
    var id: String { bundle }
}

struct PinEntry: Codable, Identifiable {
    var bundle: String
    var version: String
    var id: String { bundle }
}

struct AliasEntry: Codable, Identifiable {
    var short: String
    var full: String
    var id: String { short }
}

struct TfWatchEntry: Codable, Identifiable {
    var url: String
    var name: String
    var status: String
    var checked_at: String?
    var id: String { url }
}

struct LibraryResponse: Codable {
    var stars: [StarEntry]
    var watches: [WatchEntry]
    var presets: [PresetEntry]?
    var sources: [SourceEntry]?
    var notes: [NoteEntry]?
    var pins: [PinEntry]?
    var aliases: [AliasEntry]?
    var tfWatches: [TfWatchEntry]?
    var error: String?
}

struct Tweak: Codable, Identifiable {
    var id: String
    var name: String
    var emoji: String
    var category: String
    var description: String
    var kind: String?
    var repo: String?
    var stored: String?
}

struct TweaksResponse: Codable {
    var tweaks: [Tweak]
    var error: String?
}

struct SignedApp: Codable, Identifiable {
    var id: String
    var title: String
    var version: String
    var bundle: String
    var ts: Double
}

struct SignedResponse: Codable {
    var signed: [SignedApp]
    var error: String?
}

struct SignOptions: Codable {
    var compress: String = "speed"
    var rm_uisupported = false
    var set_minos = false
    var rm_plugins = false
    var rm_watch = false
    var rm_urlscheme = false
    var doc_browser = false
    var rm_provision = false
}

struct SignResult: Codable {
    var ok: Bool
    var note: String?
    var error: String?
}

struct InjectResult: Codable {
    var ok: Bool
    var id: String?
    var web_id: String?
    var error: String?
}

struct JobPollResult: Codable {
    var pending: Bool?
    var url: String?
    var name: String?
    var error: String?
}

struct TextJobQueued: Codable {
    var ok: Bool
    var id: String?
    var error: String?
}

struct TextJobResult: Codable {
    var pending: Bool?
    var ok: Bool?
    var kind: String?
    var text: String?
    var error: String?
}

struct EmptyResponse: Codable {}

struct CertInfo: Codable, Identifiable {
    var name: String?
    var expiry: String?
    var has_profile: Bool?
    var id: String { name ?? "cert" }
}

struct CertsResponse: Codable {
    var certs: [CertInfo]
}

struct UploadResponse: Codable {
    var url: String
    var name: String
}

struct ActionResult: Codable {
    var ok: Bool
    var error: String?
}

struct SearchHistoryResponse: Codable {
    var history: [String]
}

struct DiffResponse: Codable {
    var query: String
    var vanilla: [DiffRow]
    var modded: [DiffRow]
}

struct DiffRow: Codable, Identifiable {
    var source: String
    var emoji: String
    var app_name: String
    var version: String
    var bundle: String
    var modded: Bool
    var size_mb: Double
    var date_iso: String
    var id: String { "\(source)|\(version)|\(bundle)" }
}

struct ChangelogResponse: Codable {
    var app_name: String
    var source: String
    var versions: [ChangelogVersion]
}

struct ChangelogVersion: Codable, Identifiable {
    var version: String
    var date: String?
    var notes: String?
    var id: String { version }
}

struct SniperResponse: Codable {
    var heartbeat: SniperHeartbeat?
}

struct SniperHeartbeat: Codable {
    var status: String
    var ageSec: Int
    var fresh: Bool
    var attempts: Int
    var throttles: Int
    var capacityDenials: Int
}

struct TrendingResponse: Codable {
    var trending: [TrendingEntry]
}

struct TweakCheckResponse: Codable {
    var total: Int
    var broken: [String]
}

struct DecryptBotResponse: Codable {
    var bot: String
}

struct ActionResultWithBot: Codable {
    var ok: Bool
    var bot: String?
    var error: String?
}

struct TrendingEntry: Codable, Identifiable {
    var original: String
    var count: Int
    var id: String { original }
}

struct QueueResponse: Codable {
    var type: String
    var pending: [QueueJobEntry]
}

struct QueueJobEntry: Codable, Identifiable {
    var id: String
    var url: String?
    var status: String?
    var requested_at: String?
}

struct DiscoverResponse: Codable {
    var artist_name: String?
    var apps: [DiscoverApp]
}

struct DiscoverApp: Codable, Identifiable {
    var bundle_id: String
    var app_name: String
    var hit: Hit?
    var id: String { bundle_id }
}

struct BulkActionResult: Codable {
    var ok: Bool
    var queued: Int?
    var skipped: Int?
    var total: Int?
    var error: String?
}

struct AboutInfo: Codable {
    var app_name: String
    var bundle_id: String
    var genre: String?
    var artist_name: String?
    var artwork_url: String?
    var rating: Double?
    var rating_count: Int?
    var latest_version: String?
    var latest_date: String?
    var source_count: Int
    var source_names: [String]?
    var vault_count: Int
    var starred: Bool
    var pinned_version: String?
    var auto_tweaks: [String]
    var note: String?
    var last_signed: LastSigned?
    var discoverable: Bool

    struct LastSigned: Codable {
        var version: String
        var ts: Double
    }
}

struct ServiceBeat: Codable {
    var ageSec: Int
    var fresh: Bool
}

struct StatusResponse: Codable {
    struct Services: Codable {
        var finder: ServiceBeat
        var relay: ServiceBeat
        var inject: ServiceBeat
    }
    struct Queues: Codable {
        var decrypt: Int
        var inject: Int
    }
    var services: Services
    var queues: Queues
    var signCount: Int
    var vaultEntries: Int
    var build: String
    var autosign: Bool?
    var iosVersion: String?
}
