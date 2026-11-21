import XCTest
@testable import MathBlitzCore

/// The bank the app downloads must decode exactly as written, and a record
/// written by an older build must still load.
final class LessonDecodingTests: XCTestCase {
    func testBankRoundTripsThroughJSON() throws {
        let lesson = Lesson(id: "day002", title: "Both Sides Brawl",
                            topic: "Equations with variables on both sides", topicIndex: 2,
                            satDomain: "Algebra", level: 4.7, boss: false,
                            video: "videos/day002.mp4", poster: "videos/day002.jpg",
                            question: Question(prompt: "5x + 9 = 2x − 12. What is x?",
                                               choices: ["7", "−1", "−7", "−3"], answer: 2,
                                               explain: "Subtract 2x, then 9."),
                            rapid: [RapidQuestion(prompt: "8x − 5 = 3x + 20. What is x?",
                                                  choices: ["5", "3", "25", "−5"], answer: 0,
                                                  why: "5x = 25")],
                            resources: [Resource(name: "Khan Academy", label: "Practice",
                                                 url: URL(string: "https://www.khanacademy.org/")!,
                                                 quest: true, button: "Open")])
        let bank = LessonBank(version: 1, lessons: [lesson])
        let data = try JSONEncoder().encode(bank)
        let back = try JSONDecoder().decode(LessonBank.self, from: data)
        XCTAssertEqual(bank, back)
        XCTAssertTrue(back.malformed.isEmpty)
    }

    func testDayRecordRoundTripsWithDates() throws {
        var record = DayRecord(lessonID: "day002", session: 2, boss: false,
                               watchedAt: Date(timeIntervalSince1970: 1_700_000_000),
                               watchedPercent: 90,
                               answeredAt: Date(timeIntervalSince1970: 1_700_000_014),
                               pick: 3, correct: false)
        record.rapid = [RapidAnswer(index: 0, pick: 1, correct: true)]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let back = try decoder.decode(DayRecord.self, from: encoder.encode(record))
        XCTAssertEqual(record, back)
    }

    func testNextRapidIndexWalksTheRound() {
        var record = DayRecord(lessonID: "d", session: 1)
        XCTAssertEqual(record.nextRapidIndex(total: 5), 0)
        record.rapid = [RapidAnswer(index: 0, pick: 0, correct: true)]
        XCTAssertEqual(record.nextRapidIndex(total: 5), 1)
        record.rapid += (1...4).map { RapidAnswer(index: $0, pick: 0, correct: true) }
        XCTAssertNil(record.nextRapidIndex(total: 5))
    }

    /// Out-of-order writes must not make the round look finished.
    func testNextRapidIndexFindsAGapRatherThanTheEnd() {
        var record = DayRecord(lessonID: "d", session: 1)
        record.rapid = [RapidAnswer(index: 0, pick: 0, correct: true),
                        RapidAnswer(index: 2, pick: 0, correct: true)]
        XCTAssertEqual(record.nextRapidIndex(total: 5), 1)
    }
}
