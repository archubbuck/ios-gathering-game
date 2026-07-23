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
                    .stroke(SylvanTheme.gold, lineWidth: 2.5)
                Text("\(game.level)")
                    .font(.display(19))
                    .foregroundStyle(.white)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(biomeName)
                    .font(.display(16))
                    .foregroundStyle(SylvanTheme.textOnWood)
                ProgressView(value: progress.fraction)
                    .tint(SylvanTheme.gold)
                    .scaleEffect(y: 1.4)
                Text(
                    game.level >= XPTable.maxLevel
                        ? "Max level!"
                        : "\(Int(progress.current)) / \(Int(progress.needed)) XP"
                )
                .font(.stat(10, weight: .medium))
                .foregroundStyle(SylvanTheme.textOnWood.opacity(0.7))
                .monospacedDigit()
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 5) {
                StatChip(systemImage: "circlebadge.2.fill", text: "\(game.gold) gp")
                StatChip(
                    systemImage: "tray.full.fill",
                    text: "\(game.packCount)/\(GameData.inventorySlots)",
                    tint: game.packIsFull ? Color(hex: 0xFFAB91) : SylvanTheme.canopyLight
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [SylvanTheme.woodPanelTop, SylvanTheme.woodPanelBottom],
                startPoint: .top, endPoint: .bottom
            )
        )
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
