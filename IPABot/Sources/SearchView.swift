import SwiftUI
import UIKit

struct SearchView: View {
    @EnvironmentObject var api: APIClient
    @State private var query = ""
    @State private var hits: [Hit] = []
    @State private var suggestions: [String] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var cacheBanner: String?
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
    @State private var sortOption: SortOption = .relevance
    @State private var moddedOnly = false
    @State private var showCompare = false
    @State private var compareQuery = ""
    @State private var watches: [WatchEntry] = []

    enum SortOption: String, CaseIterable, Identifiable {
        case relevance, sizeDesc, dateDesc, name
        var id: String { rawValue }
        var title: String {
            switch self {
            case .relevance: return "Relevance"
            case .sizeDesc: return "Largest first"
            case .dateDesc: return "Newest first"
            case .name: return "Name (A-Z)"
            }
        }
    }

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
                            Button { Task { await clearHistory() } } label: {
                                Image(systemName: "trash").font(Ledger.body(12))
                            }
                            .foregroundColor(Ledger.textTertiary)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                            .accessibilityLabel("Clear search history")
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 6, trailing: 20))
                    .listRowSeparator(.hidden).listRowBackground(Color.clear)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(Ledger.accent)
                        .listRowSeparator(.hidden).listRowBackground(Color.clear)
                }
                if let cacheBanner {
                    Text(cacheBanner).font(Ledger.body(12)).foregroundColor(Ledger.textTertiary)
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
                ForEach(displayedHits) { hit in
                    Group {
                        if selectMode {
                            Button { toggleSelect(hit) } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: selected.contains(hit.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selected.contains(hit.id) ? Ledger.accent : Ledger.textTertiary)
                                        .font(Ledger.body(20))
                                        .accessibilityHidden(true)
                                    row(for: hit, interactive: false)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selected.contains(hit.id) ? .isSelected : [])
                            .accessibilityValue(selected.contains(hit.id) ? "Selected" : "Not selected")
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
            .scrollIndicators(.hidden)
            .navigationBarHidden(true)
            .scrollDismissesKeyboard(.interactively)
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
            .task {
                await PendingStarQueue.flush(api: api)
                await loadWatches()
                await loadRecent()
                await loadHistory()
            }
            .refreshable { if query.isEmpty { await loadRecent() } else { await runSearch() } }
            .sheet(item: $downloadTarget) { target in SafariView(url: target.url) }
            .sheet(item: $injectTarget) { hit in InjectView(hit: hit) }
            .sheet(isPresented: $showDecrypt) { DecryptView() }
            .sheet(isPresented: $showDiff) { DiffView() }
            .sheet(isPresented: $showCompare) { DiffView(prefillQuery: compareQuery) }
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
        HStack(alignment: .center, spacing: 8) {
            Text("Search").font(Ledger.heading(28))
            Spacer(minLength: 8)
            HStack(spacing: 4) {
                Button { Task { if query.isEmpty { await loadRecent() } else { await runSearch() } } } label: {
                    Glyph(.refresh, size: 17, color: Ledger.textSecondary)
                }
                .frame(width: 44, height: 44).contentShape(Rectangle())
                .accessibilityLabel("Refresh")

                Button(selectMode ? "Done" : "Select") {
                    selectMode.toggle()
                    if !selectMode { selected.removeAll() }
                }
                .font(Ledger.body(13)).foregroundColor(Ledger.textSecondary)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .fixedSize()

                Menu {
                    Picker("Sort", selection: $sortOption) {
                        ForEach(SortOption.allCases) { opt in Text(opt.title).tag(opt) }
                    }
                    Toggle("Modded only", isOn: $moddedOnly)
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                        .font(Ledger.body(18))
                        .foregroundColor((sortOption != .relevance || moddedOnly) ? Ledger.accent : Ledger.textSecondary)
                }
                .frame(width: 44, height: 44).contentShape(Rectangle())
                .accessibilityLabel("Sort and filter")
                .accessibilityValue(sortOption == .relevance && !moddedOnly ? "Default" : "Active")

                // "..." reads unambiguously as "more actions" — a bare "+" was
                // easy to miss as the way to reach Decrypt/Diff/etc.
                Menu {
                    Button("Sign a file") { showSign = true }
                    Button("Decrypt") { showDecrypt = true }
                    Button("Diff") { showDiff = true }
                    Button("Trending") { showTrending = true }
                    Button("Channels") { showChannels = true }
                    Button("Random") { Task { await runRandom() } }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(Ledger.body(18))
                        .foregroundColor(Ledger.textSecondary)
                }
                .frame(width: 44, height: 44).contentShape(Rectangle())
                .accessibilityLabel("More actions")
            }
        }
        .padding(.top, 8).padding(.bottom, 6)
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 12))
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
                .onSubmit { hideKeyboard(); Task { await runSearch() } }
            if !query.isEmpty {
                Button { query = ""; Task { await loadRecent() } } label: {
                    Glyph(.xmark, size: 14, color: Ledger.textSecondary)
                }
                .frame(width: 44, height: 44).contentShape(Rectangle())
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .overlay(Rectangle().stroke(Ledger.divider, lineWidth: 1))
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var displayedHits: [Hit] {
        var out = moddedOnly ? hits.filter { $0.is_modded == true } : hits
        switch sortOption {
        case .relevance: break
        case .sizeDesc: out.sort { $0.size_mb > $1.size_mb }
        case .dateDesc: out.sort { $0.date_iso > $1.date_iso }
        case .name: out.sort { $0.app_name.localizedCaseInsensitiveCompare($1.app_name) == .orderedAscending }
        }
        return out
    }

    @ViewBuilder
    private func row(for hit: Hit, interactive: Bool = true) -> some View {
        HitRow(
            hit: hit,
            onStar: interactive ? { Task { await toggleStar(hit) } } : nil,
            onDownload: interactive ? downloadAction(for: hit) : nil,
            onSign: interactive ? { Task { await signDirect(hit) } } : nil,
            onInject: interactive ? { injectTarget = hit } : nil,
            canDeliver: canDeliver(hit)
        )
        .contextMenu {
            if interactive && canDeliver(hit) {
                Button { Task { await queueInspect(hit) } } label: { Label("Inspect", systemImage: "wrench.and.screwdriver") }
                Button { Task { await queueEntitlements(hit) } } label: { Label("Entitlements", systemImage: "lock.shield") }
            }
            if interactive && !hit.bundle_id.isEmpty {
                Button { UIPasteboard.general.string = hit.bundle_id } label: { Label("Copy bundle ID", systemImage: "doc.on.doc") }
            }
            if interactive && !hit.download_url.isEmpty {
                Button { UIPasteboard.general.string = hit.download_url } label: { Label("Copy download URL", systemImage: "link") }
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
            Button("Compare") {
                if let name = hits.first(where: { selected.contains($0.id) })?.app_name {
                    compareQuery = name
                    showCompare = true
                }
            }
            .buttonStyle(LedgerOutlineButtonStyle())
            .frame(width: 100)
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
            if !result.ok { SourceHealth.recordFailure(source: hit.source) }
            signAlert = SignAlert(message: result.ok ? (result.note ?? "Signing queued — check Library › Signed shortly.") : (result.error ?? "Sign request failed."))
        } catch {
            SourceHealth.recordFailure(source: hit.source)
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
            return { Task { await downloadVault(vaultId: vaultId, name: hit.file_name ?? hit.app_name, source: hit.source) } }
        }
        return nil
    }

    private func downloadVault(vaultId: Int, name: String, source: String) async {
        guard !isDownloadingVault else { return }
        isDownloadingVault = true; errorMessage = nil
        do {
            let fileURL = try await api.downloadFile(vaultMsgId: vaultId, name: name)
            shareTarget = ShareTarget(url: fileURL)
        } catch {
            SourceHealth.recordFailure(source: source)
            errorMessage = error.localizedDescription
        }
        isDownloadingVault = false
    }

    private func loadHistory() async {
        history = (try? await api.searchHistory().history) ?? []
    }

    private func loadWatches() async {
        watches = (try? await api.library().watches) ?? []
    }

    // The server already emails/DMs watch hits — this is just an in-app echo
    // for whoever isn't watching Telegram, deduped so the same hit doesn't
    // re-fire every time /recent or a search happens to include it again.
    private func notifyWatchMatches(in freshHits: [Hit]) {
        guard !watches.isEmpty else { return }
        let seenKey = "ipabot.watchNotified"
        var seen = Set(UserDefaults.standard.stringArray(forKey: seenKey) ?? [])
        for hit in freshHits {
            guard !seen.contains(hit.id) else { continue }
            guard watches.contains(where: { hit.app_name.localizedCaseInsensitiveContains($0.term) }) else { continue }
            seen.insert(hit.id)
            LocalNotifier.fireNow(id: "watch-\(hit.id)", title: "Watch match: \(hit.app_name)", body: "v\(hit.version) via \(hit.source)")
        }
        UserDefaults.standard.set(Array(seen.suffix(200)), forKey: seenKey)
    }

    private func clearHistory() async {
        try? await api.clearHistory()
        history = []
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
        isLoading = true; errorMessage = nil; cacheBanner = nil
        do {
            let resp = try await api.recent()
            hits = resp.hits
            SearchCache.save(query: "", hits: hits)
            notifyWatchMatches(in: hits)
        } catch {
            if let cached = SearchCache.load(query: "") {
                hits = cached.hits
                cacheBanner = "Offline — showing cached results from \(formatAge(cached.age))"
            } else {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func runSearch() async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoading = true; errorMessage = nil; suggestions = []; cacheBanner = nil
        do {
            let resp = try await api.search(query)
            hits = resp.hits
            suggestions = resp.suggestions ?? []
            if let err = resp.error { errorMessage = err }
            SearchCache.save(query: query, hits: hits)
            notifyWatchMatches(in: hits)
        } catch {
            if let cached = SearchCache.load(query: query) {
                hits = cached.hits
                cacheBanner = "Offline — showing cached results from \(formatAge(cached.age))"
            } else {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
        await loadHistory()
    }

    private func formatAge(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds / 60)
        if mins < 1 { return "just now" }
        if mins < 60 { return "\(mins)m ago" }
        return "\(mins / 60)h ago"
    }

    private func toggleStar(_ hit: Hit) async {
        guard !hit.bundle_id.isEmpty, let idx = hits.firstIndex(where: { $0.id == hit.id }) else { return }
        let newState = !(hit.starred ?? false)
        hits[idx].starred = newState
        do {
            try await api.setStar(bundleId: hit.bundle_id, on: newState)
        } catch {
            // Keep the optimistic flip and queue it — offline shouldn't feel
            // like the tap didn't register, it'll flush next time we're back.
            PendingStarQueue.enqueue(bundleId: hit.bundle_id, on: newState)
            cacheBanner = "Offline — star queued, will sync when back online."
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
