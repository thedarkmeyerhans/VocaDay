import Foundation
import UserNotifications
import VocaDayCore

/// Schedules VocaDay's local notifications. Everything is planned on the
/// device, no server or push certificate is needed.
final class NotificationScheduler {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func isAuthorized() async -> Bool {
        let status = await center.notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional || status == .ephemeral
    }

    /// Shows a notification right away (e.g. when a place was entered).
    func notifyNow(title: String, body: String, url: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let url { content.userInfo = ["url": url] }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        center.add(UNNotificationRequest(identifier: "vocaday.now.\(UUID().uuidString)", content: content,
                                         trigger: trigger))
    }

    /// Replaces all pending VocaDay notifications with `entries`.
    func replace(with entries: [Reminder]) async {
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(NotificationPlanner.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        guard await isAuthorized() else { return }
        for entry in entries {
            let content = UNMutableNotificationContent()
            content.title = entry.title
            content.body = entry.body
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: entry.date, repeats: false)
            let request = UNNotificationRequest(identifier: entry.id, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
}
