import SwiftUI

struct TrendingView: View {
    @EnvironmentObject var api: APIClient
    @Environment(\.dismiss) private var dismiss
    var onSelect: (String) -> Void

    @State private var trending: [TrendingEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
                if trending.isEmpty && !isLoading && errorMessage == nil {
                    Text("Not enough search history yet.").foregroundStyle(.secondary)
                }
                ForEach(trending) { entry in
                    Button {
                        onSelect(entry.original)
                        dismiss()
                    } label: {
                        HStack {
                            Label(entry.original, systemImage: "flame")
                            Spacer()
                            if entry.count > 1 {
                                Text("×\(entry.count)").foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Trending")
            .navigationBarTitleDisplayMode(.inline)
            .overlay { if isLoading { ProgressView() } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true; errorMessage = nil
        do {
            trending = try await api.trending().trending
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
