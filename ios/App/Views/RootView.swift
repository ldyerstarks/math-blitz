import SwiftUI
import MathBlitzCore

struct RootView: View {
    @EnvironmentObject private var state: AppState
    @State private var showStats = false
    @State private var showParent = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background(boss: state.activeLesson?.boss ?? false).ignoresSafeArea()
                content
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("MATH BLITZ")
                        .font(.system(size: 19, weight: .black))
                        .foregroundStyle(Theme.yellow)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showStats = true
                    } label: {
                        Label("\(state.summary.rank.icon) \(state.summary.xp) XP · 🔥\(state.summary.streak)",
                              systemImage: "chart.bar.fill")
                            .labelStyle(.titleOnly)
                            .font(.system(size: 14, weight: .heavy))
                    }
                    .accessibilityLabel("My stats")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showParent = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Grown-ups")
                }
            }
            .sheet(isPresented: $showStats) { StatsView() }
            .sheet(isPresented: $showParent) { ParentView() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if state.settings.paused {
            Message(icon: "pause.circle.fill",
                    title: "Taking a break",
                    message: "Math Blitz is paused. A grown-up can switch it back on in settings.")
        } else if let error = state.loadError, state.bank == nil {
            Message(icon: "wifi.slash", title: "No lessons yet", message: error) {
                Button("Try again") { Task { await state.refresh() } }
                    .buttonStyle(.borderedProminent)
            }
        } else if state.bank == nil {
            ProgressView("Loading today's Blitz…").tint(Theme.cyan)
        } else if let lesson = state.activeLesson {
            FlowView(lesson: lesson)
        } else if state.finishedToday {
            DoneForTodayView()
        } else {
            StartView()
        }
    }
}

struct Message<Extra: View>: View {
    let icon: String
    let title: String
    let message: String
    @ViewBuilder var extra: () -> Extra

    init(icon: String, title: String, message: String,
         @ViewBuilder extra: @escaping () -> Extra = { EmptyView() }) {
        self.icon = icon
        self.title = title
        self.message = message
        self.extra = extra
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 44)).foregroundStyle(Theme.soft)
            Text(title).font(.title2.bold())
            Text(message).font(.body).foregroundStyle(Theme.soft).multilineTextAlignment(.center)
            extra()
        }
        .padding(28)
    }
}

struct StartView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("🏀").font(.system(size: 64))
            Text("Today's Blitz is ready")
                .font(.system(size: 26, weight: .black))
            Text("About two minutes: one video, one question, then Rapid Fire.")
                .font(.body).foregroundStyle(Theme.soft)
                .multilineTextAlignment(.center).padding(.horizontal, 30)
            Spacer()
            Button {
                _ = state.beginNextLesson()
            } label: {
                Text("Start today's Blitz ➜")
                    .font(.system(size: 19, weight: .heavy))
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .foregroundStyle(Theme.bg)
                    .background(Theme.yellow, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14).padding(.bottom, 10)
        }
    }
}

struct DoneForTodayView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("🏆").font(.system(size: 64))
            Text("Today's Blitz is done!")
                .font(.system(size: 26, weight: .black))
            Text("🔥 \(state.summary.streak)-day streak · \(state.summary.xp) XP")
                .font(.title3.bold()).foregroundStyle(Theme.yellow)
            Text("Next one lands tomorrow morning.")
                .font(.body).foregroundStyle(Theme.soft)
            Spacer()
            Button("Do another one anyway") {
                _ = state.beginNextLesson()
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Theme.soft)
            .padding(.bottom, 20)
        }
    }
}
