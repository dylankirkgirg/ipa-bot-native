import Foundation

/// Handles ipabot:// deep links — the Share Extension's handoff
/// (ipabot://sign?url=...) and the StatusWidget's tap target
/// (ipabot://open?tab=diagnostics).
final class DeepLinkRouter: ObservableObject {
    @Published var pendingSignURL: String?
    @Published var pendingTab: AppTab?

    func handle(_ url: URL) {
        guard url.scheme == "ipabot" else { return }
        switch url.host {
        case "sign":
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            pendingSignURL = comps?.queryItems?.first(where: { $0.name == "url" })?.value
        case "open":
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let tabName = comps?.queryItems?.first(where: { $0.name == "tab" })?.value {
                pendingTab = AppTab(rawValue: tabName)
            }
        default:
            break
        }
    }
}
