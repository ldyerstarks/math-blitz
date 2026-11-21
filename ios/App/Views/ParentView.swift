import SwiftUI
import MathBlitzCore

/// The grown-up screen: the same dials as the Settings tab in the log sheet,
/// plus an honest statement of what the app does and doesn't collect.
struct ParentView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var unlocked = false
    @State private var entered = ""
    @State private var cacheMB: Double = 0
    @State private var confirmErase = false

    var body: some View {
        NavigationStack {
            Group {
                if unlocked || state.settings.parentPIN.isEmpty {
                    settings
                } else {
                    lock
                }
            }
            .navigationTitle("Grown-ups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .task { cacheMB = await state.cacheSizeMB() }
    }

    private var lock: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill").font(.system(size: 40)).foregroundStyle(Theme.soft)
            Text("Enter the grown-up PIN").font(.headline)
            SecureField("4 digits", text: $entered)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .frame(width: 140)
                .onChange(of: entered) { _, value in
                    if value == state.settings.parentPIN { unlocked = true }
                }
            Text("This only keeps the settings out of reach mid-lesson. Don't reuse a PIN that matters.")
                .font(.footnote).foregroundStyle(Theme.soft)
                .multilineTextAlignment(.center).padding(.horizontal, 30)
        }
    }

    private var settings: some View {
        Form {
            Section("Difficulty") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Level adjustment")
                        Spacer()
                        Text(String(format: "%+.1f", state.settings.levelAdjustment))
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                    Slider(value: $state.settings.levelAdjustment, in: -3...3, step: 0.5)
                    Text("Shown level: \(String(format: "%.1f", state.summary.level)) (\(state.summary.levelName)) · about grade \(String(format: "%.1f", state.summary.gradeEquivalent))")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Stepper("School grade: \(state.settings.schoolGrade)",
                        value: $state.settings.schoolGrade, in: 4...12)
            }

            Section("Daily Blitz") {
                Toggle("Pause", isOn: $state.settings.paused)
                Toggle("Daily reminder", isOn: $state.settings.remindersOn)
                Text("Weekdays at 7:00 am, weekends at 10:00 am.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section("Progress") {
                LabeledContent("XP", value: "\(state.summary.xp)")
                LabeledContent("Rank", value: "\(state.summary.rank.icon) \(state.summary.rank.name)")
                LabeledContent("Current streak", value: "\(state.summary.streak) days")
                LabeledContent("Best streak", value: "\(state.summary.bestStreak) days")
                LabeledContent("Daily questions", value: "\(state.summary.wins)/\(state.summary.answered) right")
                LabeledContent("Rapid Fire", value: "\(state.summary.rapidWins)/\(state.summary.rapidAnswered) right")
            }

            Section("Privacy") {
                Text("Everything stays on this iPhone. There are no accounts, no ads, no analytics and no tracking, and nothing about your child is sent anywhere. The app only downloads lesson videos from a public website.")
                    .font(.footnote)
                LabeledContent("Downloaded videos", value: String(format: "%.0f MB", cacheMB))
                Button("Erase all progress and downloads", role: .destructive) { confirmErase = true }
            }

            Section("Grown-up PIN") {
                TextField("4 digits, or blank for none", text: $state.settings.parentPIN)
                    .keyboardType(.numberPad)
            }
        }
        .alert("Erase everything?", isPresented: $confirmErase) {
            Button("Erase", role: .destructive) {
                Task { await state.eraseEverything(); cacheMB = await state.cacheSizeMB() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears XP, streak and every downloaded video on this iPhone. It can't be undone.")
        }
        .onChange(of: state.settings.remindersOn) { _, on in
            Task { await Reminders.reschedule(enabled: on && !state.settings.paused) }
        }
        .onChange(of: state.settings.paused) { _, paused in
            Task { await Reminders.reschedule(enabled: state.settings.remindersOn && !paused) }
        }
    }
}
