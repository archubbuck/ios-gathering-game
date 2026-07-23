import SwiftUI

/// Circular progress indicator shown over the active tree: fills as the
/// tree is chopped down.
struct ProgressRing: View {
    var progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(SylvanTheme.darkWood.opacity(0.3), lineWidth: 5)
            Circle()
                .trim(from: 0, to: max(0.02, min(progress, 1)))
                .stroke(
                    SylvanTheme.gold,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.3), value: progress)
        }
    }
}
