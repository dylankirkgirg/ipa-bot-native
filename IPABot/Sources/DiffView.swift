import SwiftUI

struct DiffView: View {
    @EnvironmentObject var api: APIClient
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var result: DiffResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("App name", text: $query)
                        .autocorrectionDisabled()
                        .onSubmit { Task { await run() } }
                } header: {
                    Label("Diff", systemImage: "arrow.left.arrow.right")
                } footer: {
                    Text("Vanilla vs modded builds side by side.")
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }

                if let result {
                    Section("Vanilla (\(result.vanilla.count))") {
                        if result.vanilla.isEmpty {
                            Text("None found.").foregroundStyle(.secondary)
                        }
                        ForEach(result.vanilla) { row in diffRow(row) }
                    }
                    Section("Modded (\(result.modded.count))") {
                        if result.modded.isEmpty {
                            Text("None found.").foregroundStyle(.secondary)
                        }
                        ForEach(result.modded) { row in diffRow(row) }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Diff")
            .navigationBarTitleDisplayMode(.inline)
            .overlay { if isLoading { ProgressView() } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Go") { Task { await run() } }
                        .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
            }
        }
    }

    @ViewBuilder
    private func diffRow(_ row: DiffRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(row.emoji) \(row.app_name)").font(.subheadline)
            Text("\(row.source) · v\(row.version)" + (row.size_mb > 0 ? " · \(Int(row.size_mb)) MB" : ""))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func run() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        isLoading = true; errorMessage = nil
        do {
            result = try await api.diff(query: q)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
