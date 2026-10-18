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

    // MARK: - Word of the Day & weekly recap

    private static let wordPrefix = "wotd-"
    private static let weeklyID = "weekly-recap"

    /// One notification per morning (9:00) for the next week, each naming that
    /// day's word. Non-repeating, so every day can carry a different word;
    /// refreshed on each launch.
    static func scheduleWordsOfTheDay(level: String) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers:
            pending.map(\.identifier).filter { $0.hasPrefix(wordPrefix) })
        let calendar = Calendar.current
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: Date()),
                  var fire = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day),
                  let word = VocabularyService.shared.wordOfTheDay(level: level, date: day) else { continue }
            if fire <= Date() { continue }   // today's 9:00 already passed
            fire = max(fire, Date().addingTimeInterval(60))
            let content = UNMutableNotificationContent()
            content.title = "Word of the Day"
            content.body = "\(word.word): \(word.translation). Open SpotOn to save it."
            content.sound = .default
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let id = wordPrefix + DateFormatter.spotDate.string(from: day)
            try? await center.add(UNNotificationRequest(identifier: id, content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        }
    }

    /// Saturday 20:00, the end of the week: a nudge to open the weekly recap.
    static func scheduleWeeklyRecap() {
        let content = UNMutableNotificationContent()
        content.title = "Your week in SpotOn"
        content.body = "See your weekly recap, your streak and this week's challenge."
        content.sound = .default
        var comps = DateComponents(); comps.weekday = 7; comps.hour = 20
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: weeklyID, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)))
    }

    static func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0 == reminderID || $0 == weeklyID || $0.hasPrefix(wordPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    /// Brings every scheduled notification in line with Settings
    /// (`dailyReminderOn` / `dailyReminderHour`). Safe to call on every launch:
    /// the permission prompt only appears the first time.
    static func syncWithSettings(level: String? = nil) async {
        let defaults = UserDefaults.standard
        let isOn = defaults.object(forKey: "dailyReminderOn") as? Bool ?? true
        guard isOn else { cancelAll(); return }
        guard await requestPermission() else { return }
        let hour = defaults.object(forKey: "dailyReminderHour") as? Int ?? 20
        scheduleDailyReminder(at: hour)
        scheduleWeeklyRecap()
        if let level { await scheduleWordsOfTheDay(level: level) }
    }
}
