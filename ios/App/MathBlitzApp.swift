import SwiftUI

@main
struct MathBlitzApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .preferredColorScheme(.dark)
                .tint(Theme.cyan)
                .task {
                    await state.start()
                    await Reminders.reschedule(enabled: state.settings.remindersOn && !state.settings.paused)
                }
        }
    }
}
