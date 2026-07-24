import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject var api: APIClient
    @State private var status: StatusResponse?
    @State private var sniper: SniperHeartbeat?
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            List {
                Text("Diagnostics").font(Ledger.heading(26))
                    .padding(.top, 8)
                    .listRowSeparator(.hidden).listRowBackground(Color.clear)

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(Ledger.accent)
                        .listRowSeparator(.hidden).listRowBackground(Color.clear)
                }

                if let status {
                    HStack(spacing: 1) {
                        stat("\(status.signCount)", "signed")
                        stat("\(status.vaultEntries)", "vault")
                        stat(status.build.isEmpty ? "—" : status.build, "build", mono: true)
                    }
                    .background(Ledger.dividerSoft)
                    .overlay(Rectangle().stroke(Ledger.dividerSoft, lineWidth: 1))
                    .listRowSeparator(.hidden).listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))

                    LedgerSectionLabel(text: "Services")
                        .listRowSeparator(.hidden).listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                    beatRow("Finder", status.services.finder)
                    beatRow("Relay", status.services.relay)
                    beatRow("Inject", status.services.inject)

                    LedgerSectionLabel(text: "Queues")
                        .listRowSeparator(.hidden).listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                    NavigationLink { QueueDetailView(type: "decrypt") } label: {
                        LedgerKeyValueRow(key: "Decrypt", value: "\(status.queues.decrypt)")
                    }
                    .listRowSeparator(.hidden).listRowBackground(Color.clear)
                    NavigationLink { QueueDetailView(type: "inject") } label: {
                        LedgerKeyValueRow(key: "Inject", value: "\(status.queues.inject)")
                    }
                    .listRowSeparator(.hidden).listRowBackground(Color.clear)
                }

                if let sniper {
                    LedgerSectionLabel(text: "A1 Sniper")
                        .listRowSeparator(.hidden).listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                    HStack {
                        LedgerStatusDot(ok: sniper.fresh)
                        Text(sniper.status.capitalized).font(Ledger.body(13)).foregroundColor(Ledger.text)
                        Spacer()
                        Text(sniper.ageSec < 0 ? "never" : "\(sniper.ageSec)s ago")
                            .font(Ledger.mono(11)).foregroundColor(sniper.fresh ? Ledger.textTertiary : Ledger.accent)
                    }
                    .padding(.vertical, 9)
                    .overlay(alignment: .bottom) { Rectangle().fill(Ledger.dividerSoft).frame(height: 1) }
                    .listRowSeparator(.hidden).listRowBackground(Color.clear)
                    LedgerKeyValueRow(key: "Attempts", value: "\(sniper.attempts)")
                        .listRowSeparator(.hidden).listRowBackground(Color.clear)
                    LedgerKeyValueRow(key: "Throttles", value: "\(sniper.throttles)")
                        .listRowSeparator(.hidden).listRowBackground(Color.clear)
                    LedgerKeyValueRow(key: "Capacity denials", value: "\(sniper.capacityDenials)")
                        .listRowSeparator(.hidden).listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .ledgerBackground()
            .scrollIndicators(.hidden)
            .navigationBarHidden(true)
            .task { await load() }
            .refreshable { await load() }
            .overlay { if isLoading { ProgressView() } }
        }
    }

    private func stat(_ value: String, _ label: String, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(mono ? Ledger.mono(18, weight: .bold) : Ledger.heading(24)).foregroundColor(Ledger.text).lineLimit(1)
            Text(label).font(Ledger.mono(11)).foregroundColor(Ledger.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Ledger.bg)
    }

    @ViewBuilder
    private func beatRow(_ label: String, _ beat: ServiceBeat) -> some View {
        HStack {
            LedgerStatusDot(ok: beat.fresh)
            Text(label).font(Ledger.body(13)).foregroundColor(Ledger.text)
            Spacer()
            Text(beat.ageSec < 0 ? "never" : "\(beat.ageSec)s ago")
                .font(Ledger.mono(11))
                .foregroundColor(beat.fresh ? Ledger.textTertiary : Ledger.accent)
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) { Rectangle().fill(Ledger.dividerSoft).frame(height: 1) }
        .listRowSeparator(.hidden).listRowBackground(Color.clear)
    }

    private func load() async {
        isLoading = true; errorMessage = nil
        do {
            let s = try await api.status()
            status = s
            BadgeUpdater.set(s.queues.decrypt + s.queues.inject)
        } catch {
            errorMessage = error.localizedDescription
        }
        sniper = try? await api.sniper().heartbeat
        maybeNotifySniperStale()
        isLoading = false
    }

    // Fires once per stale streak, not once per poll — cleared as soon as
    // the sniper reports fresh again so a real re-staleness re-alerts.
    private func maybeNotifySniperStale() {
        guard let sniper else { return }
        let key = "ipabot.sniperWasStale"
        let wasStale = UserDefaults.standard.bool(forKey: key)
        if sniper.fresh {
            UserDefaults.standard.set(false, forKey: key)
        } else if !wasStale {
            UserDefaults.standard.set(true, forKey: key)
            LocalNotifier.fireNow(
                id: "sniper-stale",
                title: "A1 Sniper gone quiet",
                body: "No heartbeat in \(sniper.ageSec)s — check Diagnostics."
            )
        }
    }
}
