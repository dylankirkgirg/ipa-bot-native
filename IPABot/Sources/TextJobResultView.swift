import SwiftUI

struct TextJobResultView: View {
    let title: String
    let jobId: String

    @EnvironmentObject var api: APIClient
    @State private var text: String?
    @State private var errorMessage: String?
    @State private var isPolling = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if isPolling {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Working…").font(Ledger.body(13)).foregroundColor(Ledger.textSecondary)
                        }
                        .padding(20)
                    } else if let errorMessage {
                        Text(errorMessage).font(Ledger.body(13)).foregroundColor(Ledger.accent).padding(20)
                    } else if let text {
                        Text(Self.stripHTML(text))
                            .font(Ledger.mono(12))
                            .foregroundColor(Ledger.text)
                            .textSelection(.enabled)
                            .padding(20)
                    }
                }
            }
            .ledgerBackground()
            .scrollIndicators(.hidden)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .task { await poll() }
        }
    }

    private func poll() async {
        for _ in 0..<40 {
            if Task.isCancelled { return }
            do {
                let r = try await api.textJobResult(id: jobId)
                if r.pending == true { try? await Task.sleep(nanoseconds: 3_000_000_000); continue }
                isPolling = false
                if r.ok == true { text = r.text ?? "" } else { errorMessage = r.error ?? "Failed." }
                return
            } catch {
                isPolling = false
                errorMessage = error.localizedDescription
                return
            }
        }
        isPolling = false
        errorMessage = "Timed out waiting for a result."
    }

    // Result text is built with Telegram HTML tags (server side is shared
    // with the bot) — strip them for a plain-text native display.
    private static func stripHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}
