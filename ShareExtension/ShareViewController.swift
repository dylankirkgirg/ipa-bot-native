import UIKit
import UniformTypeIdentifiers

/// Share Sheet entry point: "share" an .ipa download link (Safari, Discord,
/// Telegram web, etc.) into IPABot and it opens straight to the Sign screen
/// with the URL prefilled. No UI of its own — it hands off to the host app
/// via a deep link and closes immediately.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        handleShare()
    }

    private func handleShare() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first else {
            close(); return
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] data, _ in
                DispatchQueue.main.async {
                    if let url = data as? URL { self?.openMainApp(with: url.absoluteString) }
                    else { self?.close() }
                }
            }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] data, _ in
                DispatchQueue.main.async {
                    if let text = data as? String, let url = URL(string: text) { self?.openMainApp(with: url.absoluteString) }
                    else { self?.close() }
                }
            }
        } else {
            close()
        }
    }

    private func openMainApp(with urlString: String) {
        guard var comps = URLComponents(string: "ipabot://sign") else { close(); return }
        comps.queryItems = [URLQueryItem(name: "url", value: urlString)]
        guard let deepLink = comps.url else { close(); return }
        extensionContext?.open(deepLink, completionHandler: nil)
        close()
    }

    private func close() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
