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
                Text(errorMessage).foregroundStyle(Ledger.accent)
                    .listRowSeparator(.hidden).listRowBackground(Color.clear)
            }
            if let info {
                HStack(spacing: 14) {
                    AsyncImage(url: info.artwork_url.flatMap(URL.init)) { phase in
                        if case .success(let image) = phase { image.resizable().aspectRatio(contentMode: .fill) }
                        else { Rectangle().fill(Ledger.surface) }
                    }
                    .frame(width: 56, height: 56).clipped()

                    VStack(alignment: .leading, spacing: 2) {
                        Text(info.app_name).font(Ledger.heading(15, weight: .semibold)).foregroundColor(Ledger.text)
                        Text(info.bundle_id).font(Ledger.mono(11)).foregroundColor(Ledger.textTertiary)
                        if let genre = info.genre {
                            Text(genre + (info.artist_name.map { " · \($0)" } ?? ""))
                                .font(Ledger.body(12)).foregroundColor(Ledger.textSecondary)
                        }
                    }
                }
                .padding(.vertical, 8)
                .listRowSeparator(.hidden).listRowBackground(Color.clear)

                if let rating = info.rating {
                    LedgerKeyValueRow(key: "App Store", value: String(format: "%.1f★ (%@)", rating, formattedCount(info.rating_count)))
                        .listRowSeparator(.hidden).listRowBackground(Color.clear)
                }

                LedgerSectionLabel(text: "Availability")
                    .listRowSeparator(.hidden).listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                if let v = info.latest_version {
                    LedgerKeyValueRow(key: "Latest", value: "v\(v)" + (info.latest_date.map { " · \($0)" } ?? ""))
                        .listRowSeparator(.hidden).listRowBackground(Color.clear)
                }
                if let names = info.source_names, !names.isEmpty {
                    LedgerKeyValueRow(key: "Sources", value: names.joined(separator: ", "))
                        .listRowSeparator(.hidden).listRowBackground(Color.clear)
                } else {
                    LedgerKeyValueRow(key: "Sources", value: "\(info.source_count) feed\(info.source_count == 1 ? "" : "s")")
                        .listRowSeparator(.hidden).listRowBackground(Color.clear)
                }
                if info.vault_count > 0 {
                    LedgerKeyValueRow(key: "TG vault", value: "\(info.vault_count) entr\(info.vault_count == 1 ? "y" : "ies")")
                        .listRowSeparator(.hidden).listRowBackground(Color.clear)
                }
                Button { showChangelog = true } label: {
                    HStack {
                        Glyph(.note, size: 14, color: Ledger.textSecondary)
                        Text("Changelog").font(Ledger.body(13)).foregroundColor(Ledger.text)
                        Spacer()
                        Glyph(.chevronRight, size: 12, color: Ledger.textTertiary)
                    }
                }
                .padding(.vertical, 9).overlay(alignment: .bottom) { Rectangle().fill(Ledger.dividerSoft).frame(height: 1) }
                .listRowSeparator(.hidden).listRowBackground(Color.clear)
                if info.discoverable {
                    NavigationLink { DiscoverView(bundleId: info.bundle_id, seedName: info.app_name) } label: {
                        HStack {
                            Text("More by this dev").font(Ledger.body(13)).foregroundColor(Ledger.text)
                            Spacer()
                            Glyph(.chevronRight, size: 12, color: Ledger.textTertiary)
                        }
                    }
                    .padding(.vertical, 9)
                    .listRowSeparator(.hidden).listRowBackground(Color.clear)
                }

                LedgerSectionLabel(text: "Your library")
                    .listRowSeparator(.hidden).listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                HStack {
                    Glyph(.star, size: 14, color: info.starred ? Ledger.accent : Ledger.textTertiary)
                    Text(info.starred ? "Starred" : "Not starred").font(Ledger.body(13)).foregroundColor(Ledger.text)
                }
                .padding(.vertical, 9).overlay(alignment: .bottom) { Rectangle().fill(Ledger.dividerSoft).frame(height: 1) }
                .listRowSeparator(.hidden).listRowBackground(Color.clear)
                if let pin = info.pinned_version {
                    LedgerKeyValueRow(key: "Pinned at", value: "v\(pin)")
                        .listRowSeparator(.hidden).listRowBackground(Color.clear)
                }
                if !info.auto_tweaks.isEmpty {
                    LedgerKeyValueRow(key: "Auto-inject", value: info.auto_tweaks.joined(separator: " + "), valueIsMono: false)
                        .listRowSeparator(.hidden).listRowBackground(Color.clear)
                }
                if let note = info.note {
                    LedgerKeyValueRow(key: "Note", value: note, valueIsMono: false)
                        .listRowSeparator(.hidden).listRowBackground(Color.clear)
                }
                if let signed = info.last_signed {
                    LedgerKeyValueRow(key: "Last signed", value: "v\(signed.version)")
                        .listRowSeparator(.hidden).listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .ledgerBackground()
        .scrollIndicators(.hidden)
        .navigationTitle(info?.app_name ?? fallbackName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .overlay { if isLoading { ProgressView() } }
        .sheet(isPresented: $showChangelog) { ChangelogView(query: info?.app_name ?? fallbackName) }
    }

    private func formattedCount(_ n: Int?) -> String {
        guard let n else { return "0" }
        if n >= 1000 { return String(format: "%.1fk", Double(n) / 1000) }
        return "\(n)"
    }

    private func load() async {
        isLoading = true; errorMessage = nil
        do { info = try await api.about(bundle: bundleId) } catch { errorMessage = error.localizedDescription }
        isLoading = false
    }
}
