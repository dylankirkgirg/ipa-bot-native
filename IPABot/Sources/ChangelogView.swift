import SwiftUI

struct ChangelogView: View {
    @EnvironmentObject var api: APIClient
    @Environment(\.dismiss) private var dismiss
    let query: String

    @State private var result: ChangelogResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(Ledger.accent)
                }
                if let result {
                    if result.versions.isEmpty {
                        Text("No version history published for \(result.app_name).").foregroundStyle(.secondary)
                    }
                    ForEach(result.versions) { v in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("v\(v.version)").font(Ledger.heading(14, weight: .semibold))
                                if let date = v.date {
                                    Text(date).font(Ledger.mono(11)).foregroundStyle(.secondary)
                                }
                            }
                            if let notes = v.notes {
                                Text(notes).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .ledgerBackground()
            .scrollIndicators(.hidden)
            .navigationTitle(result?.app_name ?? query)
            .navigationBarTitleDisplayMode(.inline)
            .overlay { if isLoading { ProgressView() } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true; errorMessage = nil
        do {
            result = try await api.changelog(query: query)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
