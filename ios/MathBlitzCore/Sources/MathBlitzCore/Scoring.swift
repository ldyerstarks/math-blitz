import Foundation

/// The numbers behind XP and the Math Level. These match the web version's
/// Apps Script scoreboard so a kid moving from the web page to the app sees
/// the same difficulty, with one deliberate exception noted on `Summary.streak`.
public struct ScoreRules: Equatable, Sendable {
    public var startLevel: Double = 3.0
    public var minLevel: Double = 1.0
    public var maxLevel: Double = 10.0
    /// Seconds after finishing the video in which an answer earns the speed bonus.
    public var speedWindow: TimeInterval = 90

    public var xpWatch = 10
    public var xpCorrect = 25
    public var xpSpeed = 10
    public var xpStreakPer = 5
    public var xpStreakCap = 50
    public var xpBonus = 30
    public var xpRapid = 10

    public var levelQuickRight = 0.18
    public var levelRight = 0.12
    public var levelWrong = -0.30
    public var levelRapidRight = 0.05
    public var levelRapidWrong = -0.08

    public init() {}

    public func clamp(_ level: Double) -> Double {
        Swift.min(maxLevel, Swift.max(minLevel, level))
    }
}

public struct Rank: Equatable, Sendable {
    public let threshold: Int
    public let name: String
    public let icon: String

    public init(threshold: Int, name: String, icon: String) {
        self.threshold = threshold
        self.name = name
        self.icon = icon
    }

    public static let all: [Rank] = [
        Rank(threshold: 0, name: "Rookie", icon: "🥉"),
        Rank(threshold: 250, name: "Starter", icon: "🥈"),
        Rank(threshold: 750, name: "All-Star", icon: "🥇"),
        Rank(threshold: 1500, name: "MVP", icon: "🏆"),
        Rank(threshold: 3000, name: "Legend", icon: "👑"),
        Rank(threshold: 5000, name: "Hall of Fame", icon: "💎")
    ]

    public static func current(xp: Int) -> (rank: Rank, next: Rank?) {
        var rank = all[0]
        var next: Rank? = all.count > 1 ? all[1] : nil
        for (i, r) in all.enumerated() where xp >= r.threshold {
            rank = r
            next = i + 1 < all.count ? all[i + 1] : nil
        }
        return (rank, next)
    }
}

/// What the kid sees on the stats screen. Always derived, never stored.
public struct Summary: Equatable, Sendable {
    public let xp: Int
    /// Math Level after Dad's adjustment, clamped to 1...10.
    public let level: Double
    /// Math Level from answers alone, before Dad's adjustment.
    public let baseLevel: Double
    public let levelName: String
    /// Approximate school grade for the level. A rough in-app scale, not a test score.
    public let gradeEquivalent: Double
    public let schoolGrade: Int
    /// Consecutive calendar days with an answer, counting back from today or
    /// yesterday. The web version counts consecutive lesson numbers instead;
    /// the app uses calendar days because that is what "🔥 5 day streak" means
    /// to a kid. Level and XP rules are otherwise identical.
    public let streak: Int
    public let bestStreak: Int
    public let wins: Int
    public let answered: Int
    public let rapidAnswered: Int
    public let rapidWins: Int
    public let badges: [String]
    public let rank: Rank
    public let nextRank: Rank?
    /// Level after each answered session, oldest first, for the progress chart.
    public let levelHistory: [LevelPoint]

    public var xpToNextRank: Int? {
        guard let next = nextRank else { return nil }
        return Swift.max(0, next.threshold - xp)
    }

    public var rankProgress: Double {
        guard let next = nextRank else { return 1 }
        let span = Double(next.threshold - rank.threshold)
        guard span > 0 else { return 1 }
        return Swift.min(1, Swift.max(0, Double(xp - rank.threshold) / span))
    }
}

public struct LevelPoint: Equatable, Sendable {
    public let session: Int
    public let date: Date
    public let level: Double
    public let gradeEquivalent: Double
}

public enum Scoring {
    /// Math Level 1...10 as an approximate school grade: 1 ≈ 6th, 10 ≈ 12th.
    public static func gradeEquivalent(forLevel level: Double) -> Double {
        ((6 + (level - 1) * 6 / 9) * 10).rounded() / 10
    }

    public static func levelName(_ level: Double) -> String {
        switch level {
        case ..<3: return "Warm-up"
        case ..<5: return "Algebra 1"
        case ..<6.5: return "SAT Foundations"
        case ..<8: return "SAT Medium"
        case ..<9.5: return "SAT Hard"
        default: return "1600 Mode"
        }
    }

    static func round1(_ value: Double) -> Double { (value * 10).rounded() / 10 }

