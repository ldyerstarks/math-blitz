import Foundation
import MathBlitzCore
import UserNotifications

/// A local daily nudge. No server, no push token, nothing leaves the phone.
enum Reminders {
    static let identifierPrefix = "mathblitz.daily."

    static func requestPermission() async -> Bool {
        let centre = UNUserNotificationCenter.current()
        return (try? await centre.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Schedules the next 14 days: weekdays at 7am, weekends at 10am.
    static func reschedule(enabled: Bool, calendar: Calendar = .current, from now: Date = Date()) async {
        let centre = UNUserNotificationCenter.current()
        let existing = await centre.pendingNotificationRequests()
            .map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        centre.removePendingNotificationRequests(withIdentifiers: existing)
        guard enabled else { return }

        var cursor = now
        for i in 0..<14 {
            guard let fire = ReminderSchedule.nextFireDate(after: cursor, calendar: calendar) else { break }
            let content = UNMutableNotificationContent()
            content.title = "Math Blitz is ready 🏀"
            content.body = "Today's Blitz takes about two minutes. Keep the streak alive!"
            content.sound = .default
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            let request = UNNotificationRequest(identifier: "\(identifierPrefix)\(i)",
                                                content: content, trigger: trigger)
            try? await centre.add(request)
            cursor = fire.addingTimeInterval(60)
        }
    }
}
