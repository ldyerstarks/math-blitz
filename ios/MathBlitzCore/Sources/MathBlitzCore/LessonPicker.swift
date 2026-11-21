import Foundation

/// Chooses the next lesson out of the pre-built bank.
///
/// The rules come from engine/curriculum.md:
///   * every 7th session is a Boss Battle over recent topics,
///   * a missed or skipped topic is replayed one notch easier before moving on,
///   * otherwise advance one topic and pick the variant closest to the kid's level.
public enum LessonPicker {
    public struct Choice: Equatable, Sendable {
        public let lesson: Lesson
        public let session: Int
        public let reason: Reason
    }

    public enum Reason: String, Equatable, Sendable {
        case firstLesson
        case bossBattle
        case instantReplay
        case nextTopic
        /// The curriculum ran out; revisit the weakest topic.
        case revision
    }

    public static func next(bank: LessonBank,
                            history: [DayRecord],
                            level: Double) -> Choice? {
        let usable = bank.lessons.filter { lesson in
            lesson.question.isWellFormed && !lesson.rapid.contains { !$0.isWellFormed }
        }
        guard !usable.isEmpty else { return nil }

        let ordered = history.sorted { $0.session < $1.session }
        let session = (ordered.last?.session ?? 0) + 1
        let seen = Set(ordered.map(\.lessonID))

        if ordered.isEmpty {
            let nonBoss = usable.filter { !$0.boss }
            var pool: [Lesson] = []
            if let firstIndex = nonBoss.map(\.topicIndex).min() {
                pool = nonBoss.filter { $0.topicIndex == firstIndex }
            }
            if let lesson = closest(to: level, in: pool) ?? closest(to: level, in: usable) {
                return Choice(lesson: lesson, session: session, reason: .firstLesson)
            }
            return nil
        }

        if session % 7 == 0 {
            let recent = Set(ordered.suffix(6).compactMap { record -> Int? in
                usable.first { $0.id == record.lessonID }?.topicIndex
            })
            let bosses = usable.filter { $0.boss && !seen.contains($0.id) }
            let onTopic = bosses.filter { boss in
                recent.isEmpty || boss.topicIndex <= (recent.max() ?? boss.topicIndex)
            }
            if let lesson = closest(to: level + 0.5, in: onTopic) ?? closest(to: level + 0.5, in: bosses) {
                return Choice(lesson: lesson, session: session, reason: .bossBattle)
            }
        }

        let last = ordered.last!
        let lastMissed = last.correct != true
        if lastMissed, let lastLesson = usable.first(where: { $0.id == last.lessonID }) {
            let replays = usable.filter {
                $0.topicIndex == lastLesson.topicIndex && !$0.boss && !seen.contains($0.id)
            }
            if let lesson = closest(to: max(1, level - 0.5), in: replays) {
                return Choice(lesson: lesson, session: session, reason: .instantReplay)
            }
        }

        let highestSeen = ordered.compactMap { record in
            usable.first { $0.id == record.lessonID }?.topicIndex
        }.max() ?? -1
        let ahead = usable.filter { $0.topicIndex > highestSeen && !$0.boss && !seen.contains($0.id) }
        if let nextIndex = ahead.map(\.topicIndex).min() {
            let pool = ahead.filter { $0.topicIndex == nextIndex }
            if let lesson = closest(to: level, in: pool) {
                return Choice(lesson: lesson, session: session, reason: .nextTopic)
            }
        }

        let unseen = usable.filter { !seen.contains($0.id) && !$0.boss }
        if let lesson = closest(to: level, in: unseen) {
            return Choice(lesson: lesson, session: session, reason: .revision)
        }
        return nil
    }

    static func closest(to level: Double, in pool: [Lesson]) -> Lesson? {
        pool.min { a, b in
            let da = abs(a.level - level), db = abs(b.level - level)
            return da == db ? a.id < b.id : da < db
        }
    }
}
