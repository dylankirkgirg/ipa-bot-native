import SwiftUI
import ActivityKit

struct DecryptView: View {
    @EnvironmentObject var api: APIClient
    @Environment(\.dismiss) private var dismiss

    @State private var urlText = ""
    @State private var isBusy = false
    @State private var statusNote: String?
    @State private var errorMessage: String?
    @State private var installTarget: DownloadTarget?
    @State private var pollTask: Task<Void, Never>?
    @State private var activityBox: Any?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("App Store or TestFlight link", text: $urlText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Decrypt")
                } footer: {
                    Text("apps.apple.com/… or testflight.apple.com/join/…")
                }

                if let statusNote {
                    Section {
                        Text(statusNote).foregroundStyle(isBusy ? Color.secondary : Ledger.ok)
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(Ledger.accent)
                    }
                }
            }
            .ledgerBackground()
            .navigationTitle("Decrypt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { pollTask?.cancel(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Go") { Task { await startDecrypt() } }
                        .disabled(isBusy || urlText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(item: $installTarget) { target in
                SafariView(url: target.url)
            }
        }
    }

    private func startDecrypt() async {
        isBusy = true; errorMessage = nil; statusNote = nil
        do {
            let result = try await api.decrypt(url: urlText.trimmingCharacters(in: .whitespaces))
            guard result.ok, let id = result.id else {
                errorMessage = result.error ?? "Decrypt request failed."
                isBusy = false
                return
            }
            statusNote = "Decrypting — this can take a few minutes…"
            pollTask?.cancel()
            pollTask = Task { await poll(id: id) }
        } catch {
            errorMessage = error.localizedDescription
            isBusy = false
        }
    }

    private func poll(id: String) async {
        if #available(iOS 16.2, *) {
            activityBox = LiveActivityManager.start(jobId: id, appName: urlText, kind: "decrypt")
        }
        let bgGuard = BackgroundTaskGuard()
        bgGuard.begin()
        defer { bgGuard.end() }
        for _ in 0..<90 {
            if Task.isCancelled { return }
            do {
                let result = try await api.decryptResult(id: id)
                if let url = result.url {
                    statusNote = "Done — \(result.name ?? "decrypted.ipa")"
                    installTarget = URL(string: url).map(DownloadTarget.init)
                    isBusy = false
                    endActivity(status: "done", detail: result.name ?? "Done")
                    return
                }
                if let err = result.error {
                    errorMessage = err
                    isBusy = false
                    endActivity(status: "failed", detail: err)
                    return
                }
            } catch {
                // transient poll failure — keep trying until the loop times out
            }
            try? await Task.sleep(nanoseconds: 4_000_000_000)
        }
        errorMessage = "Timed out waiting for the decrypt job."
        isBusy = false
        endActivity(status: "failed", detail: "Timed out")
    }

    private func endActivity(status: String, detail: String) {
        if #available(iOS 16.2, *) {
            LiveActivityManager.end(activityBox as? Activity<InjectActivityAttributes>, status: status, detail: detail)
        }
        activityBox = nil
    }
}
