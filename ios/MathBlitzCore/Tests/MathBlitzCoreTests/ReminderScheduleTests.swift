import XCTest
@testable import MathBlitzCore

final class ReminderScheduleTests: XCTestCase {
    var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }

    func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = h; c.minute = min
        return cal.date(from: c)!
    }

    func testWeekdaysAreSevenAndWeekendsAreTen() {
        XCTAssertEqual(ReminderSchedule.hour(for: at(2026, 11, 20, 12), calendar: cal), 7, "Friday")
        XCTAssertEqual(ReminderSchedule.hour(for: at(2026, 11, 21, 12), calendar: cal), 10, "Saturday")
        XCTAssertEqual(ReminderSchedule.hour(for: at(2026, 11, 22, 12), calendar: cal), 10, "Sunday")
        XCTAssertEqual(ReminderSchedule.hour(for: at(2026, 11, 23, 12), calendar: cal), 7, "Monday")
    }

    func testNextFireIsLaterTodayWhenTheHourHasNotPassed() {
        let next = ReminderSchedule.nextFireDate(after: at(2026, 11, 23, 5), calendar: cal)
        XCTAssertEqual(next, at(2026, 11, 23, 7))
    }

    func testNextFireRollsToTomorrowOnceTodaysHourHasPassed() {
        let next = ReminderSchedule.nextFireDate(after: at(2026, 11, 23, 9), calendar: cal)
        XCTAssertEqual(next, at(2026, 11, 24, 7))
    }

    func testFridayEveningRollsToSaturdayAtTen() {
        let next = ReminderSchedule.nextFireDate(after: at(2026, 11, 20, 21), calendar: cal)
        XCTAssertEqual(next, at(2026, 11, 21, 10))
    }

    func testSundayEveningRollsToMondayAtSeven() {
        let next = ReminderSchedule.nextFireDate(after: at(2026, 11, 22, 21), calendar: cal)
        XCTAssertEqual(next, at(2026, 11, 23, 7))
    }
}
