import SwiftUI

/// Top HUD: level badge with XP progress, region name, gold, pack count,
/// and stamina.
struct HUDBar: View {
    @EnvironmentObject private var game: GameState
    @State private var showingAdReward = false

    var body: some View {
        let progress = XPTable.progressToNext(xp: game.totalXP)

        VStack(spacing: 8) {
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

            if game.isWoodcuttingBoostActive {
                potionBoostRow
            } else {
                adBoostRow
            }

            staminaRow
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        // Sits outside the scene ZStack, so a real Material would have
        // nothing to blur — a solid light strip is the honest equivalent.
        .background(Color.white.opacity(0.95))
        .fullScreenCover(isPresented: $showingAdReward) {
            AdRewardOverlay {
                game.grantAdBoost()
                showingAdReward = false
            }
            .interactiveDismissDisabled(true)
        }
    }

    /// Compact stamina meter spanning the full HUD width, dimming and
    /// swapping its icon when empty (matches the exhausted movement/chop
    /// penalty applied in `GameState`).
    private var staminaRow: some View {
        HStack(spacing: 8) {
            Image(systemName: isExhausted ? "bolt.slash.fill" : "bolt.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(
                    isExhausted
                        ? SylvanTheme.hudTextDark.opacity(0.4)
                        : SylvanTheme.hudStamina
                )
                .frame(width: 16)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(SylvanTheme.hudTrack)
                    Capsule()
                        .fill(SylvanTheme.hudStamina)
                        .frame(width: geo.size.width * staminaFraction)
                    Capsule().strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                }
            }
            .frame(height: 14)

            Text("\(Int(game.stamina.rounded()))/\(Int(GameData.maxStamina.rounded()))")
                .font(.stat(10, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(SylvanTheme.hudTextDark.opacity(0.8))
        }
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
                        .foregroundStyle(SylvanTheme.Scene3D.potionGlow)
                    Text("Woodcutting +\(GameData.woodcuttingPotionLevelBoost) — \(formattedCountdown(remaining))")
                        .font(.stat(11, weight: .semibold))
                        .foregroundStyle(SylvanTheme.hudTextDark)
                        .monospacedDigit()
                    Spacer()
                }
            }
        }
    }

    private func formattedCountdown(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Shown whenever no boost is active: either a "Watch Ad" button (off
    /// cooldown) or a live countdown to when it becomes available again.
    @ViewBuilder
    private var adBoostRow: some View {
        if game.isAdBoostAvailable {
            adBoostButton
        } else if let cooldownExpiresAt = game.adBoostCooldownExpiresAt {
            adCooldownRow(expiresAt: cooldownExpiresAt)
        }
    }

    private var adBoostButton: some View {
        Button {
            showingAdReward = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SylvanTheme.forestGreen)
                Text("Watch Ad: +\(GameData.woodcuttingPotionLevelBoost) Woodcutting")
                    .font(.stat(11, weight: .semibold))
                    .foregroundStyle(SylvanTheme.hudTextDark)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private func adCooldownRow(expiresAt: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, expiresAt.timeIntervalSince(context.date))
            HStack(spacing: 8) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SylvanTheme.hudTextDark.opacity(0.4))
                Text("Ad boost ready in \(formattedCountdown(remaining))")
                    .font(.stat(11, weight: .semibold))
                    .foregroundStyle(SylvanTheme.hudTextDark.opacity(0.6))
                    .monospacedDigit()
                Spacer()
            }
        }
    }

    private var staminaFraction: Double {
        guard GameData.maxStamina > 0 else { return 0 }
        return max(0, min(1, game.stamina / GameData.maxStamina))
    }

    private var isExhausted: Bool { game.stamina <= 0 }

    /// Derive a biome name from player distance.
    private var biomeName: String {
        let dist = hypot(game.player.position.x, game.player.position.y)
        for (species, minDist) in GameData.speciesSpawnBands.reversed() {
            if dist >= minDist { return "\(species.displayName) Woods" }
        }
        return "The Forest"
    }
}
