import SwiftUI

/// Shake-to-report: snapshots current diagnostics (service health, queue
/// depth, build, sniper status) into plain text you can send yourself —
/// no screen-pixel capture, the useful payload here is the diagnostics data.
struct ReportBugView: View {
    @EnvironmentObject var api: APIClient
    @Environment(\.dismiss) private var dismiss

    @State private var notes = ""
    @State private var snapshot = "Gathering diagnostics…"
    @State private var isLoading = true
    @State private var shareTarget: ShareTarget?

    var body: some View {
        NavigationStack {
            Form {
                Section("What happened?") {
                    TextEditor(text: $notes).frame(minHeight: 100)
                }
                Section("Diagnostics snapshot") {
                    Text(snapshot).font(Ledger.mono(11)).foregroundColor(Ledger.textSecondary)
                }
            }
            .ledgerBackground()
            .navigationTitle("Report a Bug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Share") { share() }.disabled(isLoading)
                }
            }
            .task { await load() }
            .sheet(item: $shareTarget) { target in ShareSheet(items: [target.url]) }
        }
    }

    private func load() async {
        var lines = [
            "IPABot bug report",
            "time: \(ISO8601DateFormatter().string(from: Date()))",
        ]
        if let status = try? await api.status() {
            lines.append("build: \(status.build)")
            lines.append("services: finder=\(status.services.finder.fresh ? "up" : "down") relay=\(status.services.relay.fresh ? "up" : "down") inject=\(status.services.inject.fresh ? "up" : "down")")
            lines.append("queue: decrypt=\(status.queues.decrypt) inject=\(status.queues.inject)")
            lines.append("signed: \(status.signCount), vault: \(status.vaultEntries)")
        } else {
            lines.append("couldn't reach the server for status")
        }
        if let sniper = try? await api.sniper().heartbeat {
            lines.append("sniper: \(sniper.status) (\(sniper.fresh ? "fresh" : "stale"))")
        }
        snapshot = lines.joined(separator: "\n")
        isLoading = false
    }

    private func share() {
        let full = "\(notes.isEmpty ? "(no description)" : notes)\n\n---\n\(snapshot)"
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("ipabot-report-\(Int(Date().timeIntervalSince1970)).txt")
        try? full.write(to: tmp, atomically: true, encoding: .utf8)
        shareTarget = ShareTarget(url: tmp)
    }
}
