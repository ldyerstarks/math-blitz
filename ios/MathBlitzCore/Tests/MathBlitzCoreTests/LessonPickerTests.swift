import XCTest
@testable import MathBlitzCore

final class LessonPickerTests: XCTestCase {
    func q(_ answer: Int = 0) -> Question {
        Question(prompt: "p", choices: ["1", "2", "3", "4"], answer: answer, explain: "because")
    }

    func lesson(_ id: String, topic: Int, level: Double, boss: Bool = false) -> Lesson {
        Lesson(id: id, title: id, topic: "t\(topic)", topicIndex: topic,
               satDomain: "Algebra", level: level, boss: boss,
               video: "videos/\(id).mp4", question: q())
    }

    var bank: LessonBank {
        LessonBank(version: 1, lessons: [
            lesson("t1-easy", topic: 1, level: 3.0),
            lesson("t1-mid", topic: 1, level: 4.5),
            lesson("t1-hard", topic: 1, level: 6.0),
            lesson("t2-easy", topic: 2, level: 3.0),
            lesson("t2-mid", topic: 2, level: 4.5),
            lesson("t3-mid", topic: 3, level: 4.5),
            lesson("boss-a", topic: 3, level: 5.0, boss: true)
        ])
    }

    func answered(_ id: String, session: Int, correct: Bool) -> DayRecord {
        DayRecord(lessonID: id, session: session, watchedAt: Date(),
                  answeredAt: Date(), pick: 0, correct: correct)
    }

    func testFirstLessonComesFromTheFirstTopicAtTheRightLevel() {
        let choice = LessonPicker.next(bank: bank, history: [], level: 4.5)
        XCTAssertEqual(choice?.lesson.id, "t1-mid")
        XCTAssertEqual(choice?.session, 1)
        XCTAssertEqual(choice?.reason, .firstLesson)
    }

    func testARightAnswerMovesToTheNextTopic() {
        let history = [answered("t1-mid", session: 1, correct: true)]
        let choice = LessonPicker.next(bank: bank, history: history, level: 4.5)
        XCTAssertEqual(choice?.lesson.topicIndex, 2)
        XCTAssertEqual(choice?.reason, .nextTopic)
        XCTAssertEqual(choice?.session, 2)
    }

    func testAMissReplaysTheSameTopicOneNotchEasier() {
        let history = [answered("t1-mid", session: 1, correct: false)]
        let choice = LessonPicker.next(bank: bank, history: history, level: 4.5)
        XCTAssertEqual(choice?.reason, .instantReplay)
        XCTAssertEqual(choice?.lesson.topicIndex, 1)
        XCTAssertEqual(choice?.lesson.id, "t1-easy", "should pick the 4.0-ish variant, not the 6.0 one")
    }

    func testASkippedLessonIsTreatedLikeAMiss() {
        let skipped = DayRecord(lessonID: "t1-mid", session: 1, watchedAt: Date())
        let choice = LessonPicker.next(bank: bank, history: [skipped], level: 4.5)
        XCTAssertEqual(choice?.reason, .instantReplay)
    }

    func testEverySeventhSessionIsABossBattle() {
        var history: [DayRecord] = []
        for i in 1...6 { history.append(answered("x\(i)", session: i, correct: true)) }
        let choice = LessonPicker.next(bank: bank, history: history, level: 4.5)
        XCTAssertEqual(choice?.session, 7)
        XCTAssertEqual(choice?.reason, .bossBattle)
        XCTAssertEqual(choice?.lesson.boss, true)
    }

    func testTheSameLessonIsNeverServedTwice() {
        var history: [DayRecord] = []
        var seen = Set<String>()
        var level = 4.0
        for _ in 1...6 {
            guard let choice = LessonPicker.next(bank: bank, history: history, level: level) else { break }
            XCTAssertFalse(seen.contains(choice.lesson.id), "served \(choice.lesson.id) twice")
            seen.insert(choice.lesson.id)
            history.append(answered(choice.lesson.id, session: choice.session, correct: true))
            level += 0.18
        }
        XCTAssertGreaterThanOrEqual(seen.count, 5)
    }

    func testRunningOutOfBankReturnsNilRatherThanRepeating() {
        var history: [DayRecord] = []
        for (i, l) in bank.lessons.enumerated() {
            history.append(answered(l.id, session: i + 1, correct: true))
        }
        XCTAssertNil(LessonPicker.next(bank: bank, history: history, level: 5))
    }

    func testMalformedLessonsAreNeverServed() {
        let bad = Lesson(id: "bad", title: "bad", topic: "t0", topicIndex: 0,
                         satDomain: "Algebra", level: 4.5, video: "v.mp4",
                         question: Question(prompt: "p", choices: ["1", "1", "2", "3"],
                                            answer: 0, explain: "duplicate choices"))
        let withBad = LessonBank(version: 1, lessons: [bad] + bank.lessons)
        XCTAssertEqual(withBad.malformed.map(\.id), ["bad"])
        let choice = LessonPicker.next(bank: withBad, history: [], level: 4.5)
        XCTAssertNotEqual(choice?.lesson.id, "bad")
    }

    func testEmptyBankIsHandled() {
        XCTAssertNil(LessonPicker.next(bank: LessonBank(version: 1, lessons: []), history: [], level: 4))
    }
}
