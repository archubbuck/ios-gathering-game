import SwiftUI

/// Top HUD: level badge with XP progress, region name, gold, pack count.
struct HUDBar: View {
    @EnvironmentObject private var game: GameState

    var body: some View {
        let progress = XPTable.progressToNext(xp: game.totalXP)

        HStack(spacing: 12) {
            // Level badge
            ZStack {
                Circle()
                    .fill(SylvanTheme.heroGradient)
                Circle()
                    .stroke(.white, lineWidth: 2.5)
                Text("\(game.level)")
                    .font(.display(19))
                    .foregroundStyle(.white)
            }
            .frame(width: 46, height: 46)
            .shadow(color: .black.opacity(0.12), radius: 3, y: 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(biomeName)
                    .font(.display(16))
                    .foregroundStyle(SylvanTheme.hudTextDark)
                ProgressView(value: progress.fraction)
                    .tint(SylvanTheme.hudStamina)
                    .scaleEffect(y: 1.4)
                Text(
                    game.level >= XPTable.maxLevel
                        ? "Max level!"
                        : "\(Int(progress.current)) / \(Int(progress.needed)) XP"
                )
                .font(.stat(10, weight: .medium))
                .foregroundStyle(SylvanTheme.hudTextDark.opacity(0.7))
                .monospacedDigit()
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 5) {
                StatChip(
                    systemImage: "circlebadge.2.fill",
                    text: "\(game.gold) gp",
                    tint: SylvanTheme.hudLogGold,
                    onLight: true
                )
                StatChip(
                    systemImage: "tray.full.fill",
                    text: "\(game.packCount)/\(GameData.inventorySlots)",
                    tint: game.packIsFull ? SylvanTheme.hudLogWarning : SylvanTheme.forestGreen,
                    onLight: true
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        // Sits outside the scene ZStack, so a real Material would have
        // nothing to blur — a solid light strip is the honest equivalent.
        .background(Color.white.opacity(0.95))
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
