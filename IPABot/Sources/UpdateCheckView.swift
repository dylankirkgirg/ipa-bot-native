import SwiftUI

/// Checks every starred app's About info for a newer version than what's
/// pinned/starred, lets you queue a sign for each stale one straight from the
/// result list — no separate trip through Search.
struct UpdateCheckView: View {
    @EnvironmentObject var api: APIClient
    @Environment(\.dismiss) private var dismiss
    let stars: [StarEntry]

    struct StaleEntry: Identifiable {
        let star: StarEntry
        let latestVersion: String
        var id: String { star.bundle_id }
    }

    @State private var isChecking = true
    @State private var stale: [StaleEntry] = []
    @State private var signingBundleId: String?
    @State private var resultAlert: ResultAlert?
    @State private var checkedCount = 0

    struct ResultAlert: Identifiable { let id = UUID(); let message: String }

    var body: some View {
        NavigationStack {
            List {
                if isChecking {
                    HStack {
                        ProgressView()
                        Text("Checking \(checkedCount) of \(stars.count)…")
                            .font(Ledger.body(13)).foregroundColor(Ledger.textSecondary)
                    }
                    .listRowSeparator(.hidden).listRowBackground(Color.clear)
                } else if stale.isEmpty {
                    Text("Everything starred is up to date.")
                        .font(Ledger.body(14)).foregroundColor(Ledger.textSecondary)
                        .listRowSeparator(.hidden).listRowBackground(Color.clear)
                } else {
                    ForEach(stale) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.star.app_name).font(Ledger.heading(14, weight: .semibold)).foregroundColor(Ledger.text)
                                Text("v\(entry.star.version) → v\(entry.latestVersion)")
                                    .font(Ledger.mono(11)).foregroundColor(Ledger.textSecondary)
                            }
                            Spacer()
                            Button(signingBundleId == entry.id ? "…" : "Sign") { Task { await signLatest(entry) } }
                                .buttonStyle(LedgerOutlineButtonStyle())
                                .frame(width: 70)
                                .disabled(signingBundleId != nil)
                        }
                        .padding(.vertical, 4)
                        .listRowSeparator(.hidden).listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .ledgerBackground()
            .navigationTitle("Check for Updates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .alert(item: $resultAlert) { alert in
                Alert(title: Text("Sign"), message: Text(alert.message), dismissButton: .default(Text("OK")))
            }
            .task { await checkAll() }
        }
    }

    private func checkAll() async {
        for star in stars {
            checkedCount += 1
            guard let info = try? await api.about(bundle: star.bundle_id),
                  let latest = info.latest_version, !latest.isEmpty,
                  latest != star.version else { continue }
            stale.append(StaleEntry(star: star, latestVersion: latest))
        }
        isChecking = false
    }

    private func signLatest(_ entry: StaleEntry) async {
        signingBundleId = entry.id
        defer { signingBundleId = nil }
        do {
            // The star entry only carries the version it was starred at — find
            // the hit matching the latest version to get a real download source.
            let hits = try await api.search(entry.star.bundle_id).hits
            guard let hit = hits.first(where: { $0.bundle_id == entry.star.bundle_id && $0.version == entry.latestVersion }) else {
                resultAlert = ResultAlert(message: "Couldn't find a download source for v\(entry.latestVersion).")
                return
            }
            let result = try await api.sign(ipaUrl: hit.download_url, ipaName: hit.app_name, options: SignOptions(), vaultMsgId: hit.vault_msg_id)
            resultAlert = ResultAlert(message: result.ok ? (result.note ?? "Signing queued.") : (result.error ?? "Sign failed."))
        } catch {
            resultAlert = ResultAlert(message: error.localizedDescription)
        }
    }
}
