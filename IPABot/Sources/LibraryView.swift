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
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var newWatchTerm = ""

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
                Section {
                    if stars.isEmpty {
                        Text("No starred apps yet.").foregroundStyle(.secondary)
                    }
                    ForEach(stars) { star in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(star.app_name).font(.headline)
                            Text(star.bundle_id).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { indexSet in
                        Task { await unstar(at: indexSet) }
                    }
                } header: { header("Starred", count: stars.count, icon: "star.fill") }

                Section {
                    HStack {
                        TextField("Add a watch term", text: $newWatchTerm)
                            .textInputAutocapitalization(.never)
                        Button("Add") { Task { await addWatch() } }
                            .disabled(newWatchTerm.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    ForEach(watches) { w in
                        HStack {
                            Text(w.term)
                            if let mv = w.minVersion { Text("≥\(mv)").font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    .onDelete { indexSet in
                        Task { await removeWatch(at: indexSet) }
                    }
                } header: { header("Watches", count: watches.count, icon: "eye.fill") }

                if !presets.isEmpty {
                    Section {
                        ForEach(presets) { p in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name).font(.headline)
                                Text("\(p.tweaks.count) tweak(s)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .onDelete { indexSet in
                            Task { await removePresets(at: indexSet) }
                        }
                    } header: { header("Presets", count: presets.count, icon: "square.stack.3d.up.fill") }
                }
                if !sources.isEmpty {
                    Section {
                        ForEach(sources) { s in
                            HStack {
                                Text(s.emoji ?? "📦")
                                Text(s.name)
                                if s.blacklisted == true {
                                    Text("blacklisted").font(.caption2).foregroundStyle(.red)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            Task { await removeSources(at: indexSet) }
                        }
                    } header: { header("Sources", count: sources.count, icon: "tray.2.fill") }
                }
                if !notes.isEmpty {
                    Section {
                        ForEach(notes) { n in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(n.bundle).font(.caption).foregroundStyle(.secondary)
                                Text(n.text)
                            }
                        }
                        .onDelete { indexSet in
                            Task { await removeNotes(at: indexSet) }
                        }
                    } header: { header("Notes", count: notes.count, icon: "note.text") }
                }
                if !pins.isEmpty {
                    Section {
                        ForEach(pins) { p in
                            HStack {
                                Text(p.bundle)
                                Spacer()
                                Text(p.version).foregroundStyle(.secondary)
                            }
                        }
                        .onDelete { indexSet in
                            Task { await removePins(at: indexSet) }
                        }
                    } header: { header("Pins", count: pins.count, icon: "pin.fill") }
                }
                if !aliases.isEmpty {
                    Section {
                        ForEach(aliases) { a in
                            HStack {
                                Text(a.short).font(.headline)
                                Text("→ \(a.full)").foregroundStyle(.secondary)
                            }
                        }
                        .onDelete { indexSet in
                            Task { await removeAliases(at: indexSet) }
                        }
                    } header: { header("Aliases", count: aliases.count, icon: "at") }
                }
                if !tfWatches.isEmpty {
                    Section {
                        ForEach(tfWatches) { t in
                            HStack {
                                Text(t.name ?? t.url)
                                Spacer()
                                if let status = t.status { Text(status).font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                        .onDelete { indexSet in
                            Task { await removeTfWatches(at: indexSet) }
                        }
                    } header: { header("TestFlight Watches", count: tfWatches.count, icon: "airplane") }
                }
            }
            .navigationTitle("Library")
            .task { await load() }
            .refreshable { await load() }
            .overlay { if isLoading { ProgressView() } }
        }
    }

    @ViewBuilder
    private func header(_ title: String, count: Int, icon: String) -> some View {
        Label("\(title) (\(count))", systemImage: icon)
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
        isLoading = false
    }

    private func unstar(at indexSet: IndexSet) async {
        for i in indexSet {
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
        for i in indexSet {
            let term = watches[i].term
            do {
                try await api.removeWatch(term: term)
                watches.remove(at: i)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func removePresets(at indexSet: IndexSet) async {
        for i in indexSet {
            let name = presets[i].name
            do {
                try await api.removePreset(name: name)
                presets.remove(at: i)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func removeSources(at indexSet: IndexSet) async {
        for i in indexSet {
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
        for i in indexSet {
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
        for i in indexSet {
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
        for i in indexSet {
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
        for i in indexSet {
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
