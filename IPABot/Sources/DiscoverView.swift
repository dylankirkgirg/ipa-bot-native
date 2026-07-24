import SwiftUI
import UIKit

struct DiscoverView: View {
    @EnvironmentObject var api: APIClient
    let bundleId: String
    let seedName: String

    @State private var result: DiscoverResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var downloadTarget: DownloadTarget?
    @State private var injectTarget: Hit?
    @State private var shareTarget: ShareTarget?
    @State private var isDownloadingVault = false

    var body: some View {
        List {
            if let errorMessage {
                Text(errorMessage).foregroundStyle(Ledger.accent)
            }
            if let result {
                if result.apps.isEmpty {
                    Text("No other apps by \(result.artist_name ?? "this developer") found in our sources.")
                        .foregroundStyle(.secondary)
                }
                ForEach(result.apps) { app in
                    if let hit = app.hit {
                        HitRow(
                            hit: hit,
                            onDownload: downloadAction(for: hit),
                            onInject: canDeliver(hit) ? { injectTarget = hit } : nil
                        )
                        .contextMenu {
                            if !hit.bundle_id.isEmpty {
                                Button { UIPasteboard.general.string = hit.bundle_id } label: { Label("Copy bundle ID", systemImage: "doc.on.doc") }
                            }
                            if !hit.download_url.isEmpty {
                                Button { UIPasteboard.general.string = hit.download_url } label: { Label("Copy download URL", systemImage: "link") }
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.app_name).font(.subheadline)
                            Text("not yet in our sources").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .ledgerBackground()
        .navigationTitle(result?.artist_name ?? "More by this dev")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .overlay { if isLoading { ProgressView() } }
        .sheet(item: $downloadTarget) { target in
            SafariView(url: target.url)
        }
        .sheet(item: $injectTarget) { hit in
            InjectView(hit: hit)
        }
        .sheet(item: $shareTarget) { target in ShareSheet(items: [target.url]) }
    }

    private func canDeliver(_ hit: Hit) -> Bool {
        !hit.download_url.isEmpty || hit.vault_msg_id != nil
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

    private func load() async {
        isLoading = true; errorMessage = nil
        do {
            result = try await api.discover(bundle: bundleId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
