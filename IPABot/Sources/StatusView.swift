import SwiftUI

struct StatusView: View {
    @EnvironmentObject var api: APIClient
    @State private var status: StatusResponse?
    @State private var sniper: SniperHeartbeat?
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
                if let status {
                    Section("Services") {
                        beatRow("Finder", status.services.finder)
                        beatRow("Relay", status.services.relay)
                        beatRow("Inject", status.services.inject)
                    }
                    Section("Queues") {
                        NavigationLink {
                            QueueDetailView(type: "decrypt")
                        } label: {
                            LabeledContent("Decrypt", value: "\(status.queues.decrypt)")
                        }
                        NavigationLink {
                            QueueDetailView(type: "inject")
                        } label: {
                            LabeledContent("Inject", value: "\(status.queues.inject)")
                        }
                    }
                    Section("Stats") {
                        LabeledContent("Signed apps", value: "\(status.signCount)")
                        LabeledContent("Vault entries", value: "\(status.vaultEntries)")
                        if !status.build.isEmpty {
                            LabeledContent("Build", value: status.build)
                        }
                    }
                }
                if let sniper {
                    Section("A1 Sniper") {
                        HStack {
                            Circle()
                                .fill(sniper.fresh ? .green : .red)
                                .frame(width: 10, height: 10)
                            Text(sniper.status.capitalized)
                            Spacer()
                            Text(sniper.ageSec < 0 ? "never" : "\(sniper.ageSec)s ago")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        LabeledContent("Attempts", value: "\(sniper.attempts)")
                        LabeledContent("Throttles", value: "\(sniper.throttles)")
                        LabeledContent("Capacity denials", value: "\(sniper.capacityDenials)")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Status")
            .task { await load() }
            .refreshable { await load() }
            .overlay { if isLoading { ProgressView() } }
        }
    }

    @ViewBuilder
    private func beatRow(_ label: String, _ beat: ServiceBeat) -> some View {
        HStack {
            Circle()
                .fill(beat.fresh ? .green : .red)
                .frame(width: 10, height: 10)
            Text(label)
            Spacer()
            Text(beat.ageSec < 0 ? "never" : "\(beat.ageSec)s ago")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func load() async {
        isLoading = true; errorMessage = nil
        do {
            status = try await api.status()
        } catch {
            errorMessage = error.localizedDescription
        }
        sniper = try? await api.sniper().heartbeat
        isLoading = false
    }
}
