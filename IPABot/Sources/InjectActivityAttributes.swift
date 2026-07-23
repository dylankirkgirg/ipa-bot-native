import ActivityKit

/// Shared between the app (starts/updates/ends the activity from the
/// existing sign/inject/decrypt poll loops — no push-to-update needed since
/// the app is already polling) and the widget extension (renders it).
struct InjectActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: String // "running" | "done" | "failed"
        var detail: String
    }
    var jobId: String
    var appName: String
    var kind: String // "sign" | "inject" | "decrypt"
}
