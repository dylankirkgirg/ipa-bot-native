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
    @State private var showChannels = false
    @State private var showSign = false
    @State private var shareTarget: ShareTarget?
    @State private var isDownloadingVault = false
    @State private var signingBundleId: String?
    @State private var signAlert: SignAlert?
    @State private var history: [String] = []
    @State private var textJob: TextJobTarget?
    @State private var selectMode = false
    @State private var selected: Set<String> = []
    @State private var isBulkSigning = false
    @State private var bulkAlert: SignAlert?

    struct TextJobTarget: Identifiable {
        let id: String
        let title: String
    }

    struct SignAlert: Identifiable {
        let id = UUID()
        let message: String
    }

    var body: some View {
        NavigationStack {
            List {
                header
                searchField
                if query.isEmpty && !history.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(history, id: \.self) { term in
                                Button(term) { query = term; Task { await runSearch() } }
                                    .font(Ledger.mono(12))
                                    .foregroundColor(Ledger.textSecondary)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .overlay(Rectangle().stroke(Ledger.divider, lineWidth: 1))
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 6, trailing: 20))
                    .listRowSeparator(.hidden).listRowBackground(Color.clear)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(Ledger.accent)
                        .listRowSeparator(.hidden).listRowBackground(Color.clear)
                }
                if !suggestions.isEmpty {
                    LedgerSectionLabel(text: "Did you mean?")
                        .listRowSeparator(.hidden).listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                    ForEach(suggestions, id: \.self) { s in
                        Button(s) { query = s; Task { await runSearch() } }
                            .font(Ledger.body(14))
                            .listRowSeparator(.hidden).listRowBackground(Color.clear)
                    }
                }
                ForEach(hits) { hit in
                    Group {
                        if selectMode {
                            Button { toggleSelect(hit) } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: selected.contains(hit.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selected.contains(hit.id) ? Ledger.accent : Ledger.textTertiary)
                                        .font(.system(size: 20))
                                    row(for: hit, interactive: false)
                                }
                            }
                            .buttonStyle(.plain)
                        } else if hit.bundle_id.isEmpty {
                            row(for: hit)
                        } else {
                            NavigationLink {
                                AboutView(bundleId: hit.bundle_id, fallbackName: hit.app_name)
                            } label: {
                                row(for: hit)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .ledgerBackground()
            .navigationBarHidden(true)
            .overlay {
                if isLoading { ProgressView() }
                else if hits.isEmpty && query.isEmpty && errorMessage == nil {
                    Text("Recent finds will appear here")
                        .font(Ledger.body(14)).foregroundColor(Ledger.textTertiary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if selectMode && !selected.isEmpty {
                    bulkBar
                }
            }
            .task { await loadRecent(); await loadHistory() }
            .refreshable { if query.isEmpty { await loadRecent() } else { await runSearch() } }
            .sheet(item: $downloadTarget) { target in SafariView(url: target.url) }
            .sheet(item: $injectTarget) { hit in InjectView(hit: hit) }
            .sheet(isPresented: $showDecrypt) { DecryptView() }
            .sheet(isPresented: $showDiff) { DiffView() }
            .sheet(isPresented: $showTrending) {
                TrendingView { term in query = term; Task { await runSearch() } }
            }
            .sheet(isPresented: $showChannels) { ChannelBrowseView() }
            .sheet(isPresented: $showSign) { SignInstallView() }
            .sheet(item: $shareTarget) { target in ShareSheet(items: [target.url]) }
            .sheet(item: $textJob) { target in TextJobResultView(title: target.title, jobId: target.id) }
            .alert(item: $signAlert) { alert in
                Alert(title: Text("Sign"), message: Text(alert.message), dismissButton: .default(Text("OK")))
            }
            .alert(item: $bulkAlert) { alert in
                Alert(title: Text("Bulk Sign"), message: Text(alert.message), dismissButton: .default(Text("OK")))
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Search").font(Ledger.heading(28))
            Spacer()
            Button { Task { if query.isEmpty { await loadRecent() } else { await runSearch() } } } label: {
                Glyph(.refresh, size: 18, color: Ledger.textSecondary)
            }
            Button(selectMode ? "Done" : "Select") {
                selectMode.toggle()
                if !selectMode { selected.removeAll() }
            }
            .font(Ledger.body(13)).foregroundColor(Ledger.textSecondary)
            Menu {
                Button("Sign a file") { showSign = true }
                Button("Decrypt") { showDecrypt = true }
                Button("Diff") { showDiff = true }
                Button("Trending") { showTrending = true }
                Button("Channels") { showChannels = true }
                Button("Random") { Task { await runRandom() } }
            } label: {
                Glyph(.plus, size: 18, color: Ledger.textSecondary)
            }
        }
        .padding(.top, 8).padding(.bottom, 6)
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Glyph(.search, size: 16, color: Ledger.textSecondary)
            TextField("App name or bundle ID", text: $query)
                .font(Ledger.body(15))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { Task { await runSearch() } }
            if !query.isEmpty {
                Button { query = ""; Task { await loadRecent() } } label: {
                    Glyph(.xmark, size: 14, color: Ledger.textSecondary)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .overlay(Rectangle().stroke(Ledger.divider, lineWidth: 1))
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private func row(for hit: Hit, interactive: Bool = true) -> some View {
        HitRow(
            hit: hit,
            onStar: interactive ? { Task { await toggleStar(hit) } } : nil,
            onDownload: interactive ? downloadAction(for: hit) : nil,
            onSign: interactive && canDeliver(hit) ? { Task { await signDirect(hit) } } : nil,
            onInject: interactive && canDeliver(hit) ? { injectTarget = hit } : nil
        )
        .contextMenu {
            if interactive && canDeliver(hit) {
                Button { Task { await queueInspect(hit) } } label: { Label("Inspect", systemImage: "wrench.and.screwdriver") }
                Button { Task { await queueEntitlements(hit) } } label: { Label("Entitlements", systemImage: "lock.shield") }
            }
        }
    }

    private func toggleSelect(_ hit: Hit) {
        if selected.contains(hit.id) { selected.remove(hit.id) } else { selected.insert(hit.id) }
    }

    private var bulkBar: some View {
        HStack {
            Text("\(selected.count) selected").font(Ledger.body(13)).foregroundColor(Ledger.textSecondary)
            Spacer()
            Button(isBulkSigning ? "Signing…" : "Sign All") { Task { await bulkSign() } }
                .buttonStyle(LedgerPrimaryButtonStyle())
                .disabled(isBulkSigning || !selected.contains(where: { id in hits.first(where: { $0.id == id }).map(canDeliver) ?? false }))
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(Ledger.surface)
        .overlay(alignment: .top) { Rectangle().fill(Ledger.divider).frame(height: 1) }
    }

    private func bulkSign() async {
        let targets = hits.filter { selected.contains($0.id) && canDeliver($0) }
        guard !targets.isEmpty else { return }
        isBulkSigning = true
        var okCount = 0
        var failures: [String] = []
        for hit in targets {
            do {
                let result = try await api.sign(ipaUrl: hit.download_url, ipaName: hit.app_name, options: SignOptions(), vaultMsgId: hit.vault_msg_id)
                if result.ok { okCount += 1 } else { failures.append("\(hit.app_name): \(result.error ?? "failed")") }
            } catch {
                failures.append("\(hit.app_name): \(error.localizedDescription)")
            }
        }
        isBulkSigning = false
        selected.removeAll()
        selectMode = false
        let summary = "Queued \(okCount) of \(targets.count)." + (failures.isEmpty ? "" : "\n\n" + failures.joined(separator: "\n"))
        bulkAlert = SignAlert(message: summary)
    }

    private func canDeliver(_ hit: Hit) -> Bool {
        !hit.download_url.isEmpty || hit.vault_msg_id != nil
    }

    private func signDirect(_ hit: Hit) async {
        guard signingBundleId == nil else { return }
        signingBundleId = hit.bundle_id
        do {
            let result = try await api.sign(ipaUrl: hit.download_url, ipaName: hit.app_name, options: SignOptions(), vaultMsgId: hit.vault_msg_id)
            signAlert = SignAlert(message: result.ok ? (result.note ?? "Signing queued — check Library › Signed shortly.") : (result.error ?? "Sign request failed."))
        } catch {
            signAlert = SignAlert(message: error.localizedDescription)
        }
        signingBundleId = nil
    }

    private func queueInspect(_ hit: Hit) async {
        do {
            let r = try await api.inspect(ipaUrl: hit.download_url, ipaName: hit.app_name, vaultMsgId: hit.vault_msg_id)
            if let id = r.id { textJob = TextJobTarget(id: id, title: "Inspect — \(hit.app_name)") }
            else { errorMessage = r.error ?? "Couldn't queue inspect." }
        } catch { errorMessage = error.localizedDescription }
    }

    private func queueEntitlements(_ hit: Hit) async {
        do {
            let r = try await api.entitlements(ipaUrl: hit.download_url, ipaName: hit.app_name, vaultMsgId: hit.vault_msg_id)
            if let id = r.id { textJob = TextJobTarget(id: id, title: "Entitlements — \(hit.app_name)") }
            else { errorMessage = r.error ?? "Couldn't queue entitlements." }
        } catch { errorMessage = error.localizedDescription }
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
