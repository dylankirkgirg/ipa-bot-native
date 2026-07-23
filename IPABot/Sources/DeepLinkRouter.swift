import Foundation

/// Handles ipabot:// deep links — currently just the Share Extension's
/// handoff (ipabot://sign?url=...). Grows a case per scheme action if more
/// show up later.
final class DeepLinkRouter: ObservableObject {
    @Published var pendingSignURL: String?

    func handle(_ url: URL) {
        guard url.scheme == "ipabot", url.host == "sign" else { return }
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        pendingSignURL = comps?.queryItems?.first(where: { $0.name == "url" })?.value
    }
}
