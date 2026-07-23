import SwiftUI

struct SignedView: View {
    @EnvironmentObject var api: APIClient
    @State private var signed: [SignedApp] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var installTarget: DownloadTarget?
    @State private var isResigning = false
    @State private var resignAlert: ResignAlert?

    struct ResignAlert: Identifiable {
        let id = UUID()
        let message: String
    }

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
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
            .listStyle(.insetGrouped)
            .navigationTitle("Signed")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await resignAll() }
                    } label: {
                        if isResigning { ProgressView() } else { Image(systemName: "arrow.triangle.2.circlepath") }
                    }
                    .disabled(isResigning || signed.isEmpty)
                }
            }
            .alert(item: $resignAlert) { alert in
                Alert(title: Text("Re-sign All"), message: Text(alert.message), dismissButton: .default(Text("OK")))
            }
            .task { await load() }
            .refreshable { await load() }
            .overlay {
                if isLoading { ProgressView() }
                else if signed.isEmpty && errorMessage == nil {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.seal").font(.largeTitle).foregroundStyle(.secondary)
                        Text("No recently signed apps").foregroundStyle(.secondary)
                        Text("Signed apps show up here for ~24h").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
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

    private func resignAll() async {
        isResigning = true
        do {
            let result = try await api.resignAll()
            resignAlert = ResignAlert(message: result.ok
                ? "Queued \(result.queued ?? 0) of \(result.total ?? 0) re-signs."
                : (result.error ?? "Re-sign failed."))
        } catch {
            resignAlert = ResignAlert(message: error.localizedDescription)
        }
        isResigning = false
    }
}
