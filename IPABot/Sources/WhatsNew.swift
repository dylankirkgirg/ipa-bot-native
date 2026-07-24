import Foundation

/// Per-version changelog, keyed by MARKETING_VERSION (build-ipa.sh sets this
/// on real archives; simulator debug builds stay at project.yml's static
/// "1.0" and just never trigger the sheet, which is fine).
enum WhatsNew {
    static let entries: [String: [String]] = [
        "1.1.11": [
            "Check starred apps for updates and sign the new version in one tap",
            "Signed apps now show days left before their 7-day cert expires, with a reminder before they die",
            "Multi-select \"Compare\" in Search, offline-tolerant star toggles, per-source reliability flag",
            "Siri: \"sign my starred apps\"; Trending rows can be quick-watched",
            "A1 Sniper staleness alert, interactive \"Clear queue\" button on the widget",
            "Settings is now two tabs — Bot and App — instead of one long scroll",
            "Fixed the Search header clipping the Select button on smaller screens",
            "Removed the scroll bar that showed on the right edge of every list",
        ],
        "1.1.9": [
            "Fixed a keyboard dead-end on the iOS version field and Search",
            "Fixed Sign > custom file upload always failing",
            "Cleaned up the crowded Search header buttons",
        ],
        "1.1.8": [
            "Settings wiring for tweak-check, decrypt bot, forks, and a Danger Zone wipe (confirmation-gated)",
            "Search history clear button",
            "App icon badge showing pending queue depth",
            "Copy bundle ID / download URL from Search, Discover, and Channels",
        ],
        "1.1.7": [
            "Siri Shortcuts: \"check my queue\" and \"sign an IPA\"",
            "Search sort (size/date/name) and modded-only filter",
            "Shake the phone anywhere to file a diagnostics report",
        ],
        "1.1.6": [
            "Home Screen widget — queue depth, signed count, A1 sniper status",
            "Multi-select + Sign All in Search",
        ],
        "1.1.5": [
            "Share an .ipa link straight into Sign from Safari or Discord",
            "Lock Screen / Dynamic Island progress for sign, inject, and decrypt jobs",
        ],
    ]

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    static var currentEntries: [String]? { entries[currentVersion] }

    private static let lastSeenKey = "ipabot.lastSeenVersion"

    static func markSeen() {
        UserDefaults.standard.set(currentVersion, forKey: lastSeenKey)
    }
}
