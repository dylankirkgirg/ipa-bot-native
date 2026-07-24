import SwiftUI

struct TrendingView: View {
    @EnvironmentObject var api: APIClient
    @Environment(\.dismiss) private var dismiss
    var onSelect: (String) -> Void

    @State private var trending: [TrendingEntry] = []
    @State private var watchedTerms: Set<String> = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(Ledger.accent)
                }
                if trending.isEmpty && !isLoading && errorMessage == nil {
                    Text("Not enough search history yet.").foregroundStyle(.secondary)
                }
                ForEach(trending) { entry in
                    HStack {
                        Button {
                            onSelect(entry.original)
                            dismiss()
                        } label: {
                            HStack {
                                Text(entry.original).foregroundColor(Ledger.text)
                                Spacer()
                                if entry.count > 1 {
                                    Text("×\(entry.count)").foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        let isWatched = watchedTerms.contains(entry.original.lowercased())
                        Button { Task { await toggleWatch(entry.original) } } label: {
                            Glyph(.eye, size: 15, color: isWatched ? Ledger.accent : Ledger.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                        .accessibilityLabel(isWatched ? "Stop watching \(entry.original)" : "Watch \(entry.original)")
                    }
                }
            }
            .ledgerBackground()
            .scrollIndicators(.hidden)
            .navigationTitle("Trending")
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
            trending = try await api.trending().trending
        } catch {
            errorMessage = error.localizedDescription
        }
        watchedTerms = Set((try? await api.library().watches.map { $0.term.lowercased() }) ?? [])
        isLoading = false
    }

    private func toggleWatch(_ term: String) async {
        let key = term.lowercased()
        do {
            if watchedTerms.contains(key) {
                try await api.removeWatch(term: term)
                watchedTerms.remove(key)
            } else {
                try await api.addWatch(term: term)
                watchedTerms.insert(key)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
