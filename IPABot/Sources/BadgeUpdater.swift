import UserNotifications

/// App icon badge = pending decrypt+inject queue depth, so you can see there's
/// work in flight without opening the app. Badge-only authorization (no
/// alerts/sounds) — a much lighter ask than full notification permission.
enum BadgeUpdater {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.badge]) { _, _ in }
    }

    static func set(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count)
    }
}
