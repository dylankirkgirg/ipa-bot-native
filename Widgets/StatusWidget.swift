import WidgetKit
import SwiftUI

private struct StatusSnapshot: Codable {
    struct Queues: Codable { var decrypt: Int; var inject: Int }
    var queues: Queues
    var signCount: Int
    var vaultEntries: Int
}

private struct SniperSnapshot: Codable {
    struct Heartbeat: Codable { var status: String; var fresh: Bool }
    var heartbeat: Heartbeat?
}

struct StatusEntry: TimelineEntry {
    let date: Date
    let queueTotal: Int
    let signCount: Int
    let sniperStatus: String?
    let configured: Bool
}

struct StatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatusEntry {
        StatusEntry(date: Date(), queueTotal: 0, signCount: 0, sniperStatus: nil, configured: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        Task {
            let entry = await fetchEntry()
            // Widgets refresh at OS discretion regardless of what's requested here
            // (typically 15-60min) — this just states the earliest we'd want one.
            let next = Date().addingTimeInterval(30 * 60)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func fetchEntry() async -> StatusEntry {
        guard let cfg = SharedConfig.read() else {
            return StatusEntry(date: Date(), queueTotal: 0, signCount: 0, sniperStatus: nil, configured: false)
        }
        async let status = fetchJSON(StatusSnapshot.self, path: "/api/status", cfg: cfg)
        async let sniper = fetchJSON(SniperSnapshot.self, path: "/api/sniper", cfg: cfg)
        let (s, sn) = await (status, sniper)
        return StatusEntry(
            date: Date(),
            queueTotal: (s?.queues.decrypt ?? 0) + (s?.queues.inject ?? 0),
            signCount: s?.signCount ?? 0,
            sniperStatus: sn?.heartbeat?.status,
            configured: true
        )
    }

    private func fetchJSON<T: Decodable>(_ type: T.Type, path: String, cfg: (baseURL: String, secret: String)) async -> T? {
        guard let url = URL(string: cfg.baseURL + path) else { return nil }
        var req = URLRequest(url: url)
        req.setValue(cfg.secret, forHTTPHeaderField: "X-Inject-Secret")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

struct StatusWidgetView: View {
    let entry: StatusEntry

    var body: some View {
        if !entry.configured {
            Text("Open IPABot to sign in").font(.caption).foregroundStyle(.secondary).padding()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("IPABOT").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                HStack {
                    stat("\(entry.queueTotal)", "queued")
                    Spacer()
                    stat("\(entry.signCount)", "signed")
                }
                if let sniperStatus = entry.sniperStatus {
                    HStack(spacing: 4) {
                        Circle().fill(sniperStatus == "hunting" ? Color.orange : Color.green).frame(width: 6, height: 6)
                        Text("A1: \(sniperStatus)").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if entry.queueTotal > 0 {
                    if #available(iOS 17.0, *) {
                        Button(intent: ClearQueueIntent()) {
                            Text("Clear queue").font(.system(size: 10, weight: .bold))
                        }
                        .tint(.red)
                    }
                }
            }
            .padding()
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.system(size: 20, weight: .bold))
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }
}

struct StatusWidget: Widget {
    let kind = "StatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatusProvider()) { entry in
            StatusWidgetView(entry: entry)
                .background(Color.black)
                .widgetURL(URL(string: "ipabot://open?tab=diagnostics"))
        }
        .configurationDisplayName("IPABot Status")
        .description("Queue depth, signed count, and A1 sniper status.")
        .supportedFamilies([.systemSmall])
    }
}
