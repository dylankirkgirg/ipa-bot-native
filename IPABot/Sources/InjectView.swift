import SwiftUI

struct InjectView: View {
    @EnvironmentObject var api: APIClient
    @Environment(\.dismiss) private var dismiss
    let hit: Hit

    @State private var tweaks: [Tweak] = []
    @State private var presets: [PresetEntry] = []
    @State private var selected: Set<String> = []
    @State private var isLoadingTweaks = false
    @State private var errorMessage: String?

    @State private var isBusy = false
    @State private var statusNote: String?
    @State private var installTarget: DownloadTarget?
    @State private var pollTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
                if let statusNote {
                    Section {
                        Label(statusNote, systemImage: isBusy ? "hourglass" : "checkmark.circle.fill")
                            .foregroundStyle(isBusy ? Color.secondary : Color.green)
                    }
                }
                if !presets.isEmpty {
                    Section("Presets") {
                        ForEach(presets) { preset in
                            Button {
                                selected = Set(preset.tweaks)
                            } label: {
                                HStack {
                                    Image(systemName: "square.stack.3d.up.fill")
                                    Text(preset.name).foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(preset.tweaks.count)").foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                Section("Tweaks") {
                    if isLoadingTweaks {
                        ProgressView()
                    } else if tweaks.isEmpty {
                        Text("No tweaks available.").foregroundStyle(.secondary)
                    }
                    ForEach(tweaks) { tweak in
                        Button {
                            if selected.contains(tweak.id) { selected.remove(tweak.id) }
                            else { selected.insert(tweak.id) }
                        } label: {
                            HStack {
                                Text(tweak.emoji)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tweak.name).foregroundStyle(.primary)
                                    Text(tweak.category).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selected.contains(tweak.id) {
                                    Image(systemName: "checkmark").foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(hit.app_name)
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadTweaks() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { pollTask?.cancel(); dismiss() }
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Sign as-is") { Task { await signOnly() } }
                        .disabled(isBusy)
                    Spacer()
                    Button("Inject (\(selected.count))") { Task { await injectSelected() } }
                        .disabled(isBusy || selected.isEmpty)
                }
            }
            .sheet(item: $installTarget) { target in
                SafariView(url: target.url)
            }
        }
    }

    private func loadTweaks() async {
        isLoadingTweaks = true
        do {
            tweaks = try await api.tweaks().tweaks
            presets = try await api.library().presets ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingTweaks = false
    }

    private func signOnly() async {
        isBusy = true; errorMessage = nil; statusNote = nil
        do {
            let result = try await api.sign(ipaUrl: hit.download_url, ipaName: hit.app_name, options: SignOptions())
            if result.ok {
                statusNote = result.note ?? "Signing queued — check the Signed tab shortly."
            } else {
                errorMessage = result.error ?? "Sign request failed."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isBusy = false
    }

    private func injectSelected() async {
        isBusy = true; errorMessage = nil; statusNote = nil
        do {
            let result = try await api.inject(hit: hit, tweakIds: Array(selected))
            guard result.ok, let id = result.web_id ?? result.id else {
                errorMessage = result.error ?? "Inject request failed."
                isBusy = false
                return
            }
            statusNote = "Injecting — this can take a few minutes…"
            pollTask?.cancel()
            pollTask = Task { await pollInject(id: id) }
        } catch {
            errorMessage = error.localizedDescription
            isBusy = false
        }
    }

    private func pollInject(id: String) async {
        for _ in 0..<90 {
            if Task.isCancelled { return }
            do {
                let poll = try await api.injectResult(id: id)
                if let url = poll.url {
                    statusNote = "Done — \(poll.name ?? "tweaked.ipa")"
                    installTarget = URL(string: url).map(DownloadTarget.init)
                    isBusy = false
                    return
                }
                if let err = poll.error {
                    errorMessage = err
                    isBusy = false
                    return
                }
            } catch {
                // transient poll failure — keep trying until the loop times out
            }
            try? await Task.sleep(nanoseconds: 4_000_000_000)
        }
        errorMessage = "Timed out waiting for the inject job."
        isBusy = false
    }
}
