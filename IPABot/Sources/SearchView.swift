import SwiftUI

struct SearchView: View {
    @EnvironmentObject var api: APIClient
    @State private var query = ""
    @State private var hits: [Hit] = []
    @State private var suggestions: [String] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var downloadTarget: DownloadTarget?
    @State private var injectTarget: Hit?

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
                if !suggestions.isEmpty {
                    Section("Did you mean?") {
                        ForEach(suggestions, id: \.self) { s in
                            Button(s) { query = s; Task { await runSearch() } }
                        }
                    }
                }
                Section {
                    ForEach(hits) { hit in
                        HitRow(
                            hit: hit,
                            onStar: { Task { await toggleStar(hit) } },
                            onDownload: hit.download_url.isEmpty ? nil : { downloadTarget = URL(string: hit.download_url).map(DownloadTarget.init) },
                            onInject: hit.download_url.isEmpty ? nil : { injectTarget = hit }
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "App name or bundle ID")
            .onSubmit(of: .search) { Task { await runSearch() } }
            .overlay {
                if isLoading { ProgressView() }
                else if hits.isEmpty && query.isEmpty && errorMessage == nil {
                    VStack(spacing: 8) {
                        Image(systemName: "clock").font(.largeTitle).foregroundStyle(.secondary)
                        Text("Recent finds will appear here").foregroundStyle(.secondary)
                    }
                }
            }
            .task { await loadRecent() }
            .refreshable { if query.isEmpty { await loadRecent() } else { await runSearch() } }
            .sheet(item: $downloadTarget) { target in
                SafariView(url: target.url)
            }
            .sheet(item: $injectTarget) { hit in
                InjectView(hit: hit)
            }
        }
    }

    private func loadRecent() async {
        isLoading = true; errorMessage = nil
        do {
            let resp = try await api.recent()
            hits = resp.hits
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func runSearch() async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoading = true; errorMessage = nil; suggestions = []
        do {
            let resp = try await api.search(query)
            hits = resp.hits
            suggestions = resp.suggestions ?? []
            if let err = resp.error { errorMessage = err }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func toggleStar(_ hit: Hit) async {
        guard !hit.bundle_id.isEmpty, let idx = hits.firstIndex(where: { $0.id == hit.id }) else { return }
        let newState = !(hit.starred ?? false)
        hits[idx].starred = newState
        do {
            try await api.setStar(bundleId: hit.bundle_id, on: newState)
        } catch {
            hits[idx].starred = !newState
            errorMessage = error.localizedDescription
        }
    }
}

struct DownloadTarget: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
