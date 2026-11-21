import SwiftUI
import MathBlitzCore

struct AnswerView: View {
    let lesson: Lesson
    let record: DayRecord?
    let onAnswer: (Int, Bool) -> Void

    @State private var secondsLeft = 90
    @State private var ticker: Timer?

    private var pick: Int? { record?.pick }
    private var answered: Bool { pick != nil }
    private var correct: Bool { record?.correct ?? false }
    private var multiplier: Int { lesson.boss ? 2 : 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(lesson.question.prompt)
                .font(.system(size: 20, weight: .heavy))
                .fixedSize(horizontal: false, vertical: true)

            if !answered {
                HStack(spacing: 4) {
                    Text("Win **+\(25 * multiplier) XP**")
                    Text("·")
                    Text(secondsLeft > 0
                         ? "⚡ speed bonus +\(10 * multiplier) XP for \(secondsLeft)s"
                         : "speed bonus over — still worth it!")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.yellow)
                .padding(.bottom, 4)
            }

            ForEach(lesson.question.choices.indices, id: \.self) { i in
                ChoiceButton(letter: String(Array("ABCD")[min(i, 3)]),
                             text: lesson.question.choices[i],
                             colour: Theme.choice[i % Theme.choice.count],
                             state: buttonState(i)) {
                    guard !answered else { return }
                    ticker?.invalidate()
                    onAnswer(i, i == lesson.question.answer)
                }
                .disabled(answered)
            }

            if answered {
                VStack(alignment: .leading, spacing: 8) {
                    Text(correct ? cheer : "So close! Here's the play-by-play:")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(correct ? Theme.green : Theme.pink)
                    Text(lesson.question.explain)
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.soft)
                        .fixedSize(horizontal: false, vertical: true)
                    if !correct {
                        Text("💪 A lesson on this comes back around. Win some XP back in Rapid Fire ⬇️")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.soft)
                    }
                }
                .padding(.top, 10)
            }
        }
        .cardStyle()
        .onAppear(perform: startTicker)
        .onDisappear { ticker?.invalidate() }
    }

    private var cheer: String {
        if lesson.boss { return "BOSS DEFEATED! ⚔️" }
        let cheers = ["NOTHING BUT NET! 🏀", "TOUCHDOWN! 🏈", "GOOOAL! ⚽",
                      "HOME RUN! ⚾", "SLAM DUNK! 🏀", "HAT TRICK! 🏒"]
        return cheers[abs(lesson.id.hashValue) % cheers.count]
    }

    private func buttonState(_ i: Int) -> ChoiceButton.State {
        guard answered else { return .idle }
        if i == lesson.question.answer { return .right }
        if i == pick { return .wrong }
        return .dimmed
    }

    private func startTicker() {
        guard !answered, let watchedAt = record?.watchedAt else { return }
        updateSeconds(from: watchedAt)
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            updateSeconds(from: watchedAt)
            if secondsLeft <= 0 { timer.invalidate() }
        }
    }

    private func updateSeconds(from watchedAt: Date) {
        secondsLeft = max(0, 90 - Int(Date().timeIntervalSince(watchedAt)))
    }
}