    /// Consecutive calendar days ending today or yesterday.
    public static func calendarStreak(days: Set<Date>, calendar: Calendar, now: Date) -> Int {
        guard !days.isEmpty else { return 0 }
        let today = calendar.startOfDay(for: now)
        var cursor = today
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  days.contains(yesterday) else { return 0 }
            cursor = yesterday
        }
        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    /// Rebuild the whole scoreboard from the session history.
    public static func summarize(history: [DayRecord],
                                 rules: ScoreRules = ScoreRules(),
                                 levelAdjustment: Double = 0,
                                 schoolGrade: Int = 8,
                                 calendar: Calendar = Calendar(identifier: .gregorian),
                                 now: Date = Date()) -> Summary {
        let ordered = history.sorted { $0.session < $1.session }
        var level = rules.startLevel
        var xp = 0
        var wins = 0, answered = 0, rapidWins = 0, rapidAnswered = 0
        var bosses = 0, bonuses = 0, bestWinRun = 0, winRun = 0
        var sawSpeedy = false
        var points: [LevelPoint] = []
        var answeredDays: Set<Date> = []
        var runningStreak = 0
        var bestStreak = 0
        var previousDay: Date?

        for record in ordered {
            let multiplier = record.boss ? 2 : 1
            var gained = 0
            if record.watchedAt != nil { gained += rules.xpWatch }

            if record.isAnswered {
                let correct = record.correct ?? false
                let quick = record.wasQuick(window: rules.speedWindow)
                level = rules.clamp(level + (correct ? (quick ? rules.levelQuickRight : rules.levelRight) : rules.levelWrong))
                answered += 1

                let day = calendar.startOfDay(for: record.answeredAt ?? now)
                answeredDays.insert(day)
                if let previous = previousDay {
                    if calendar.isDate(day, inSameDayAs: previous) {
                        // Two lessons the same day do not extend the streak.
                    } else if let next = calendar.date(byAdding: .day, value: 1, to: previous),
                              calendar.isDate(day, inSameDayAs: next) {
                        runningStreak += 1
                    } else {
                        runningStreak = 1
                    }
                } else {
                    runningStreak = 1
                }
                previousDay = day
                bestStreak = Swift.max(bestStreak, runningStreak)

                if correct {
                    wins += 1
                    winRun += 1
                    bestWinRun = Swift.max(bestWinRun, winRun)
                    gained += rules.xpCorrect
                    if quick {
                        gained += rules.xpSpeed
                        sawSpeedy = true
                    }
                    if record.boss { bosses += 1 }
                } else {
                    winRun = 0
                }
                gained += Swift.min(rules.xpStreakPer * (runningStreak - 1), rules.xpStreakCap)
            }

            if record.bonusAt != nil {
                gained += rules.xpBonus
                bonuses += 1
            }

            if !record.rapid.isEmpty {
                for answer in record.rapid.sorted(by: { $0.index < $1.index }) {
                    rapidAnswered += 1
                    if answer.correct {
                        rapidWins += 1
                        gained += rules.xpRapid
                        level += rules.levelRapidRight
                    } else {
                        level += rules.levelRapidWrong
                    }
                }
                level = rules.clamp(level)
            }

            xp += gained * multiplier

            if record.isAnswered || !record.rapid.isEmpty {
                let adjusted = rules.clamp(level + levelAdjustment)
                points.append(LevelPoint(session: record.session,
                                         date: record.answeredAt ?? record.watchedAt ?? now,
                                         level: round1(adjusted),
                                         gradeEquivalent: gradeEquivalent(forLevel: adjusted)))
            }
        }

        let baseLevel = round1(level)
        let adjusted = round1(rules.clamp(level + levelAdjustment))
        var badges: [String] = []
        let streak = calendarStreak(days: answeredDays, calendar: calendar, now: now)
        if wins >= 1 { badges.append("🎯 First Win") }
        if bestStreak >= 3 { badges.append("🔥 3-Day Streak") }
        if bestStreak >= 7 { badges.append("🔥 7-Day Streak") }
        if bestStreak >= 30 { badges.append("☄️ 30-Day Streak") }
        if bestWinRun >= 5 { badges.append("🎳 5 in a Row") }
        if bosses >= 1 { badges.append("⚔️ Boss Slayer") }
        if bosses >= 5 { badges.append("🐉 Boss Hunter") }
        if bonuses >= 5 { badges.append("⭐ Bonus Hunter") }
        if sawSpeedy { badges.append("⚡ Speed Demon") }

        let (rank, next) = Rank.current(xp: xp)
        return Summary(xp: xp,
                       level: adjusted,
                       baseLevel: baseLevel,
                       levelName: levelName(adjusted),
                       gradeEquivalent: gradeEquivalent(forLevel: adjusted),
                       schoolGrade: schoolGrade,
                       streak: streak,
                       bestStreak: bestStreak,
                       wins: wins,
                       answered: answered,
                       rapidAnswered: rapidAnswered,
                       rapidWins: rapidWins,
                       badges: badges,
                       rank: rank,
                       nextRank: next,
                       levelHistory: points)
    }
}
