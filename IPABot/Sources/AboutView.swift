import SwiftUI

struct AboutView: View {
    @EnvironmentObject var api: APIClient
    let bundleId: String
    let fallbackName: String

    @State private var info: AboutInfo?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showChangelog = false

    var body: some View {
        List {
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
            if let info {
                Section {
                    HStack(spacing: 12) {
                        AsyncImage(url: info.artwork_url.flatMap(URL.init)) { phase in
                            if case .success(let image) = phase {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                RoundedRectangle(cornerRadius: 12).fill(Color(.tertiarySystemFill))
                            }
                        }
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(info.app_name).font(.headline)
                            Text(info.bundle_id).font(.caption).foregroundStyle(.secondary)
                            if let genre = info.genre {
                                Text(genre + (info.artist_name.map { " · \($0)" } ?? ""))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    if let rating = info.rating {
                        LabeledContent("App Store", value: String(format: "%.1f★ (%@)", rating, formattedCount(info.rating_count)))
                    }
                }

                Section("Availability") {
                    if let v = info.latest_version {
                        LabeledContent("Latest version", value: "v\(v)" + (info.latest_date.map { " · \($0)" } ?? ""))
                    }
                    if let names = info.source_names, !names.isEmpty {
                        ForEach(names, id: \.self) { name in
                            Label(name, systemImage: "tray.2.fill")
                        }
                    } else {
                        LabeledContent("Sources", value: "\(info.source_count) feed\(info.source_count == 1 ? "" : "s")")
                    }
                    if info.vault_count > 0 {
                        LabeledContent("TG vault", value: "\(info.vault_count) entr\(info.vault_count == 1 ? "y" : "ies")")
                    }
                    Button {
                        showChangelog = true
                    } label: {
                        Label("Changelog", systemImage: "text.alignleft")
                    }
                    if info.discoverable {
                        NavigationLink {
                            DiscoverView(bundleId: info.bundle_id, seedName: info.app_name)
                        } label: {
                            Label("More by this dev", systemImage: "compass.drawing")
                        }
                    }
                }

                Section("Your library") {
                    Label(info.starred ? "Starred" : "Not starred", systemImage: info.starred ? "star.fill" : "star")
                        .foregroundStyle(info.starred ? .yellow : .secondary)
                    if let pin = info.pinned_version {
                        Label("Pinned at v\(pin)", systemImage: "pin.fill")
                    }
                    if !info.auto_tweaks.isEmpty {
                        Label("Auto-inject: \(info.auto_tweaks.joined(separator: " + "))", systemImage: "wand.and.stars")
                    }
                    if let note = info.note {
                        Label(note, systemImage: "note.text")
                    }
                    if let signed = info.last_signed {
                        Label("Last signed v\(signed.version)", systemImage: "signature")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(info?.app_name ?? fallbackName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .overlay { if isLoading { ProgressView() } }
        .sheet(isPresented: $showChangelog) {
            ChangelogView(query: info?.app_name ?? fallbackName)
        }
    }

    private func formattedCount(_ n: Int?) -> String {
        guard let n else { return "0" }
        if n >= 1000 { return String(format: "%.1fk", Double(n) / 1000) }
        return "\(n)"
    }

    private func load() async {
        isLoading = true; errorMessage = nil
        do {
            info = try await api.about(bundle: bundleId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
