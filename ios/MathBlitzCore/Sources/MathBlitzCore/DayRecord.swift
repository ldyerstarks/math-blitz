import Foundation

/// Everything that happened in one session, in the order a kid does it:
/// watch the video, answer the question, run Rapid Fire, claim the bonus.
/// The scoreboard is always recomputed from these records, never stored, so
/// a bad write can't permanently corrupt someone's XP.
public struct DayRecord: Codable, Equatable, Identifiable, Sendable {
    public var lessonID: String
    /// 1-based session number: the first lesson a kid does is 1.
    public var session: Int
    public var boss: Bool
    public var watchedAt: Date?
    public var watchedPercent: Int?
    public var answeredAt: Date?
    public var pick: Int?
    public var correct: Bool?
    public var bonusAt: Date?
    public var rapid: [RapidAnswer]

    public var id: String { lessonID }

    public init(lessonID: String, session: Int, boss: Bool = false,
                watchedAt: Date? = nil, watchedPercent: Int? = nil,
                answeredAt: Date? = nil, pick: Int? = nil, correct: Bool? = nil,
                bonusAt: Date? = nil, rapid: [RapidAnswer] = []) {
        self.lessonID = lessonID
        self.session = session
        self.boss = boss
        self.watchedAt = watchedAt
        self.watchedPercent = watchedPercent
        self.answeredAt = answeredAt
        self.pick = pick
        self.correct = correct
        self.bonusAt = bonusAt
        self.rapid = rapid
    }

    /// True once the challenge question has been answered either way.
    public var isAnswered: Bool { pick != nil }

    /// Answered inside the speed-bonus window after finishing the video.
    public func wasQuick(window: TimeInterval) -> Bool {
        guard let w = watchedAt, let a = answeredAt else { return false }
        return a.timeIntervalSince(w) <= window && a >= w
    }

    public func rapidAnswer(at index: Int) -> RapidAnswer? {
        rapid.first { $0.index == index }
    }

    /// Index of the next unanswered Rapid Fire question, or nil when the round is done.
    public func nextRapidIndex(total: Int) -> Int? {
        (0..<total).first { rapidAnswer(at: $0) == nil }
    }
}

public struct RapidAnswer: Codable, Equatable, Sendable {
    public let index: Int
    public let pick: Int
    public let correct: Bool

    public init(index: Int, pick: Int, correct: Bool) {
        self.index = index
        self.pick = pick
        self.correct = correct
    }
}
