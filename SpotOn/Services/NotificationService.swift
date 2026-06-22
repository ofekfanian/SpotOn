import Foundation
import UserNotifications

struct NotificationService {
    static func scheduleDailyReminder(at hour: Int = 20, minute: Int = 0) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        let content = UNMutableNotificationContent()
        content.title = "SpotOn"
        content.body  = "Time for your daily word practice!"
        content.sound = .default
        var comps = DateComponents(); comps.hour = hour; comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-reminder"])
    }

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }
}
