import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var api: APIClient
    let bundleId: String
    let seedName: String

    @State private var result: DiscoverResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var downloadTarget: DownloadTarget?
    @State private var injectTarget: Hit?

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
                            onDownload: hit.download_url.isEmpty ? nil : { downloadTarget = URL(string: hit.download_url).map(DownloadTarget.init) },
                            onInject: hit.download_url.isEmpty ? nil : { injectTarget = hit }
                        )
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
