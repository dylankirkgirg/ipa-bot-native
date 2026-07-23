import SwiftUI

struct DecryptView: View {
    @EnvironmentObject var api: APIClient
    @Environment(\.dismiss) private var dismiss

    @State private var urlText = ""
    @State private var isBusy = false
    @State private var statusNote: String?
    @State private var errorMessage: String?
    @State private var installTarget: DownloadTarget?
    @State private var pollTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("App Store or TestFlight link", text: $urlText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Label("Decrypt", systemImage: "lock.open")
                } footer: {
                    Text("apps.apple.com/… or testflight.apple.com/join/…")
                }

                if let statusNote {
                    Section {
                        Label(statusNote, systemImage: isBusy ? "hourglass" : "checkmark.circle.fill")
                            .foregroundStyle(isBusy ? Color.secondary : Color.green)
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
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
        for _ in 0..<90 {
            if Task.isCancelled { return }
            do {
                let result = try await api.decryptResult(id: id)
                if let url = result.url {
                    statusNote = "Done — \(result.name ?? "decrypted.ipa")"
                    installTarget = URL(string: url).map(DownloadTarget.init)
                    isBusy = false
                    return
                }
                if let err = result.error {
                    errorMessage = err
                    isBusy = false
                    return
                }
            } catch {
                // transient poll failure — keep trying until the loop times out
            }
            try? await Task.sleep(nanoseconds: 4_000_000_000)
        }
        errorMessage = "Timed out waiting for the decrypt job."
        isBusy = false
    }
}
