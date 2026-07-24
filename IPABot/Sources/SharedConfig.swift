import Foundation

/// App Group bridge so the widget extension (a separate process, no Keychain
/// access to the main app's items) can read the server URL + secret. Not
/// Keychain-backed on the shared side — App Group UserDefaults is already
/// sandboxed to this app + its own extensions, and avoids the
/// keychain-access-groups + AppIdentifierPrefix dance under ad-hoc signing.
enum SharedConfig {
    static let suiteName = "group.com.dylankirkgirg.ipabot"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: suiteName) }

    static func write(baseURL: String, secret: String) {
        defaults?.set(baseURL, forKey: "baseURL")
        defaults?.set(secret, forKey: "secret")
    }

    static func read() -> (baseURL: String, secret: String)? {
        guard let d = defaults,
              let baseURL = d.string(forKey: "baseURL"), !baseURL.isEmpty,
              let secret = d.string(forKey: "secret"), !secret.isEmpty else { return nil }
        return (baseURL, secret)
    }
}
