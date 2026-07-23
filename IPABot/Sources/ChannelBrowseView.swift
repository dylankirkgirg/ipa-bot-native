import SwiftUI

struct ChannelBrowseView: View {
    @EnvironmentObject var api: APIClient
    @Environment(\.dismiss) private var dismiss

    @State private var available: [String] = []
    @State private var hits: [Hit] = []
    @State private var selected: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var downloadTarget: DownloadTarget?
    @State private var shareTarget: ShareTarget?
    @State private var isDownloadingVault = false

    var body: some View {
        NavigationStack {
            List {
                if !available.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(available, id: \.self) { ch in
                                Button(ch) { Task { await load(ch) } }
                                    .font(Ledger.mono(12))
                                    .foregroundColor(selected == ch ? Ledger.bg : Ledger.textSecondary)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(selected == ch ? Ledger.text : Color.clear)
                                    .overlay(Rectangle().stroke(Ledger.divider, lineWidth: 1))
                            }
                        }
                    }
                    .listRowSeparator(.hidden).listRowBackground(Color.clear)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(Ledger.accent)
                        .listRowSeparator(.hidden).listRowBackground(Color.clear)
                }
                if selected == nil && !isLoading {
                    Text("Pick a channel to browse its recent drops.")
                        .font(Ledger.body(13)).foregroundColor(Ledger.textTertiary)
                        .listRowSeparator(.hidden).listRowBackground(Color.clear)
                }
                ForEach(hits) { hit in
                    HitRow(hit: hit, onDownload: downloadAction(for: hit))
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        .listRowSeparator(.hidden).listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .ledgerBackground()
            .navigationTitle("Channels")
            .navigationBarTitleDisplayMode(.inline)
            .overlay { if isLoading { ProgressView() } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await loadAvailable() }
            .sheet(item: $downloadTarget) { target in SafariView(url: target.url) }
            .sheet(item: $shareTarget) { target in ShareSheet(items: [target.url]) }
        }
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
        } catch { errorMessage = error.localizedDescription }
        isDownloadingVault = false
    }

    private func loadAvailable() async {
        isLoading = true; errorMessage = nil
        do { available = try await api.channel("").available ?? [] } catch { errorMessage = error.localizedDescription }
        isLoading = false
    }

    private func load(_ channel: String) async {
        isLoading = true; errorMessage = nil; selected = channel
        do {
            let r = try await api.channel(channel)
            hits = r.hits
        } catch { errorMessage = error.localizedDescription }
        isLoading = false
    }
}
