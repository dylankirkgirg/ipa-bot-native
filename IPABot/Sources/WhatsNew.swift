import Foundation

/// Per-version changelog, keyed by MARKETING_VERSION (build-ipa.sh sets this
/// on real archives; simulator debug builds stay at project.yml's static
/// "1.0" and just never trigger the sheet, which is fine).
enum WhatsNew {
    static let entries: [String: [String]] = [
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

    static func shouldShow() -> Bool {
        guard currentEntries != nil else { return false }
        let lastSeen = UserDefaults.standard.string(forKey: lastSeenKey)
        return lastSeen != currentVersion
    }

    static func markSeen() {
        UserDefaults.standard.set(currentVersion, forKey: lastSeenKey)
    }
}
