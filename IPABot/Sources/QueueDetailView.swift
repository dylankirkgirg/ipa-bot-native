import SwiftUI

struct QueueDetailView: View {
    @EnvironmentObject var api: APIClient
    let type: String

    @State private var pending: [QueueJobEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
            if pending.isEmpty && !isLoading {
                Text("Queue is empty.").foregroundStyle(.secondary)
            }
            ForEach(pending) { job in
                VStack(alignment: .leading, spacing: 2) {
                    Text(job.status ?? "pending").font(.caption).foregroundStyle(.secondary)
                    Text(job.url ?? job.id).font(.subheadline).lineLimit(2)
                }
            }
            .onDelete { indexSet in
                Task { await cancel(at: indexSet) }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(type == "inject" ? "Inject Queue" : "Decrypt Queue")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !pending.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear All", role: .destructive) { Task { await clearAll() } }
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .overlay { if isLoading { ProgressView() } }
    }

    private func load() async {
        isLoading = true; errorMessage = nil
        do {
            pending = try await api.queue(type: type).pending
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func cancel(at indexSet: IndexSet) async {
        for i in indexSet {
            do {
                try await api.cancelQueueJob(type: type, id: pending[i].id)
                pending.remove(at: i)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func clearAll() async {
        do {
            try await api.clearQueue(type: type)
            pending = []
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
