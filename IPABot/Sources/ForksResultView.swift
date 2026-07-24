import SwiftUI

struct ForksResultView: View {
    @EnvironmentObject var api: APIClient
    @Environment(\.dismiss) private var dismiss
    let tweakId: String
    let tweakName: String

    @State private var result: ForksResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(Ledger.accent)
                }
                if let result {
                    LedgerKeyValueRow(key: "Original repo", value: result.parent_status)
                    if result.forks.isEmpty {
                        Text("No forks with a live .deb/.dylib release found.")
                            .font(Ledger.body(13)).foregroundColor(Ledger.textTertiary)
                    } else {
                        ForEach(result.forks) { fork in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(fork.repo).font(Ledger.body(14)).foregroundColor(Ledger.text)
                                Text("v\(fork.tag) · \(fork.date.prefix(10)) · ★\(fork.stars)")
                                    .font(Ledger.mono(11)).foregroundColor(Ledger.textTertiary)
                            }
                        }
                    }
                }
            }
            .ledgerBackground()
            .scrollIndicators(.hidden)
            .navigationTitle("Forks — \(tweakName)")
            .navigationBarTitleDisplayMode(.inline)
            .overlay { if isLoading { ProgressView() } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .task { await load() }
        }
    }

    private func load() async {
        do { result = try await api.forks(id: tweakId) } catch { errorMessage = error.localizedDescription }
        isLoading = false
    }
}
