import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var api: APIClient

    @State private var stars: [StarEntry] = []
    @State private var watches: [WatchEntry] = []
    @State private var presets: [PresetEntry] = []
    @State private var sources: [SourceEntry] = []
    @State private var notes: [NoteEntry] = []
    @State private var pins: [PinEntry] = []
    @State private var aliases: [AliasEntry] = []
    @State private var tfWatches: [TfWatchEntry] = []
    @State private var signed: [SignedApp] = []

    @State private var section: LibrarySection = .starred
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var newWatchTerm = ""
    @State private var activeSheet: AddSheetKind?
    @State private var isRebuilding = false
    @State private var isResigning = false
    @State private var bulkAlert: BulkAlert?
    @State private var installTarget: DownloadTarget?
    @State private var showSignInstall = false
    @State private var showUpdateCheck = false

    struct BulkAlert: Identifiable { let id = UUID(); let message: String }

    enum AddSheetKind: Identifiable {
        case note, pin, alias, tfwatch, source, preset
        var id: Int { hashValue }
    }

    enum LibrarySection: String, CaseIterable, Identifiable {
        case starred, signed, watches, sources, notes, pins, aliases, tfwatches
        var id: String { rawValue }
        var title: String {
            switch self {
            case .starred: return "Starred"
            case .signed: return "Signed"
            case .watches: return "Watches"
            case .sources: return "Sources"
            case .notes: return "Notes"
            case .pins: return "Pins"
            case .aliases: return "Aliases"
            case .tfwatches: return "TF Watches"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                chips
                Rectangle().fill(Ledger.dividerSoft).frame(height: 1)
                if let errorMessage {
                    Text(errorMessage).font(Ledger.body(13)).foregroundStyle(Ledger.accent)
                        .padding(.horizontal, 20).padding(.top, 8)
                }
                content
            }
            .ledgerBackground()
            .scrollIndicators(.hidden)
            .navigationBarHidden(true)
            .task { await load() }
            .overlay { if isLoading { ProgressView() } }
            .sheet(item: $activeSheet) { kind in
                switch kind {
                case .note: AddNoteSheet(onSaved: { Task { await load() } })
                case .pin: AddPinSheet(onSaved: { Task { await load() } })
                case .alias: AddAliasSheet(onSaved: { Task { await load() } })
                case .tfwatch: AddTfWatchSheet(onSaved: { Task { await load() } })
                case .source: AddSourceSheet(onSaved: { Task { await load() } })
                case .preset: AddPresetSheet(onSaved: { Task { await load() } })
                }
            }
            .sheet(isPresented: $showSignInstall) { SignInstallView() }
            .sheet(isPresented: $showUpdateCheck) { UpdateCheckView(stars: stars) }
            .sheet(item: $installTarget) { target in SafariView(url: target.url) }
            .alert(item: $bulkAlert) { alert in
                Alert(title: Text("Library"), message: Text(alert.message), dismissButton: .default(Text("OK")))
            }
        }
    }

    // MARK: Chrome

    private var header: some View {
        HStack {
            Button { Task { await rebuildAll() } } label: {
                if isRebuilding { ProgressView() } else { Glyph(.refresh, size: 20, color: Ledger.textSecondary) }
            }
            .disabled(isRebuilding)
            .frame(width: 44, height: 44).contentShape(Rectangle())
            .accessibilityLabel("Rebuild library")
            Spacer()
            Text("Library").font(Ledger.heading(26))
            Spacer()
            Menu {
                Button("Preset") { activeSheet = .preset }
                Button("Note") { activeSheet = .note }
                Button("Pin") { activeSheet = .pin }
                Button("Alias") { activeSheet = .alias }
                Button("TestFlight Watch") { activeSheet = .tfwatch }
                Button("Source") { activeSheet = .source }
            } label: {
                Glyph(.plus, size: 20, color: Ledger.textSecondary)
            }
            .frame(width: 44, height: 44).contentShape(Rectangle())
            .accessibilityLabel("Add to library")
        }
        .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 8)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibrarySection.allCases) { s in
                    Button { section = s } label: {
                        Text("\(s.title) · \(count(for: s))")
                            .font(Ledger.heading(11, weight: .bold))
                            .textCase(.uppercase)
                            .tracking(0.4)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .foregroundColor(section == s ? .white : Ledger.textSecondary)
                            .background(section == s ? Ledger.accent : Color.clear)
                            .overlay(Rectangle().stroke(section == s ? Color.clear : Ledger.divider, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 4)
        }
    }

    private func count(for s: LibrarySection) -> Int {
        switch s {
        case .starred: return stars.count
        case .signed: return signed.count
        case .watches: return watches.count
        case .sources: return sources.count
        case .notes: return notes.count
        case .pins: return pins.count
        case .aliases: return aliases.count
        case .tfwatches: return tfWatches.count
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        List {
            switch section {
            case .starred: starredRows
            case .signed: signedRows
            case .watches: watchRows
            case .sources: sourceRows
            case .notes: noteRows
            case .pins: pinRows
            case .aliases: aliasRows
            case .tfwatches: tfWatchRows
            }
        }
        .listStyle(.plain)
        .ledgerBackground()
        .scrollIndicators(.hidden)
        .refreshable { await load() }
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text).font(Ledger.body(13)).foregroundColor(Ledger.textTertiary)
            .listRowSeparator(.hidden).listRowBackground(Color.clear)
    }

    @ViewBuilder private var starredRows: some View {
        if !stars.isEmpty {
            Button("Check for updates") { showUpdateCheck = true }
                .buttonStyle(LedgerOutlineButtonStyle())
                .padding(.vertical, 6)
                .listRowSeparator(.hidden).listRowBackground(Color.clear)
        }
        if stars.isEmpty { emptyRow("No starred apps yet.") }
        ForEach(stars) { star in
            HStack(spacing: 12) {
                Glyph(.star, size: 16, color: Ledger.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(star.app_name).font(Ledger.heading(14, weight: .semibold)).foregroundColor(Ledger.text)
                    Text(star.bundle_id).font(Ledger.mono(11)).foregroundColor(Ledger.textTertiary)
                }
                Spacer()
            }
            .padding(.vertical, 8)
            .listRowSeparator(.hidden).listRowBackground(Color.clear)
            .overlay(alignment: .bottom) { Rectangle().fill(Ledger.dividerSoft).frame(height: 1) }
        }
        .onDelete { indexSet in Task { await unstar(at: indexSet) } }
    }

    @ViewBuilder private var signedRows: some View {
        HStack {
            Button("Sign a new IPA") { showSignInstall = true }
                .buttonStyle(LedgerOutlineButtonStyle())
            Button(action: { Task { await resignAll() } }) {
                if isResigning { ProgressView() } else { Glyph(.refresh, size: 15) }
            }
            .buttonStyle(LedgerIconButtonStyle())
            .disabled(isResigning || signed.isEmpty)
            .accessibilityLabel("Re-sign all")
        }
        .padding(.vertical, 6)
        .listRowSeparator(.hidden).listRowBackground(Color.clear)

        if signed.isEmpty { emptyRow("No recently signed apps. Signed apps show up here for ~24h.") }
        ForEach(signed) { app in
            Button {
                installTarget = URL(string: api.baseURL + "/sign-install/" + app.id).map(DownloadTarget.init)
            } label: {
                HStack(spacing: 12) {
                    Glyph(.seal, size: 16, color: Ledger.textSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.title).font(Ledger.heading(14, weight: .semibold)).foregroundColor(Ledger.text)
                        Text("v\(app.version) · \(app.bundle)").font(Ledger.mono(11)).foregroundColor(Ledger.textTertiary)
                    }
                    Spacer()
                    expiryBadge(for: app)
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 8)
            .listRowSeparator(.hidden).listRowBackground(Color.clear)
            .overlay(alignment: .bottom) { Rectangle().fill(Ledger.dividerSoft).frame(height: 1) }
        }
    }

    // Free-account signing certs expire after 7 days — this is a client-side
    // estimate off the sign timestamp, not a value the server sends back.
    private func expiryBadge(for app: SignedApp) -> some View {
        let expiry = Date(timeIntervalSince1970: app.ts).addingTimeInterval(7 * 86400)
        let daysLeft = Int(expiry.timeIntervalSinceNow / 86400)
        let label = daysLeft <= 0 ? "Expired" : "\(daysLeft)d left"
        return Text(label)
            .font(Ledger.mono(10))
            .foregroundColor(daysLeft <= 1 ? Ledger.accent : Ledger.textTertiary)
    }

    private func scheduleExpiryReminders() {
        for app in signed {
            let expiry = Date(timeIntervalSince1970: app.ts).addingTimeInterval(7 * 86400)
            let fireAt = expiry.addingTimeInterval(-24 * 3600)
            guard fireAt.timeIntervalSinceNow > 0 else { continue }
            LocalNotifier.scheduleOnce(
                id: "expiry-\(app.id)",
                title: "Signing cert expiring soon",
                body: "\(app.title) will stop opening in ~24h — re-sign it from Library.",
                in: fireAt.timeIntervalSinceNow
            )
        }
    }

    @ViewBuilder private var watchRows: some View {
        HStack {
            TextField("Add a watch term", text: $newWatchTerm)
                .textInputAutocapitalization(.never)
                .font(Ledger.body(14))
            Button("Add") { Task { await addWatch() } }
                .buttonStyle(LedgerOutlineButtonStyle())
                .frame(width: 90)
                .disabled(newWatchTerm.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.vertical, 6)
        .listRowSeparator(.hidden).listRowBackground(Color.clear)

        if watches.isEmpty { emptyRow("No watches yet.") }
        ForEach(watches) { w in
            HStack {
                Glyph(.eye, size: 15, color: Ledger.textSecondary)
                Text(w.term).font(Ledger.body(14)).foregroundColor(Ledger.text)
                if let mv = w.minVersion {
                    Text("≥\(mv)").font(Ledger.mono(11)).foregroundColor(Ledger.textTertiary)
                }
                Spacer()
            }
            .padding(.vertical, 8)
            .listRowSeparator(.hidden).listRowBackground(Color.clear)
            .overlay(alignment: .bottom) { Rectangle().fill(Ledger.dividerSoft).frame(height: 1) }
        }
        .onDelete { indexSet in Task { await removeWatch(at: indexSet) } }
    }

    @ViewBuilder private var sourceRows: some View {
        if sources.isEmpty { emptyRow("No custom sources yet.") }
        ForEach(sources) { s in
            HStack {
                Glyph(.tray, size: 15, color: Ledger.textSecondary)
                Text(s.name).font(Ledger.body(14)).foregroundColor(Ledger.text)
                if s.blacklisted == true {
                    Text("blacklisted").font(Ledger.mono(10)).foregroundColor(Ledger.accent)
                }
                Spacer()
            }
            .padding(.vertical, 8)
            .listRowSeparator(.hidden).listRowBackground(Color.clear)
            .overlay(alignment: .bottom) { Rectangle().fill(Ledger.dividerSoft).frame(height: 1) }
        }
        .onDelete { indexSet in Task { await removeSources(at: indexSet) } }
    }

    @ViewBuilder private var noteRows: some View {
        if notes.isEmpty { emptyRow("No notes yet.") }
        ForEach(notes) { n in
            VStack(alignment: .leading, spacing: 2) {
                Text(n.bundle).font(Ledger.mono(11)).foregroundColor(Ledger.textTertiary)
                Text(n.text).font(Ledger.body(14)).foregroundColor(Ledger.text)
            }
            .padding(.vertical, 8)
            .listRowSeparator(.hidden).listRowBackground(Color.clear)
            .overlay(alignment: .bottom) { Rectangle().fill(Ledger.dividerSoft).frame(height: 1) }
        }
        .onDelete { indexSet in Task { await removeNotes(at: indexSet) } }
    }

    @ViewBuilder private var pinRows: some View {
        if pins.isEmpty { emptyRow("No pins yet.") }
        ForEach(pins) { p in
            HStack {
                Glyph(.pin, size: 15, color: Ledger.textSecondary)
                Text(p.bundle).font(Ledger.body(14)).foregroundColor(Ledger.text)
                Spacer()
                Text(p.version).font(Ledger.mono(12)).foregroundColor(Ledger.textSecondary)
            }
            .padding(.vertical, 8)
            .listRowSeparator(.hidden).listRowBackground(Color.clear)
            .overlay(alignment: .bottom) { Rectangle().fill(Ledger.dividerSoft).frame(height: 1) }
        }
        .onDelete { indexSet in Task { await removePins(at: indexSet) } }
    }

    @ViewBuilder private var aliasRows: some View {
        if aliases.isEmpty { emptyRow("No aliases yet.") }
        ForEach(aliases) { a in
            HStack {
                Text(a.short).font(Ledger.heading(14, weight: .semibold)).foregroundColor(Ledger.text)
                Text("→ \(a.full)").font(Ledger.body(13)).foregroundColor(Ledger.textSecondary)
                Spacer()
            }
            .padding(.vertical, 8)
            .listRowSeparator(.hidden).listRowBackground(Color.clear)
            .overlay(alignment: .bottom) { Rectangle().fill(Ledger.dividerSoft).frame(height: 1) }
        }
        .onDelete { indexSet in Task { await removeAliases(at: indexSet) } }
    }

    @ViewBuilder private var tfWatchRows: some View {
        if tfWatches.isEmpty { emptyRow("No TestFlight watches yet.") }
        ForEach(tfWatches) { t in
            HStack {
                Text(t.name.isEmpty ? t.url : t.name).font(Ledger.body(14)).foregroundColor(Ledger.text)
                Spacer()
                Text(t.status).font(Ledger.mono(11)).foregroundColor(Ledger.textSecondary)
            }
            .padding(.vertical, 8)
            .listRowSeparator(.hidden).listRowBackground(Color.clear)
            .overlay(alignment: .bottom) { Rectangle().fill(Ledger.dividerSoft).frame(height: 1) }
        }
        .onDelete { indexSet in Task { await removeTfWatches(at: indexSet) } }
    }

    // MARK: Data

    private func rebuildAll() async {
        isRebuilding = true
        do {
            let result = try await api.rebuildAll()
            bulkAlert = BulkAlert(message: result.ok
                ? "Queued \(result.queued ?? 0) of \(result.total ?? 0) remembered bundles."
                : (result.error ?? "Rebuild failed."))
        } catch {
            bulkAlert = BulkAlert(message: error.localizedDescription)
        }
        isRebuilding = false
    }

    private func resignAll() async {
        isResigning = true
        do {
            let result = try await api.resignAll()
            bulkAlert = BulkAlert(message: result.ok
                ? "Queued \(result.queued ?? 0) of \(result.total ?? 0) re-signs."
                : (result.error ?? "Re-sign failed."))
        } catch {
            bulkAlert = BulkAlert(message: error.localizedDescription)
        }
        isResigning = false
    }

    private func load() async {
        isLoading = true; errorMessage = nil
        do {
            let resp = try await api.library()
            stars = resp.stars
            watches = resp.watches
            presets = resp.presets ?? []
            sources = resp.sources ?? []
            notes = resp.notes ?? []
            pins = resp.pins ?? []
            aliases = resp.aliases ?? []
            tfWatches = resp.tfWatches ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
        do {
            let resp = try await api.signed()
            signed = resp.signed
        } catch {
            // signed history is best-effort — don't block the rest of Library on it
        }
        scheduleExpiryReminders()
        maybeNudgeUnsignedStars()
        isLoading = false
    }

    // At most one nudge per day — starred apps with a download source but no
    // matching entry in the last-24h signed list are "waiting to be signed".
    private func maybeNudgeUnsignedStars() {
        let signedBundles = Set(signed.map { $0.bundle })
        let waiting = stars.filter { !signedBundles.contains($0.bundle_id) && ($0.download_url?.isEmpty == false || $0.vault_msg_id != nil) }
        guard waiting.count >= 3 else { return }
        let lastKey = "ipabot.lastUnsignedNudge"
        let last = UserDefaults.standard.object(forKey: lastKey) as? Date
        guard last == nil || Date().timeIntervalSince(last!) > 24 * 3600 else { return }
        UserDefaults.standard.set(Date(), forKey: lastKey)
        LocalNotifier.fireNow(
            id: "unsigned-nudge",
            title: "\(waiting.count) starred apps waiting",
            body: "Sign them now, or say \"Sign my starred apps in IPABot\" to Siri."
        )
    }

    private func unstar(at indexSet: IndexSet) async {
        for i in indexSet.sorted(by: >) {
            let bundle = stars[i].bundle_id
            do {
                try await api.setStar(bundleId: bundle, on: false)
                stars.remove(at: i)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func addWatch() async {
        let term = newWatchTerm.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return }
        do {
            try await api.addWatch(term: term)
            newWatchTerm = ""
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeWatch(at indexSet: IndexSet) async {
        for i in indexSet.sorted(by: >) {
            let term = watches[i].term
            do {
                try await api.removeWatch(term: term)
                watches.remove(at: i)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func removeSources(at indexSet: IndexSet) async {
        for i in indexSet.sorted(by: >) {
            let name = sources[i].name
            do {
                try await api.removeSource(name: name)
                sources.remove(at: i)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func removeNotes(at indexSet: IndexSet) async {
        for i in indexSet.sorted(by: >) {
            let bundle = notes[i].bundle
            do {
                try await api.removeNote(bundle: bundle)
                notes.remove(at: i)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func removePins(at indexSet: IndexSet) async {
        for i in indexSet.sorted(by: >) {
            let bundle = pins[i].bundle
            do {
                try await api.removePin(bundle: bundle)
                pins.remove(at: i)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func removeAliases(at indexSet: IndexSet) async {
        for i in indexSet.sorted(by: >) {
            let short = aliases[i].short
            do {
                try await api.removeAlias(short: short)
                aliases.remove(at: i)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func removeTfWatches(at indexSet: IndexSet) async {
        for i in indexSet.sorted(by: >) {
            let id = tfWatches[i].id
            do {
                try await api.removeTfWatch(id: id)
                tfWatches.remove(at: i)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
