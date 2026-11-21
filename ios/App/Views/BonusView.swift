import SwiftUI
import MathBlitzCore

/// The optional extra: open a free practice link, spend a few minutes on it,
/// then claim the XP. The three-minute wait is the honour system with a speed bump.
struct BonusView: View {
    let lesson: Lesson
    let claimed: Bool
    let stepsDone: [String]
    let onClaim: () -> Void
    let rewatch: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var openedAt: Double = 0
    @State private var secondsLeft = 180

    /// Per-lesson so yesterday's three minutes don't unlock today's quest.
    private var openedKey: String { "bonusOpenedAt.\(lesson.id)" }
    @State private var ticker: Timer?

    private var multiplier: Int { lesson.boss ? 2 : 1 }
    private var quest: Resource? { lesson.resources.first(where: \.quest) ?? lesson.resources.first }
    private var others: [Resource] { lesson.resources.filter { $0.url != quest?.url } }
    private var ready: Bool { openedAt > 0 && secondsLeft <= 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let quest {
                VStack(alignment: .leading, spacing: 10) {
                    Text("⭐ Bonus Quest · +\(30 * multiplier) XP")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Theme.yellow)
                    Text(quest.label)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.soft)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        Button {
                            if openedAt == 0 {
                                openedAt = Date().timeIntervalSince1970
                                UserDefaults.standard.set(openedAt, forKey: openedKey)
                            }
                            startTicker()
                            openURL(quest.url)
                        } label: {
                            Label(quest.button ?? "Open practice", systemImage: "arrow.up.forward.app.fill")
                                .font(.system(size: 16, weight: .heavy))
                                .padding(.vertical, 12).padding(.horizontal, 14)
                                .background(Theme.cyan, in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(Theme.bg)
                        }
                        .buttonStyle(.plain)

                        Button(action: onClaim) {
                            Text(claimed ? "✅ Done" : ready ? "I did it!" : timerLabel)
                                .font(.system(size: 16, weight: .heavy))
                                .padding(.vertical, 12).padding(.horizontal, 14)
                                .background(claimed || ready ? Theme.green : Theme.card2,
                                            in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(claimed || ready ? Theme.bg : Theme.soft)
                        }
                        .buttonStyle(.plain)
                        .disabled(claimed || !ready)
                    }

                    if !claimed {
                        Text(openedAt == 0
                             ? "Open the practice, do a few, then come back and tap “I did it!”"
                             : "Keep going — the button unlocks after three minutes.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.soft)
                    }

                    if !others.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(others, id: \.url) { resource in
                                Link(destination: resource.url) {
                                    Text("\(resource.name): \(resource.label)")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Theme.cyan)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .cardStyle()
            }

            VStack(spacing: 10) {
                Text(stepsDone.count >= 4 ? "Lesson complete! 🏆" : "Today so far")
                    .font(.system(size: 22, weight: .black))
                HStack(spacing: 8) {
                    ForEach(["Watch", "Answer", "Rapid Fire", "Bonus"], id: \.self) { name in
                        let done = stepsDone.contains(name)
                        Text("\(done ? "✓" : "○") \(name)")
                            .font(.system(size: 13, weight: .heavy))
                            .padding(.horizontal, 9).padding(.vertical, 6)
                            .background(Color.white.opacity(0.08), in: Capsule())
                            .foregroundStyle(done ? Theme.green : Theme.soft)
                    }
                }
                Button(action: rewatch) {
                    Label("Rewatch the video", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
            }
            .cardStyle()
        }
        .onAppear {
            openedAt = UserDefaults.standard.double(forKey: openedKey)
            startTicker()
        }
        .onDisappear { ticker?.invalidate() }
    }

    private var timerLabel: String {
        let m = secondsLeft / 60, s = secondsLeft % 60
        return String(format: "Ready in %d:%02d", m, s)
    }

    private func startTicker() {
        guard openedAt > 0, !claimed else { return }
        tick()
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            tick()
            if secondsLeft <= 0 { timer.invalidate() }
        }
    }

    private func tick() {
        let elapsed = Date().timeIntervalSince1970 - openedAt
        secondsLeft = max(0, 180 - Int(elapsed))
    }
}
