import SwiftUI

/// Top HUD: level badge with XP progress, region name, gold, pack count,
/// and loading indicator.
struct HUDBar: View {
    @EnvironmentObject private var game: GameState

    /// Derived from the device's available canvas size (see `DeviceScale`)
    /// so the badge stays proportionate from iPhone SE to iPad.
    var scale: CGFloat = 1

    var body: some View {
        let progress = XPTable.progressToNext(xp: game.totalXP)
        let badgeSize = 46 * scale

        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Level badge
                ZStack {
                    Circle()
                        .fill(TimberlineTheme.heroGradient)
                    Circle()
                        .stroke(.white, lineWidth: 2.5)
                    Text("\(game.level)")
                        .font(.display(19 * scale))
                        .foregroundStyle(.white)
                }
                .frame(width: badgeSize, height: badgeSize)
                .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                .accessibilityLabel("Woodcutting level \(game.level)")

                VStack(alignment: .leading, spacing: 3) {
                    Text(biomeName)
                        .font(.display(16))
                        .foregroundStyle(TimberlineTheme.hudTextDark)
                    ProgressView(value: progress.fraction)
                        .tint(TimberlineTheme.hudStamina)
                        .scaleEffect(y: 1.4)
                        .accessibilityLabel("XP progress")
                        .accessibilityValue("\(Int(progress.current)) of \(Int(progress.needed)) XP")
                    Text(
                        game.level >= XPTable.maxLevel
                            ? "Max level!"
                            : "\(Int(progress.current)) / \(Int(progress.needed)) XP"
                    )
                    .font(.stat(10, weight: .medium))
                    .foregroundStyle(TimberlineTheme.hudTextDark.opacity(0.7))
                    .monospacedDigit()
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 5) {
                    StatChip(
                        systemImage: "circlebadge.2.fill",
                        text: "\(game.gold) gp",
                        tint: TimberlineTheme.hudLogGold,
                        onLight: true
                    )
                    .accessibilityLabel("\(game.gold) gold")
                    StatChip(
                        systemImage: "tray.full.fill",
                        text: "\(game.packCount)/\(GameData.inventorySlots)",
                        tint: game.packIsFull ? TimberlineTheme.hudLogWarning : TimberlineTheme.forestGreen,
                        onLight: true
                    )
                    .accessibilityLabel("Pack \(game.packCount) of \(GameData.inventorySlots)")
                }
            }

            if game.isWoodcuttingBoostActive {
                potionBoostRow
            }

            if game.loadingChunks {
                loadingRow
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.95))
    }

    /// Small indicator shown while background chunk generation is running.
    private var loadingRow: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.mini)
            Text("Loading forest…")
                .font(.stat(11, weight: .regular))
                .foregroundStyle(TimberlineTheme.hudTextDark.opacity(0.7))
            Spacer()
        }
        .accessibilityLabel("Loading nearby trees")
    }

    /// Shown only while a Woodcutting Potion boost is active; a live
    /// mm:ss countdown to `game.activeBoostExpiresAt`.
    @ViewBuilder
    private var potionBoostRow: some View {
        if let expiresAt = game.activeBoostExpiresAt {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(0, expiresAt.timeIntervalSince(context.date))
                HStack(spacing: 8) {
                    Image(systemName: "flask.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(TimberlineTheme.SceneArt.potionGlow)
                    Text("Woodcutting +\(GameData.woodcuttingPotionLevelBoost) — \(formattedCountdown(remaining))")
                        .font(.stat(11, weight: .semibold))
                        .foregroundStyle(TimberlineTheme.hudTextDark)
                        .monospacedDigit()
                    Spacer()
                }
                .accessibilityLabel("Woodcutting potion active, \(formattedCountdown(remaining)) remaining")
            }
        }
    }

    private func formattedCountdown(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Derive a biome name from player distance.
    private var biomeName: String {
        let dist = hypot(game.player.position.x, game.player.position.y)
        for (species, minDist) in GameData.speciesSpawnBands.reversed() {
            if dist >= minDist { return "\(species.displayName) Woods" }
        }
        return "The Forest"
    }
}
