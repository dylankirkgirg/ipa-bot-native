import UIKit

/// Extends the OS's background execution grace period (typically ~30s, up to
/// a few minutes) for the duration a poll loop runs — covers the common case
/// of backgrounding the app right as a quick sign/inject job is finishing.
/// Not a substitute for real background execution (BGTaskScheduler runs are
/// opportunistic and far too infrequent for an active few-minute poll loop);
/// this only buys the tail end of jobs that are nearly done.
final class BackgroundTaskGuard {
    private var id: UIBackgroundTaskIdentifier = .invalid

    func begin() {
        end()
        id = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.end()
        }
    }

    func end() {
        guard id != .invalid else { return }
        UIApplication.shared.endBackgroundTask(id)
        id = .invalid
    }
}
