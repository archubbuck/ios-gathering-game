import SwiftUI

/// Circular progress indicator shown over the active tree: fills as the
/// tree is chopped down. Defaults keep the classic gold-on-wood look;
/// the frosted chop overlay passes its own tint/track.
struct ProgressRing: View {
    var progress: Double
    var tint: Color = TimberlineTheme.gold
    var track: Color = TimberlineTheme.darkWood.opacity(0.3)
    var lineWidth: CGFloat = 5

    var body: some View {
        ZStack {
            Circle()
                .stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.02, min(progress, 1)))
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.3), value: progress)
        }
    }
}
