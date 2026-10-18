import Foundation
import UserNotifications

struct NotificationService {
    private static let reminderID = "daily-reminder"

    static func scheduleDailyReminder(at hour: Int = 20, minute: Int = 0) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderID])
        let content = UNMutableNotificationContent()
        content.title = "SpotOn"
        content.body  = "Time for your daily word practice!"
        content.sound = .default
        var comps = DateComponents(); comps.hour = hour; comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        center.add(UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger))
    }

    static func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderID])
    }

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }

    /// Brings the scheduled reminder in line with the Settings toggle and hour
    /// (`dailyReminderOn` / `dailyReminderHour`). Safe to call on every launch:
    /// the permission prompt only appears the first time.
    static func syncWithSettings() async {
        let defaults = UserDefaults.standard
        let isOn = defaults.object(forKey: "dailyReminderOn") as? Bool ?? true
        guard isOn else { cancelDailyReminder(); return }
        guard await requestPermission() else { return }
        let hour = defaults.object(forKey: "dailyReminderHour") as? Int ?? 20
        scheduleDailyReminder(at: hour)
    }
}
