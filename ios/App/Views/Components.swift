import SwiftUI

enum Step: String, CaseIterable, Identifiable {
    case watch, answer, rapid, bonus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .watch: return "Watch"
        case .answer: return "Answer"
        case .rapid: return "Rapid Fire"
        case .bonus: return "Bonus"
        }
    }

    var symbol: String {
        switch self {
        case .watch: return "play.fill"
        case .answer: return "target"
        case .rapid: return "bolt.fill"
        case .bonus: return "star.fill"
        }
    }
}

/// The four-step bar across the top: done, locked or here.
struct StepperBar: View {
    let current: Step
    let isDone: (Step) -> Bool
    let isOpen: (Step) -> Bool
    let select: (Step) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases) { step in
                Button {
                    select(step)
                } label: {
                    VStack(spacing: 3) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: isOpen(step) ? step.symbol : "lock.fill")
                                .font(.system(size: 17, weight: .semibold))
                                .frame(height: 20)
                            if isDone(step) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .black))
                                    .offset(x: 12, y: -4)
                            }
                        }
                        Text(step.title.uppercased())
                            .font(.system(size: 10, weight: .heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundStyle(foreground(step))
                    .background(background(step), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(current == step ? Theme.yellow : .clear, lineWidth: 3)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(step.title)\(isDone(step) ? ", done" : isOpen(step) ? "" : ", locked")")
            }
        }
    }

    private func foreground(_ step: Step) -> Color {
        if current == step { return Theme.bg }
        if isDone(step) { return Theme.green }
        return isOpen(step) ? Theme.soft : Theme.soft.opacity(0.45)
    }

    private func background(_ step: Step) -> Color {
        current == step ? .white : Color.white.opacity(0.07)
    }
}

/// One answer choice, A-D, coloured like the web page.
struct ChoiceButton: View {
    let letter: String
    let text: String
    let colour: Color
    let state: State
    let action: () -> Void

    enum State { case idle, right, wrong, dimmed }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(letter)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(colour)
                Text(text)
                    .font(.system(size: 20, weight: .bold))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(border, lineWidth: 3)
            )
            .opacity(state == .dimmed ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .accessibilityLabel("\(letter). \(text)")
    }

    private var fill: Color {
        switch state {
        case .right: return Theme.green.opacity(0.25)
        case .wrong: return Theme.pink.opacity(0.25)
        default: return Color.white.opacity(0.06)
        }
    }

    private var border: Color {
        state == .right ? Theme.green : colour
    }
}

/// The single big button pinned to the bottom that always says what's next.
struct PrimaryBar: View {
    let title: String
    var waiting: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: waiting ? 16 : 19, weight: waiting ? .bold : .heavy))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(waiting ? Theme.soft : Theme.bg)
                .background(waiting ? Theme.card2 : Theme.cyan,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(waiting)
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }
}

struct Celebration: View {
    @State private var go = false
    private let pieces = (0..<60).map { _ in
        (x: Double.random(in: -180...180),
         delay: Double.random(in: 0...0.35),
         colour: [Theme.yellow, Theme.pink, Theme.cyan, Theme.green, Theme.orange].randomElement()!)
    }

    var body: some View {
        ZStack {
            ForEach(pieces.indices, id: \.self) { i in
                let piece = pieces[i]
                RoundedRectangle(cornerRadius: 2)
                    .fill(piece.colour)
                    .frame(width: 8, height: 4)
                    .offset(x: piece.x, y: go ? 420 : -260)
                    .opacity(go ? 0 : 1)
                    .animation(.easeIn(duration: 1.6).delay(piece.delay), value: go)
            }
        }
        .allowsHitTesting(false)
        .onAppear { go = true }
    }
}
