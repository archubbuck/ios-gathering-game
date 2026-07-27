import SwiftUI

/// Floating "Watch Ad" prompt, independent of `HUDBar` so it never reflows
/// the top HUD as it appears, disappears, or swaps to a cooldown countdown.
/// Hidden entirely while a boost (from either source) is active.
struct AdBoostFloatingButton: View {
    @EnvironmentObject private var game: GameState
    @State private var showingAdReward = false

    var body: some View {
        Group {
            if game.isAdBoostAvailable {
                watchAdButton
            } else if let cooldownExpiresAt = game.adBoostCooldownExpiresAt, !game.isWoodcuttingBoostActive {
                cooldownChip(expiresAt: cooldownExpiresAt)
            }
        }
        .fullScreenCover(isPresented: $showingAdReward) {
            AdRewardOverlay {
                game.grantAdBoost()
                showingAdReward = false
            }
            .interactiveDismissDisabled(true)
        }
    }

    private var watchAdButton: some View {
        Button {
            showingAdReward = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SylvanTheme.forestGreen)
                Text("Watch Ad: +\(GameData.woodcuttingPotionLevelBoost) Woodcutting")
                    .font(.stat(12, weight: .semibold))
                    .foregroundStyle(SylvanTheme.hudTextDark)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .background(Capsule().fill(SylvanTheme.hudPanelTint))
                    .overlay(Capsule().strokeBorder(SylvanTheme.hudBorder, lineWidth: 1))
            )
            .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func cooldownChip(expiresAt: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, expiresAt.timeIntervalSince(context.date))
            HStack(spacing: 6) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SylvanTheme.hudTextDark.opacity(0.4))
                Text(formattedCountdown(remaining))
                    .font(.stat(11, weight: .semibold))
                    .foregroundStyle(SylvanTheme.hudTextDark.opacity(0.6))
                    .monospacedDigit()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .background(Capsule().fill(SylvanTheme.hudPanelTint.opacity(0.7)))
            )
        }
    }

    private func formattedCountdown(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
