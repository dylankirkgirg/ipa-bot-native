import ActivityKit

/// Thin wrapper around ActivityKit for the sign/inject/decrypt poll loops.
/// Local-only updates (started/updated/ended from the same poll loop that's
/// already hitting the API) — no APNs push-to-update needed.
@available(iOS 16.2, *)
enum LiveActivityManager {
    static func start(jobId: String, appName: String, kind: String) -> Activity<InjectActivityAttributes>? {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return nil }
        let attrs = InjectActivityAttributes(jobId: jobId, appName: appName, kind: kind)
        let state = InjectActivityAttributes.ContentState(status: "running", detail: "Working…")
        return try? Activity.request(attributes: attrs, content: .init(state: state, staleDate: nil))
    }

    static func end(_ activity: Activity<InjectActivityAttributes>?, status: String, detail: String) {
        guard let activity else { return }
        Task {
            await activity.end(
                .init(state: .init(status: status, detail: detail), staleDate: nil),
                dismissalPolicy: .after(.now.addingTimeInterval(15))
            )
        }
    }
}
