import SwiftUI
import ActivityKit

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
    @State private var customUrl = ""
    @State private var showAddTweak = false
    // Type-erased since Activity<T> requires iOS 16.2 availability, which a
    // stored property's type can't carry on a struct with no such guard.
    @State private var activityBox: Any?

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
                Section {
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
                } header: {
                    HStack {
                        Text("Tweaks")
                        Spacer()
                        Button { showAddTweak = true } label: {
                            Image(systemName: "plus.circle")
                        }
                    }
                }

                Section {
                    TextField(".deb / .dylib URL", text: $customUrl)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Inject Custom URL") { Task { await injectCustomUrl() } }
                        .disabled(isBusy || customUrl.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Label("Custom Tweak", systemImage: "link")
                } footer: {
                    Text("One-off inject, not saved to your tweak catalog.")
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
            .sheet(isPresented: $showAddTweak) {
                AddTweakSheet(onSaved: { Task { await loadTweaks() } })
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

    private func injectCustomUrl() async {
        isBusy = true; errorMessage = nil; statusNote = nil
        do {
            let result = try await api.injectCustom(hit: hit, customUrl: customUrl.trimmingCharacters(in: .whitespaces))
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
        if #available(iOS 16.2, *) {
            activityBox = LiveActivityManager.start(jobId: id, appName: hit.app_name, kind: "inject")
        }
        let bgGuard = BackgroundTaskGuard()
        bgGuard.begin()
        defer { bgGuard.end() }
        for _ in 0..<90 {
            if Task.isCancelled { return }
            do {
                let poll = try await api.injectResult(id: id)
                if let url = poll.url {
                    statusNote = "Done — \(poll.name ?? "tweaked.ipa")"
                    installTarget = URL(string: url).map(DownloadTarget.init)
                    isBusy = false
                    endActivity(status: "done", detail: poll.name ?? "Done")
                    return
                }
                if let err = poll.error {
                    errorMessage = err
                    isBusy = false
                    endActivity(status: "failed", detail: err)
                    return
                }
            } catch {
                // transient poll failure — keep trying until the loop times out
            }
            try? await Task.sleep(nanoseconds: 4_000_000_000)
        }
        errorMessage = "Timed out waiting for the inject job."
        isBusy = false
        endActivity(status: "failed", detail: "Timed out")
    }

    private func endActivity(status: String, detail: String) {
        if #available(iOS 16.2, *) {
            LiveActivityManager.end(activityBox as? Activity<InjectActivityAttributes>, status: status, detail: detail)
        }
        activityBox = nil
    }
}
