import Foundation
import UserNotifications

/// The daily reminder: one local notification a day naming that day's strait.
///
/// Off until the player turns it on (offered after their first Daily Strait
/// win, and in the Locker). The Daily Strait is decided by the date alone, so
/// the next week of reminders can say exactly what each day holds without the
/// app being opened. Nothing is sent anywhere; these are local notifications.
enum Reminders {
    private static let onKey = "reminders.on"
    private static let hourKey = "reminders.hour"
    private static let askedKey = "reminders.asked"

    static var isOn: Bool { UserDefaults.standard.bool(forKey: onKey) }
    /// Hour of day, 18 (6 PM) unless changed.
    static var hour: Int {
        get { UserDefaults.standard.object(forKey: hourKey) as? Int ?? 18 }
        set { UserDefaults.standard.set(newValue, forKey: hourKey) }
    }
    static var wasOffered: Bool {
        get { UserDefaults.standard.bool(forKey: askedKey) }
        set { UserDefaults.standard.set(newValue, forKey: askedKey) }
    }

    /// Ask the system, then switch on. False when the player says no.
    static func turnOn(streak: Int, wonToday: Bool) async -> Bool {
        wasOffered = true
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        UserDefaults.standard.set(granted, forKey: onKey)
        if granted { schedule(streak: streak, wonToday: wonToday) }
        return granted
    }

    static func turnOff() {
        UserDefaults.standard.set(false, forKey: onKey)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: (0..<8).map { "daily-\($0)" })
    }

    /// The next seven days, rewritten whenever the app is opened or a round ends.
    static func schedule(streak: Int, wonToday: Bool, now: Date = Date()) {
        guard isOn else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: (0..<8).map { "daily-\($0)" })
        let cal = Calendar.current
        for offset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: offset, to: now),
                  var when = cal.date(bySettingHour: hour, minute: 0, second: 0, of: day) else { continue }
            if offset == 0 && (wonToday || when <= now) { continue }
            when = max(when, now.addingTimeInterval(60))
            let strait = DailyStrait.on(DailyStrait.key(day))
            let content = UNMutableNotificationContent()
            content.title = "Daily Strait #\(strait.number): \(strait.condition.name)"
            let goal = strait.goal.sentence
            if streak > 0 && offset <= 1 {
                content.body = "\(goal). Keep your \(streak)-day streak going."
            } else {
                content.body = "\(goal). \(strait.condition.line)"
            }
            content.sound = .default
            content.userInfo = ["route": "daily"]
            let parts = cal.dateComponents([.year, .month, .day, .hour, .minute], from: when)
            let req = UNNotificationRequest(identifier: "daily-\(offset)", content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
            center.add(req)
        }
    }
}
