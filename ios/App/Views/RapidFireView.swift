import SwiftUI
import MathBlitzCore

/// Five one-tap questions. A right answer moves on by itself; a wrong one
/// stops and waits for "Got it", so the explanation is never missed.
struct RapidFireView: View {
    let lesson: Lesson
    let record: DayRecord?
    let onAnswer: (Int, Int, Bool) -> Void

    /// The question whose result is on screen. While this is set the view stays
    /// put, even though the record has already moved on, so the explanation is
    /// never skipped past.
    @State private var revealed: Int?
    @State private var advanceTask: Task<Void, Never>?

    private var multiplier: Int { lesson.boss ? 2 : 1 }
    private var answers: [RapidAnswer] { (record?.rapid ?? []).sorted { $0.index < $1.index } }
    private var index: Int? { revealed ?? record?.nextRapidIndex(total: lesson.rapid.count) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if lesson.rapid.isEmpty {
                Text("No Rapid Fire today").font(.title3.bold())
            } else if let index, lesson.rapid.indices.contains(index) {
                question(at: index)
            } else {
                finished
            }
        }
        .cardStyle()
        .onDisappear { advanceTask?.cancel() }
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(lesson.rapid.indices, id: \.self) { i in
                Capsule()
                    .fill(colour(for: i))
                    .frame(height: 6)
            }
        }
    }

    private func colour(for i: Int) -> Color {
        if let answer = answers.first(where: { $0.index == i }) {
            return answer.correct ? Theme.green : Theme.pink
        }
        return i == index ? Theme.yellow : Color.white.opacity(0.15)
    }

    @ViewBuilder
    private func question(at index: Int) -> some View {
        let item = lesson.rapid[index]
        let lastAnswer = answers.first { $0.index == index }

        HStack {
            Text("⚡ RAPID FIRE · +\(10 * multiplier) XP each")
            Spacer()
            Text("\(index + 1) / \(lesson.rapid.count)")
        }
        .font(.system(size: 15, weight: .black))
        .foregroundStyle(Theme.yellow)

        dots

        Text(item.prompt)
            .font(.system(size: 20, weight: .heavy))
            .fixedSize(horizontal: false, vertical: true)

        ForEach(item.choices.indices, id: \.self) { i in
            ChoiceButton(letter: String(Array("ABCD")[min(i, 3)]),
                         text: item.choices[i],
                         colour: Theme.choice[i % Theme.choice.count],
                         state: state(for: i, item: item, answered: lastAnswer)) {
                guard lastAnswer == nil else { return }
                tap(index: index, pick: i, item: item)
            }
            .disabled(lastAnswer != nil)
        }

        if let lastAnswer {
            if lastAnswer.correct {
                Text("+\(10 * multiplier) XP")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(Theme.yellow)
            } else {
                Text(item.why)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.soft)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    advanceTask?.cancel()
                    revealed = nil
                } label: {
                    Text(index + 1 < lesson.rapid.count ? "Got it ➜ next question" : "Got it ➜ see my score")
                        .font(.system(size: 17, weight: .heavy))
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .foregroundStyle(Theme.bg)
                        .background(Theme.cyan, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
    }

    private var finished: some View {
        let right = answers.filter(\.correct).count
        let total = lesson.rapid.count
        let message: String
        if right == total { message = "PERFECT ROUND! 🔥🔥🔥" }
        else if right >= total - 1 { message = "ALMOST PERFECT! 🔥" }
        else if right * 2 >= total { message = "Solid round! 💪" }
        else { message = "Tough round. Next time you get your revenge 💪" }
        return VStack(spacing: 8) {
            dots
            Text("\(right) / \(total)").font(.system(size: 34, weight: .black))
            Text(message).font(.system(size: 18, weight: .heavy))
        }
        .frame(maxWidth: .infinity)
    }

    private func state(for i: Int, item: RapidQuestion, answered: RapidAnswer?) -> ChoiceButton.State {
        guard let answered else { return .idle }
        if i == item.answer { return .right }
        if i == answered.pick { return .wrong }
        return .dimmed
    }

    private func tap(index: Int, pick: Int, item: RapidQuestion) {
        let correct = pick == item.answer
        revealed = index
        onAnswer(index, pick, correct)
        advanceTask?.cancel()
        if correct {
            advanceTask = Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                revealed = nil
            }
        }
    }
}
