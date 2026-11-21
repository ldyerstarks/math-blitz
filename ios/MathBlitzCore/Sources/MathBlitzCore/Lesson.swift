import Foundation

/// One day's lesson: a short video, one challenge question, a Rapid Fire round
/// and a bonus practice link. Lessons are pre-built into a bank and shipped as
/// JSON; the app picks from the bank rather than generating anything at runtime.
public struct Lesson: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let topic: String
    /// Position in the curriculum (engine/curriculum.md), used for ordering.
    public let topicIndex: Int
    public let satDomain: String
    /// Difficulty this lesson was written for, on the 1...10 Math Level scale.
    public let level: Double
    public let boss: Bool
    /// Path relative to the content base URL, e.g. "videos/day002.mp4".
    public let video: String
    public let poster: String?
    public let question: Question
    public let rapid: [RapidQuestion]
    public let resources: [Resource]

    public init(id: String, title: String, topic: String, topicIndex: Int,
                satDomain: String, level: Double, boss: Bool = false,
                video: String, poster: String? = nil, question: Question,
                rapid: [RapidQuestion] = [], resources: [Resource] = []) {
        self.id = id
        self.title = title
        self.topic = topic
        self.topicIndex = topicIndex
        self.satDomain = satDomain
        self.level = level
        self.boss = boss
        self.video = video
        self.poster = poster
        self.question = question
        self.rapid = rapid
        self.resources = resources
    }
}

public struct Question: Codable, Equatable, Sendable {
    public let prompt: String
    public let choices: [String]
    public let answer: Int
    public let explain: String

    public init(prompt: String, choices: [String], answer: Int, explain: String) {
        self.prompt = prompt
        self.choices = choices
        self.answer = answer
        self.explain = explain
    }

    /// A lesson is only usable if exactly one choice can be correct.
    public var isWellFormed: Bool {
        choices.count == 4 && choices.indices.contains(answer)
            && Set(choices).count == choices.count
    }
}

public struct RapidQuestion: Codable, Equatable, Sendable {
    public let prompt: String
    public let choices: [String]
    public let answer: Int
    public let why: String

    public init(prompt: String, choices: [String], answer: Int, why: String) {
        self.prompt = prompt
        self.choices = choices
        self.answer = answer
        self.why = why
    }

    public var isWellFormed: Bool {
        choices.count == 4 && choices.indices.contains(answer)
            && Set(choices).count == choices.count
            && prompt.count <= 120
    }
}

public struct Resource: Codable, Equatable, Sendable {
    public let name: String
    public let label: String
    public let url: URL
    public let quest: Bool
    public let button: String?

    public init(name: String, label: String, url: URL, quest: Bool = false, button: String? = nil) {
        self.name = name
        self.label = label
        self.url = url
        self.quest = quest
        self.button = button
    }
}

/// The whole shipped lesson bank.
public struct LessonBank: Codable, Equatable, Sendable {
    public let version: Int
    public let lessons: [Lesson]

    public init(version: Int, lessons: [Lesson]) {
        self.version = version
        self.lessons = lessons
    }

    public func lesson(id: String) -> Lesson? {
        lessons.first { $0.id == id }
    }

    /// Lessons that fail their own sanity checks. Should always be empty;
    /// the app refuses to show one and CI fails the build if any appear.
    public var malformed: [Lesson] {
        lessons.filter { lesson in
            !lesson.question.isWellFormed || lesson.rapid.contains { !$0.isWellFormed }
        }
    }
}
