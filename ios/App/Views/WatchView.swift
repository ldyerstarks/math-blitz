import AVKit
import SwiftUI
import MathBlitzCore

/// Plays the day's video and unlocks the question once he's watched it through.
/// Skipping ahead doesn't count: only time actually played moves the marker.
struct WatchView: View {
    let lesson: Lesson
    let watched: Bool
    let onFinished: () -> Void

    @EnvironmentObject private var state: AppState
    @State private var player: AVPlayer?
    @State private var furthest: Double = 0
    @State private var observer: Any?
    @State private var nudgedAboutSkipping = false
    @State private var skipToast = false
    @State private var reportedFinished = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(.black)
                if let player {
                    VideoPlayer(player: player)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    ProgressView().tint(.white)
                }
            }
            .aspectRatio(9.0 / 16.0, contentMode: .fit)
            .frame(maxHeight: 420)

            if skipToast {
                Text("No skipping ahead 😉 Watch it through to unlock the question")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.yellow)
                    .multilineTextAlignment(.center)
            } else if !watched {
                Label("Watch to the end to unlock the question", systemImage: "lock.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.soft)
            } else {
                Label("Unlocked", systemImage: "lock.open.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.green)
            }
        }
        .task(id: lesson.id) { await load() }
        .onDisappear { teardown() }
    }

    private func load() async {
        teardown()
        furthest = 0
        reportedFinished = watched
        let url = await state.videoURL(for: lesson)
        let player = AVPlayer(url: url)
        player.allowsExternalPlayback = false
        self.player = player
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        observer = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            guard let item = player.currentItem else { return }
            let duration = item.duration.seconds
            guard duration.isFinite, duration > 0 else { return }
            let now = time.seconds
            if now > furthest {
                // Only count time that actually played; a jump forward is ignored.
                if now - furthest < 1.5 {
                    furthest = now
                } else if !nudgedAboutSkipping {
                    nudgedAboutSkipping = true
                    skipToast = true
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        skipToast = false
                    }
                }
            }
            if !reportedFinished, furthest / duration > 0.9 {
                reportedFinished = true
                onFinished()
            }
        }
    }

    private func teardown() {
        if let observer, let player { player.removeTimeObserver(observer) }
        observer = nil
        player?.pause()
        player = nil
    }
}
