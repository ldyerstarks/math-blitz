import SwiftUI
import MathBlitzCore

/// The four-step run through one lesson. Mirrors the web page so moving
/// between them feels the same: Watch → Answer → Rapid Fire → Bonus.
struct FlowView: View {
    let lesson: Lesson
    @EnvironmentObject private var state: AppState
    @State private var step: Step = .watch
    @State private var toast: String?
    @State private var celebrate = false

    private var record: DayRecord? { state.activeRecord }

    private func isDone(_ step: Step) -> Bool {
        guard let record else { return false }
        switch step {
        case .watch: return record.watchedAt != nil
        case .answer: return record.isAnswered
        case .rapid:
            guard !lesson.rapid.isEmpty else { return record.isAnswered }
            return record.nextRapidIndex(total: lesson.rapid.count) == nil
        case .bonus: return record.bonusAt != nil
        }
    }

    private func isOpen(_ step: Step) -> Bool {
        guard let record else { return step == .watch }
        switch step {
        case .watch: return true
        case .answer: return record.watchedAt != nil
        case .rapid, .bonus: return record.isAnswered
        }
    }

    private var lockReason: [Step: String] {
        [.answer: "Watch the video to the end first",
         .rapid: "Answer today's question first",
         .bonus: "Answer today's question first"]
    }

    var body: some View {
        VStack(spacing: 0) {
            StepperBar(current: step, isDone: isDone, isOpen: isOpen) { tapped in
                if isOpen(tapped) {
                    withAnimation(.easeOut(duration: 0.2)) { step = tapped }
                } else {
                    toast = lockReason[tapped]
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    switch step {
                    case .watch:
                        WatchView(lesson: lesson, watched: isDone(.watch)) {
                            state.markWatched(percent: 100)
                            if !isDone(.answer) {
                                withAnimation { step = .answer }
                            }
                        }
                    case .answer:
                        AnswerView(lesson: lesson, record: record) { pick, correct in
                            state.answer(pick: pick, correct: correct)
                            if correct { celebrate = true }
                        }
                    case .rapid:
                        RapidFireView(lesson: lesson, record: record) { index, pick, correct in
                            state.answerRapid(index: index, pick: pick, correct: correct)
                        }
                    case .bonus:
                        BonusView(lesson: lesson, claimed: isDone(.bonus),
                                  stepsDone: Step.allCases.filter(isDone).map(\.title)) {
                            state.claimBonus()
                        } rewatch: {
                            withAnimation { step = .watch }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 110)
            }
        }
        .overlay(alignment: .top) {
            if let toast {
                Text(toast)
                    .font(.system(size: 15, weight: .bold))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Theme.yellow, in: Capsule())
                    .foregroundStyle(Theme.bg)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(nanoseconds: 2_200_000_000)
                        withAnimation { self.toast = nil }
                    }
            }
        }
        .overlay { if celebrate { Celebration().id(UUID()) } }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .animation(.easeOut(duration: 0.2), value: toast)
        .onAppear { step = firstUnfinishedStep() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            if lesson.boss {
                Text("⚔️ BOSS BATTLE · DOUBLE XP")
                    .font(.system(size: 14, weight: .black))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Theme.red, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.bottom, 6)
            }
            Text("LESSON \(record?.session ?? 1) · \(lesson.topic.uppercased())")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Theme.soft)
                .lineLimit(1)
            Text(lesson.title)
                .font(.system(size: 22, weight: .black))
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        switch step {
        case .watch:
            if isDone(.watch) {
                PrimaryBar(title: isDone(.answer) ? "Next: ⚡ Rapid Fire ➜" : "Next: 🎯 Answer the question ➜") {
                    withAnimation { step = isDone(.answer) ? .rapid : .answer }
                }
            }
        case .answer:
            if isDone(.answer) {
                PrimaryBar(title: lesson.rapid.isEmpty ? "Next: ⭐ Bonus Quest ➜"
                                                       : "Next: ⚡ Rapid Fire · \(lesson.rapid.count) questions ➜") {
                    withAnimation { step = lesson.rapid.isEmpty ? .bonus : .rapid }
                }
            }
        case .rapid:
            if isDone(.rapid) {
                PrimaryBar(title: "Next: ⭐ Bonus Quest ➜") { withAnimation { step = .bonus } }
            }
        case .bonus:
            EmptyView()
        }
    }

    private func firstUnfinishedStep() -> Step {
        Step.allCases.first { !isDone($0) && isOpen($0) } ?? .bonus
    }
}
