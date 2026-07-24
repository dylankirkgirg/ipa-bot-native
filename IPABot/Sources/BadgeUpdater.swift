import UserNotifications

/// App icon badge = pending decrypt+inject queue depth, so you can see there's
/// work in flight without opening the app. Also covers alert+sound now that
/// LocalNotifier uses this same authorization for expiry/nudge alerts.
enum BadgeUpdater {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .alert, .sound]) { _, _ in }
    }

    static func set(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count)
    }
}
