import Charts
import SwiftUI
import MathBlitzCore

struct StatsView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    private var summary: Summary { state.summary }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    rankCard
                    if summary.levelHistory.count >= 2 { chartCard }
                    if !summary.badges.isEmpty { badgeCard }
                    historyCard
                }
                .padding(14)
            }
            .background(Theme.background(boss: false).ignoresSafeArea())
            .navigationTitle("My stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var rankCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Text(summary.rank.icon).font(.system(size: 44))
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.rank.name).font(.system(size: 20, weight: .black))
                    if let next = summary.nextRank, let togo = summary.xpToNextRank {
                        Text("\(summary.xp) XP · \(togo) to \(next.icon) \(next.name)")
                            .font(.system(size: 14)).foregroundStyle(Theme.soft)
                    } else {
                        Text("\(summary.xp) XP · MAX RANK")
                            .font(.system(size: 14)).foregroundStyle(Theme.soft)
                    }
                }
            }
            ProgressView(value: summary.rankProgress)
                .tint(Theme.yellow)
            HStack(spacing: 8) {
                tile("🔥 \(summary.streak)", "day streak")
                tile("\(summary.wins)/\(summary.answered)", "right")
                tile("Lv \(String(format: "%.1f", summary.level))", summary.levelName)
            }
        }
        .cardStyle()
    }

    private func tile(_ value: String, _ caption: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 19, weight: .heavy))
            Text(caption.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.soft)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Theme.card2, in: RoundedRectangle(cornerRadius: 12))
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("📈 Your climb to 1600")
                .font(.system(size: 15, weight: .black)).foregroundStyle(Theme.yellow)
            Text("Working at about grade \(String(format: "%.1f", summary.gradeEquivalent))")
                .font(.system(size: 13)).foregroundStyle(Theme.soft)
            Chart {
                ForEach(summary.levelHistory, id: \.session) { point in
                    LineMark(x: .value("Lesson", point.session),
                             y: .value("Grade", point.gradeEquivalent))
                        .foregroundStyle(Theme.cyan)
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Lesson", point.session),
                              y: .value("Grade", point.gradeEquivalent))
                        .foregroundStyle(Theme.cyan)
                }
                RuleMark(y: .value("1600-ready", 12))
                    .foregroundStyle(Theme.yellow)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("1600-ready").font(.caption2).foregroundStyle(Theme.yellow)
                    }
                RuleMark(y: .value("Your grade", Double(summary.schoolGrade)))
                    .foregroundStyle(Theme.soft)
                    .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [3, 4]))
                    .annotation(position: .bottom, alignment: .trailing) {
                        Text("your grade").font(.caption2).foregroundStyle(Theme.soft)
                    }
            }
            .chartYScale(domain: 5...12.5)
            .frame(height: 180)
            Text("A rough in-app scale, not a test score. Level 1 ≈ 6th grade, 10 ≈ 12th.")
                .font(.system(size: 11)).foregroundStyle(Theme.soft)
        }
        .cardStyle()
    }

    private var badgeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Badges").font(.system(size: 15, weight: .black)).foregroundStyle(Theme.yellow)
            FlowLayoutish(items: summary.badges)
        }
        .cardStyle()
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Every lesson").font(.system(size: 15, weight: .black)).foregroundStyle(Theme.yellow)
            ForEach(state.history.reversed(), id: \.lessonID) { record in
                HStack {
                    Text("\(record.session). \(state.bank?.lesson(id: record.lessonID)?.title ?? record.lessonID)")
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    if let correct = record.correct {
                        Text(correct ? "✅" : "❌")
                    } else {
                        Text("—").foregroundStyle(Theme.soft)
                    }
                }
                .padding(.vertical, 6)
            }
            if state.history.isEmpty {
                Text("Nothing yet — today's Blitz will show up here.")
                    .font(.system(size: 14)).foregroundStyle(Theme.soft)
            }
        }
        .cardStyle()
    }
}

/// Wrapping row of badge pills.
struct FlowLayoutish: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { item in
                        Text(item)
                            .font(.system(size: 13, weight: .bold))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Theme.yellow.opacity(0.15), in: Capsule())
                            .foregroundStyle(Theme.yellow)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var rows: [[String]] {
        stride(from: 0, to: items.count, by: 2).map {
            Array(items[$0..<min($0 + 2, items.count)])
        }
    }
}
