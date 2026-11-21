import Foundation

/// When the daily nudge fires: 7:00 am on weekdays, 10:00 am at weekends.
/// Delivered as a local notification, so no server and no push token is needed.
public enum ReminderSchedule {
    public static let weekdayHour = 7
    public static let weekendHour = 10

    public static func hour(for date: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7
        return isWeekend ? weekendHour : weekdayHour
    }

    /// The next time the reminder should fire after `now`.
    public static func nextFireDate(after now: Date,
                                    calendar: Calendar = Calendar(identifier: .gregorian)) -> Date? {
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            var parts = calendar.dateComponents([.year, .month, .day], from: day)
            parts.hour = hour(for: day, calendar: calendar)
            parts.minute = 0
            if let candidate = calendar.date(from: parts), candidate > now { return candidate }
        }
        return nil
    }
}
