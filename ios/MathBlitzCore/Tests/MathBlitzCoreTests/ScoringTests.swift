import XCTest
@testable import MathBlitzCore

final class ScoringTests: XCTestCase {
    let cal = Calendar(identifier: .gregorian)

    func day(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9, _ min: Int = 0) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = h; c.minute = min
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: c)!
    }

    var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    func testEmptyHistoryStartsAtLevelThree() {
        let s = Scoring.summarize(history: [], calendar: utc, now: day(2026, 11, 21))
        XCTAssertEqual(s.xp, 0)
        XCTAssertEqual(s.level, 3.0, accuracy: 0.001)
        XCTAssertEqual(s.levelName, "Algebra 1")
        XCTAssertEqual(s.streak, 0)
        XCTAssertEqual(s.rank.name, "Rookie")
        XCTAssertEqual(s.nextRank?.name, "Starter")
        XCTAssertTrue(s.badges.isEmpty)
    }

    /// Watch 10 + correct 25 + speed 10 = 45, and the level climbs 0.18.
    func testQuickCorrectAnswer() {
        let watched = day(2026, 11, 21, 9, 0)
        let record = DayRecord(lessonID: "d1", session: 1,
                               watchedAt: watched, watchedPercent: 100,
                               answeredAt: watched.addingTimeInterval(6), pick: 1, correct: true)
        let s = Scoring.summarize(history: [record], calendar: utc, now: day(2026, 11, 21, 12))
        XCTAssertEqual(s.xp, 45)
        XCTAssertEqual(s.level, 3.2, accuracy: 0.001)
        XCTAssertEqual(s.wins, 1)
        XCTAssertEqual(s.answered, 1)
        XCTAssertEqual(s.streak, 1)
        XCTAssertTrue(s.badges.contains("⚡ Speed Demon"))
        XCTAssertTrue(s.badges.contains("🎯 First Win"))
    }

    /// Past the 90-second window the speed bonus is gone and the level climbs less.
    func testSlowCorrectAnswerLosesSpeedBonus() {
        let watched = day(2026, 11, 21, 9, 0)
        let record = DayRecord(lessonID: "d1", session: 1,
                               watchedAt: watched,
                               answeredAt: watched.addingTimeInterval(120), pick: 1, correct: true)
        let s = Scoring.summarize(history: [record], calendar: utc, now: day(2026, 11, 21, 12))
        XCTAssertEqual(s.xp, 35)
        XCTAssertEqual(s.baseLevel, 3.1, accuracy: 0.001, "3.12 shown to one decimal")
        XCTAssertEqual(s.level, 3.1, accuracy: 0.001)
        XCTAssertFalse(s.badges.contains("⚡ Speed Demon"))
    }

    func testWrongAnswerDropsLevelFasterThanARightOneRaisesIt() {
        let watched = day(2026, 11, 21, 9, 0)
        let record = DayRecord(lessonID: "d1", session: 1,
                               watchedAt: watched,
                               answeredAt: watched.addingTimeInterval(10), pick: 3, correct: false)
        let s = Scoring.summarize(history: [record], calendar: utc, now: day(2026, 11, 21, 12))
        XCTAssertEqual(s.xp, 10, "only the watch XP")
        XCTAssertEqual(s.level, 2.7, accuracy: 0.001)
        XCTAssertEqual(s.wins, 0)
        XCTAssertEqual(s.answered, 1)
    }

    func testLevelNeverLeavesOneToTen() {
        var history: [DayRecord] = []
        for i in 1...60 {
            let d = day(2026, 1, 1, 9).addingTimeInterval(Double(i) * 86_400)
            history.append(DayRecord(lessonID: "d\(i)", session: i, watchedAt: d,
                                     answeredAt: d.addingTimeInterval(5), pick: 0, correct: false))
        }
        let low = Scoring.summarize(history: history, calendar: utc, now: day(2026, 6, 1))
        XCTAssertEqual(low.level, 1.0, accuracy: 0.001)

        var up: [DayRecord] = []
        for i in 1...120 {
            let d = day(2026, 1, 1, 9).addingTimeInterval(Double(i) * 86_400)
            up.append(DayRecord(lessonID: "u\(i)", session: i, watchedAt: d,
                                answeredAt: d.addingTimeInterval(5), pick: 0, correct: true))
        }
        let high = Scoring.summarize(history: up, calendar: utc, now: day(2026, 12, 1))
        XCTAssertEqual(high.level, 10.0, accuracy: 0.001)
        XCTAssertEqual(high.levelName, "1600 Mode")
    }

    func testBossDayDoublesTheDaysXP() {
        let watched = day(2026, 11, 21, 9, 0)
        let plain = DayRecord(lessonID: "a", session: 1, boss: false, watchedAt: watched,
                              answeredAt: watched.addingTimeInterval(5), pick: 0, correct: true)
        let boss = DayRecord(lessonID: "b", session: 1, boss: true, watchedAt: watched,
                             answeredAt: watched.addingTimeInterval(5), pick: 0, correct: true)
        let a = Scoring.summarize(history: [plain], calendar: utc, now: day(2026, 11, 21, 12))
        let b = Scoring.summarize(history: [boss], calendar: utc, now: day(2026, 11, 21, 12))
        XCTAssertEqual(b.xp, a.xp * 2)
        XCTAssertTrue(b.badges.contains("⚔️ Boss Slayer"))
    }

    func testRapidFireNudgesTheLevelAndPaysTenEach() {
        let watched = day(2026, 11, 21, 9, 0)
        var record = DayRecord(lessonID: "d1", session: 1, watchedAt: watched,
                               answeredAt: watched.addingTimeInterval(5), pick: 0, correct: true)
        record.rapid = [
            RapidAnswer(index: 0, pick: 0, correct: true),
            RapidAnswer(index: 1, pick: 1, correct: true),
            RapidAnswer(index: 2, pick: 1, correct: false),
            RapidAnswer(index: 3, pick: 1, correct: true),
            RapidAnswer(index: 4, pick: 2, correct: true)
        ]
        let s = Scoring.summarize(history: [record], calendar: utc, now: day(2026, 11, 21, 12))
        XCTAssertEqual(s.rapidWins, 4)
        XCTAssertEqual(s.rapidAnswered, 5)
        XCTAssertEqual(s.xp, 45 + 40)
        // 3.0 + 0.18 + four rights at 0.05 and one wrong at -0.08
        XCTAssertEqual(s.level, 3.3, accuracy: 0.001)
    }

    func testStreakCountsCalendarDaysAndStopsWhenADayIsMissed() {
        var history: [DayRecord] = []
        for (i, d) in [19, 20, 21].enumerated() {
            let date = day(2026, 11, d, 9)
            history.append(DayRecord(lessonID: "d\(d)", session: i + 1, watchedAt: date,
                                     answeredAt: date.addingTimeInterval(5), pick: 0, correct: true))
        }
        let s = Scoring.summarize(history: history, calendar: utc, now: day(2026, 11, 21, 20))
        XCTAssertEqual(s.streak, 3)
        XCTAssertEqual(s.bestStreak, 3)

        // Same history seen three days later: the run is broken, best is kept.
        let later = Scoring.summarize(history: history, calendar: utc, now: day(2026, 11, 24, 20))
        XCTAssertEqual(later.streak, 0)
        XCTAssertEqual(later.bestStreak, 3)
    }

    func testStreakStillCountsWhenYesterdayWasTheLastAnswer() {
        let date = day(2026, 11, 20, 9)
        let record = DayRecord(lessonID: "d1", session: 1, watchedAt: date,
                               answeredAt: date.addingTimeInterval(5), pick: 0, correct: true)
        let s = Scoring.summarize(history: [record], calendar: utc, now: day(2026, 11, 21, 8))
        XCTAssertEqual(s.streak, 1)
    }

    func testTwoLessonsInOneDayDoNotInflateTheStreak() {
        let date = day(2026, 11, 21, 9)
        let a = DayRecord(lessonID: "a", session: 1, watchedAt: date,
                          answeredAt: date.addingTimeInterval(5), pick: 0, correct: true)
        let b = DayRecord(lessonID: "b", session: 2, watchedAt: date.addingTimeInterval(3600),
                          answeredAt: date.addingTimeInterval(3605), pick: 0, correct: true)
        let s = Scoring.summarize(history: [a, b], calendar: utc, now: day(2026, 11, 21, 20))
        XCTAssertEqual(s.streak, 1)
        XCTAssertEqual(s.bestStreak, 1)
    }

    func testStreakBonusIsCappedAtFifty() {
        var history: [DayRecord] = []
        for i in 1...20 {
            let date = day(2026, 11, 1, 9).addingTimeInterval(Double(i - 1) * 86_400)
            history.append(DayRecord(lessonID: "d\(i)", session: i, watchedAt: date,
                                     answeredAt: date.addingTimeInterval(5), pick: 0, correct: true))
        }
        let s = Scoring.summarize(history: history, calendar: utc, now: day(2026, 11, 20, 20))
        // Each day: 10 watch + 25 correct + 10 speed + capped streak bonus.
        let capped = history.indices.map { Swift.min(5 * $0, 50) }.reduce(0, +)
        XCTAssertEqual(s.xp, 20 * 45 + capped)
        XCTAssertEqual(s.streak, 20)
    }

    func testDadsAdjustmentShiftsTheShownLevelButNotTheBase() {
        let date = day(2026, 11, 21, 9)
        let record = DayRecord(lessonID: "d1", session: 1, watchedAt: date,
                               answeredAt: date.addingTimeInterval(5), pick: 0, correct: true)
        let s = Scoring.summarize(history: [record], levelAdjustment: 1.5,
                                  calendar: utc, now: day(2026, 11, 21, 12))
        XCTAssertEqual(s.baseLevel, 3.2, accuracy: 0.001)
        XCTAssertEqual(s.level, 4.7, accuracy: 0.001)
    }

    func testGradeEquivalentMatchesTheWebFormula() {
        XCTAssertEqual(Scoring.gradeEquivalent(forLevel: 1), 6.0, accuracy: 0.001)
        XCTAssertEqual(Scoring.gradeEquivalent(forLevel: 10), 12.0, accuracy: 0.001)
        XCTAssertEqual(Scoring.gradeEquivalent(forLevel: 4.7), 8.5, accuracy: 0.001)
        XCTAssertEqual(Scoring.gradeEquivalent(forLevel: 4.5), 8.3, accuracy: 0.001)
    }

    func testRankThresholds() {
        XCTAssertEqual(Rank.current(xp: 0).rank.name, "Rookie")
        XCTAssertEqual(Rank.current(xp: 249).rank.name, "Rookie")
        XCTAssertEqual(Rank.current(xp: 250).rank.name, "Starter")
        XCTAssertEqual(Rank.current(xp: 5000).rank.name, "Hall of Fame")
        XCTAssertNil(Rank.current(xp: 5000).next)
    }

    func testRankProgressAndXPToNext() {
        let date = day(2026, 11, 21, 9)
        let record = DayRecord(lessonID: "d1", session: 1, watchedAt: date,
                               answeredAt: date.addingTimeInterval(5), pick: 0, correct: true)
        let s = Scoring.summarize(history: [record], calendar: utc, now: day(2026, 11, 21, 12))
        XCTAssertEqual(s.xpToNextRank, 205)
        XCTAssertEqual(s.rankProgress, 45.0 / 250.0, accuracy: 0.001)
    }

    /// Jack's real first two days, so the app agrees with the web scoreboard.
    func testJacksFirstTwoDays() {
        let d1Watched = day(2026, 11, 20, 19, 15)
        var d1 = DayRecord(lessonID: "day001", session: 1, watchedAt: d1Watched, watchedPercent: 90,
                           answeredAt: d1Watched.addingTimeInterval(6), pick: 1, correct: true,
                           bonusAt: d1Watched.addingTimeInterval(27))
        d1.rapid = [
            RapidAnswer(index: 0, pick: 0, correct: true),
            RapidAnswer(index: 1, pick: 1, correct: true),
            RapidAnswer(index: 2, pick: 1, correct: false),
            RapidAnswer(index: 3, pick: 1, correct: true),
            RapidAnswer(index: 4, pick: 2, correct: true)
        ]
        let d2Watched = day(2026, 11, 21, 10, 33)
        let d2 = DayRecord(lessonID: "day002", session: 2, watchedAt: d2Watched, watchedPercent: 90,
                           answeredAt: d2Watched.addingTimeInterval(14), pick: 3, correct: false)

        let s = Scoring.summarize(history: [d1, d2], levelAdjustment: 1.5,
                                  calendar: utc, now: day(2026, 11, 21, 20))
        XCTAssertEqual(s.wins, 1)
        XCTAssertEqual(s.answered, 2)
        XCTAssertEqual(s.rapidWins, 4)
        XCTAssertEqual(s.streak, 2)
        // 3.0 +0.18 right, +0.12 net from Rapid Fire, −0.30 for the Day 2 miss.
        XCTAssertEqual(s.baseLevel, 3.0, accuracy: 0.001)
        XCTAssertEqual(s.level, 4.5, accuracy: 0.001)
        XCTAssertEqual(s.gradeEquivalent, 8.3, accuracy: 0.001)
        // Day 1: 10+25+10+30 bonus+40 rapid = 115. Day 2: 10 watch + 5 streak = 15.
        XCTAssertEqual(s.xp, 130)
    }
}
