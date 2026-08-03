import SwiftUI

/// Auto-fading warning shown once when the player approaches a tree whose
/// Woodcutting level requirement exceeds their own. A new `warning.id`
/// (via `.id(_:)` at the call site) recreates the view, restarting the
/// appear/fade animation — same pattern as `XPDropOverlay`.
struct LevelGateToast: View {
    let warning: LevelGateWarning

    @State private var visible = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 13, weight: .semibold))
            Text("Requires Woodcutting level \(warning.requiredLevel) for \(warning.species.displayName)")
                .font(.stat(13, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Capsule().fill(TimberlineTheme.hudLogWarning.opacity(0.92)))
        .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : -12)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                visible = true
            }
            Task {
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.4)) {
                        visible = false
                    }
                }
            }
        }
    }
}
