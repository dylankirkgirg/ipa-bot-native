import AppIntents

struct CheckQueueIntent: AppIntent {
    static var title: LocalizedStringResource = "Check IPABot Queue"
    static var description = IntentDescription("Pending decrypt/inject jobs and A1 sniper status.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard APIClient.shared.isConfigured else {
            return .result(dialog: "IPABot isn't configured yet — open the app and set your server URL.")
        }
        do {
            let status = try await APIClient.shared.status()
            let total = status.queues.decrypt + status.queues.inject
            let queueLine = total == 0
                ? "Queue is empty."
                : "\(total) job\(total == 1 ? "" : "s") queued — \(status.queues.decrypt) decrypt, \(status.queues.inject) inject."
            return .result(dialog: IntentDialog(stringLiteral: queueLine))
        } catch {
            return .result(dialog: "Couldn't reach the server.")
        }
    }
}

struct SignURLIntent: AppIntent {
    static var title: LocalizedStringResource = "Sign IPA URL"
    static var description = IntentDescription("Queue a direct .ipa URL for signing.")

    @Parameter(title: "IPA URL")
    var ipaURL: URL

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard APIClient.shared.isConfigured else {
            return .result(dialog: "IPABot isn't configured yet — open the app and set your server URL.")
        }
        do {
            let result = try await APIClient.shared.sign(ipaUrl: ipaURL.absoluteString, ipaName: ipaURL.lastPathComponent, options: SignOptions())
            let line = result.ok ? (result.note ?? "Signing queued.") : (result.error ?? "Sign request failed.")
            return .result(dialog: IntentDialog(stringLiteral: line))
        } catch {
            return .result(dialog: "Request failed: \(error.localizedDescription)")
        }
    }
}

struct IPABotShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckQueueIntent(),
            phrases: ["Check my \(.applicationName) queue", "\(.applicationName) queue status"],
            shortTitle: "Check Queue",
            systemImageName: "list.bullet"
        )
        AppShortcut(
            intent: SignURLIntent(),
            phrases: ["Sign an IPA in \(.applicationName)"],
            shortTitle: "Sign IPA",
            systemImageName: "signature"
        )
    }
}
