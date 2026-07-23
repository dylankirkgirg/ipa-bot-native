import SwiftUI

struct SignedView: View {
    @EnvironmentObject var api: APIClient
    @State private var signed: [SignedApp] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var installTarget: DownloadTarget?

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
                if signed.isEmpty && !isLoading {
                    Text("No recently signed apps (~24h window).").foregroundStyle(.secondary)
                }
                ForEach(signed) { app in
                    Button {
                        installTarget = URL(string: api.baseURL + "/sign-install/" + app.id).map(DownloadTarget.init)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.title).font(.headline)
                            Text("v\(app.version) · \(app.bundle)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Signed")
            .task { await load() }
            .refreshable { await load() }
            .overlay { if isLoading { ProgressView() } }
            .sheet(item: $installTarget) { target in
                SafariView(url: target.url)
            }
        }
    }

    private func load() async {
        isLoading = true; errorMessage = nil
        do {
            let resp = try await api.signed()
            signed = resp.signed
            if let err = resp.error { errorMessage = err }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
