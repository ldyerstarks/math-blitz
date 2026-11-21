import Foundation
import MathBlitzCore
import SwiftUI

struct ParentSettings: Codable, Equatable {
    var kidName: String = ""
    /// Dad's difficulty dial, the same one as the Settings tab in the sheet.
    var levelAdjustment: Double = 0
    var paused: Bool = false
    var schoolGrade: Int = 8
    var remindersOn: Bool = true
    /// Four digits that keep the parent screen out of the kid's hands. Not security,
    /// just a speed bump, and deliberately not a password anyone reuses.
    var parentPIN: String = ""
}

struct SaveFile: Codable {
    var history: [DayRecord] = []
    var settings = ParentSettings()
    var bankVersion: Int = 0
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var bank: LessonBank?
    @Published private(set) var history: [DayRecord] = []
    @Published var settings = ParentSettings() { didSet { save() } }
    @Published private(set) var loadError: String?
    @Published private(set) var isRefreshing = false

    private let store: ContentStore
    private let saveURL: URL

    init(store: ContentStore = ContentStore()) {
        self.store = store
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MathBlitz", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.saveURL = base.appendingPathComponent("save.json")
        load()
    }

    // MARK: - Derived

    /// Always recomputed from history, so a bad write can't corrupt the scoreboard.
    var summary: Summary {
        Scoring.summarize(history: history,
                          levelAdjustment: settings.levelAdjustment,
                          schoolGrade: settings.schoolGrade)
    }

    /// The record the kid is working on, if today's run isn't finished.
    var activeRecord: DayRecord? {
        guard let last = history.last else { return nil }
        return isFinished(last) ? nil : last
    }

    var activeLesson: Lesson? {
        guard let record = activeRecord, let bank else { return nil }
        return bank.lesson(id: record.lessonID)
    }

    func isFinished(_ record: DayRecord) -> Bool {
        guard record.isAnswered else { return false }
        guard let bank, let lesson = bank.lesson(id: record.lessonID) else { return true }
        return record.nextRapidIndex(total: lesson.rapid.count) == nil
    }

    var finishedToday: Bool {
        guard let last = history.last, let answered = last.answeredAt else { return false }
        return Calendar.current.isDateInToday(answered) && isFinished(last)
    }

    // MARK: - Loading

    func start() async {
        if let cached = await store.cachedBank() { bank = cached }
        await refresh()
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let fresh = try await store.refreshBank()
            bank = fresh
            loadError = nil
            if let lesson = activeLesson { try? await store.download(lesson) }
            await prefetchNext()
        } catch {
            loadError = bank == nil ? error.localizedDescription : nil
        }
    }

    /// Pull tomorrow's video down on Wi-Fi so a car ride still works.
    private func prefetchNext() async {
        guard let bank else { return }
        var lookahead = history
        if let choice = LessonPicker.next(bank: bank, history: lookahead, level: summary.level) {
            try? await store.download(choice.lesson)
            lookahead.append(DayRecord(lessonID: choice.lesson.id, session: choice.session,
                                       answeredAt: Date(), pick: 0, correct: true))
        }
        let keep = Set(lookahead.suffix(6).map(\.lessonID).compactMap { id in bank.lesson(id: id)?.video })
        await store.pruneVideos(keeping: keep)
    }

    func videoURL(for lesson: Lesson) async -> URL {
        await store.videoURL(for: lesson)
    }

    // MARK: - Flow

    @discardableResult
    func beginNextLesson() -> Lesson? {
        if let lesson = activeLesson { return lesson }
        guard let bank,
              let choice = LessonPicker.next(bank: bank, history: history, level: summary.level)
        else { return nil }
        history.append(DayRecord(lessonID: choice.lesson.id,
                                 session: choice.session,
                                 boss: choice.lesson.boss))
        save()
        Task { await prefetchNext() }
        return choice.lesson
    }

    func markWatched(percent: Int) {
        updateActive { record in
            guard record.watchedAt == nil else { return }
            record.watchedAt = Date()
            record.watchedPercent = percent
        }
    }

    func answer(pick: Int, correct: Bool) {
        updateActive { record in
            guard record.pick == nil else { return }
            record.pick = pick
            record.correct = correct
            record.answeredAt = Date()
        }
    }

    func answerRapid(index: Int, pick: Int, correct: Bool) {
        updateActive { record in
            guard record.rapidAnswer(at: index) == nil else { return }
            record.rapid.append(RapidAnswer(index: index, pick: pick, correct: correct))
        }
    }

    func claimBonus() {
        updateActive { record in
            guard record.bonusAt == nil else { return }
            record.bonusAt = Date()
        }
    }

    private func updateActive(_ change: (inout DayRecord) -> Void) {
        guard var record = history.last else { return }
        change(&record)
        history[history.count - 1] = record
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: saveURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let file = try? decoder.decode(SaveFile.self, from: data) else { return }
        history = file.history
        settings = file.settings
    }

    func save() {
        let file = SaveFile(history: history, settings: settings, bankVersion: bank?.version ?? 0)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(file) else { return }
        try? data.write(to: saveURL, options: .atomic)
    }

    /// Parent screen: wipe everything on the device. Nothing lives anywhere else.
    func eraseEverything() async {
        history = []
        settings = ParentSettings()
        await store.clearVideos()
        try? FileManager.default.removeItem(at: saveURL)
    }

    func cacheSizeMB() async -> Double {
        Double(await store.cacheSizeBytes()) / 1_048_576
    }
}
