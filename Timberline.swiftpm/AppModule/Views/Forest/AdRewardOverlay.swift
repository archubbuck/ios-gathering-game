import SwiftUI

/// Simulated rewarded-ad placeholder: a full-screen, non-dismissable
/// countdown mimicking a real ad network's rewarded video. There is no ad
/// SDK and no network access here — it's purely a timed gate the caller
/// presents before granting the reward via `onComplete`.
struct AdRewardOverlay: View {
    let onComplete: () -> Void

    @State private var startedAt = Date()

    private var duration: TimeInterval { GameData.simulatedAdDuration }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TimelineView(.animation) { context in
                let elapsed = context.date.timeIntervalSince(startedAt)
                let remaining = max(0, duration - elapsed)
                let progress = duration > 0 ? min(1, elapsed / duration) : 1

                VStack(spacing: 18) {
                    Text("ADVERTISEMENT")
                        .font(.stat(12, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.6))

                    ZStack {
                        ProgressRing(
                            progress: progress,
                            tint: TimberlineTheme.gold,
                            track: .white.opacity(0.2),
                            lineWidth: 6
                        )
                        .frame(width: 84, height: 84)

                        Text("\(Int(remaining.rounded(.up)))")
                            .font(.display(28))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }

                    Text("Your reward is on its way...")
                        .font(.stat(14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            await MainActor.run {
                onComplete()
            }
        }
    }
}
