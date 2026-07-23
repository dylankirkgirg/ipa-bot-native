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
    @State private var showDecrypt = false
    @State private var showDiff = false
    @State private var showTrending = false
    @State private var shareTarget: ShareTarget?
    @State private var isDownloadingVault = false
    @State private var signingBundleId: String?
    @State private var signAlert: SignAlert?
    @State private var history: [String] = []

    struct SignAlert: Identifiable {
        let id = UUID()
        let message: String
    }

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
                        Group {
                            if hit.bundle_id.isEmpty {
                                row(for: hit)
                            } else {
                                NavigationLink {
                                    AboutView(bundleId: hit.bundle_id, fallbackName: hit.app_name)
                                } label: {
                                    row(for: hit)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Search")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Decrypt", systemImage: "lock.open") { showDecrypt = true }
                        Button("Diff", systemImage: "arrow.left.arrow.right") { showDiff = true }
                        Button("Trending", systemImage: "flame") { showTrending = true }
                        Button("Random", systemImage: "dice") { Task { await runRandom() } }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .searchable(text: $query, prompt: "App name or bundle ID")
            .searchSuggestions {
                ForEach(history, id: \.self) { term in
                    Label(term, systemImage: "clock").searchCompletion(term)
                }
            }
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
            .task { await loadRecent(); await loadHistory() }
            .refreshable { if query.isEmpty { await loadRecent() } else { await runSearch() } }
            .sheet(item: $downloadTarget) { target in
                SafariView(url: target.url)
            }
            .sheet(item: $injectTarget) { hit in
                InjectView(hit: hit)
            }
            .sheet(isPresented: $showDecrypt) {
                DecryptView()
            }
            .sheet(isPresented: $showDiff) {
                DiffView()
            }
            .sheet(isPresented: $showTrending) {
                TrendingView { term in
                    query = term
                    Task { await runSearch() }
                }
            }
            .sheet(item: $shareTarget) { target in
                ShareSheet(items: [target.url])
            }
            .alert(item: $signAlert) { alert in
                Alert(title: Text("Sign"), message: Text(alert.message), dismissButton: .default(Text("OK")))
            }
        }
    }

    @ViewBuilder
    private func row(for hit: Hit) -> some View {
        HitRow(
            hit: hit,
            onStar: { Task { await toggleStar(hit) } },
            onDownload: downloadAction(for: hit),
            onSign: hit.download_url.isEmpty ? nil : { Task { await signDirect(hit) } },
            onInject: hit.download_url.isEmpty ? nil : { injectTarget = hit }
        )
    }

    private func signDirect(_ hit: Hit) async {
        guard signingBundleId == nil else { return }
        signingBundleId = hit.bundle_id
        do {
            let result = try await api.sign(ipaUrl: hit.download_url, ipaName: hit.app_name, options: SignOptions())
            signAlert = SignAlert(message: result.ok ? (result.note ?? "Signing queued — check the Signed tab shortly.") : (result.error ?? "Sign request failed."))
        } catch {
            signAlert = SignAlert(message: error.localizedDescription)
        }
        signingBundleId = nil
    }

    private func downloadAction(for hit: Hit) -> (() -> Void)? {
        if !hit.download_url.isEmpty {
            return { downloadTarget = URL(string: hit.download_url).map(DownloadTarget.init) }
        }
        if let vaultId = hit.vault_msg_id {
            return { Task { await downloadVault(vaultId: vaultId, name: hit.file_name ?? hit.app_name) } }
        }
        return nil
    }

    private func downloadVault(vaultId: Int, name: String) async {
        guard !isDownloadingVault else { return }
        isDownloadingVault = true; errorMessage = nil
        do {
            let fileURL = try await api.downloadFile(vaultMsgId: vaultId, name: name)
            shareTarget = ShareTarget(url: fileURL)
        } catch {
            errorMessage = error.localizedDescription
        }
        isDownloadingVault = false
    }

    private func loadHistory() async {
        history = (try? await api.searchHistory().history) ?? []
    }

    private func runRandom() async {
        isLoading = true; errorMessage = nil; suggestions = []
        do {
            let resp = try await api.random()
            hits = resp.hits
            query = ""
            if let err = resp.error { errorMessage = err }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
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
        await loadHistory()
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

struct ShareTarget: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
