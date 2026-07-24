import UserNotifications

/// One-shot local alerts (cert expiry, stale-stars nudge). Dedup is the
/// caller's job — each id maps 1:1 to a pending/delivered notification, so
/// re-scheduling the same id just replaces it rather than stacking.
enum LocalNotifier {
    static func scheduleOnce(id: String, title: String, body: String, in seconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(seconds, 1), repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func fireNow(id: String, title: String, body: String) {
        scheduleOnce(id: id, title: title, body: body, in: 1)
    }
}
