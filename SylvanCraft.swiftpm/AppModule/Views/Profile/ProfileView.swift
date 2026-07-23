import SwiftUI

/// Tab 5: woodcutting level card, lifetime stats, achievement badges,
/// and the settings sheet.
struct ProfileView: View {
    @EnvironmentObject private var game: GameState
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            SylvanTheme.parchment.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    HStack {
                        Text("Profile")
                            .font(.display(30))
                            .foregroundStyle(SylvanTheme.textOnParchment)
                        Spacer()
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(SylvanTheme.textOnParchmentSecondary)
                        }
                    }

                    levelCard
                    statsCard
                    achievementsCard
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    private var levelCard: some View {
        let progress = XPTable.progressToNext(xp: game.totalXP)
        return VStack(spacing: 8) {
            Text("Woodcutting")
                .font(.stat(13))
                .foregroundStyle(SylvanTheme.textOnParchmentSecondary)
                .textCase(.uppercase)
            Text("Level \(game.level)")
                .font(.display(40))
                .foregroundStyle(SylvanTheme.textOnParchment)
            ProgressView(value: progress.fraction)
                .tint(SylvanTheme.forestGreen)
            Text(
                game.level >= XPTable.maxLevel
                    ? "Max level — a true master!"
                    : "\(Int(progress.current)) / \(Int(progress.needed)) XP to level \(game.level + 1)"
            )
            .font(.stat(12, weight: .regular))
            .foregroundStyle(SylvanTheme.textOnParchmentSecondary)
            .monospacedDigit()

            HStack(spacing: 8) {
                AxeArt(tier: game.equippedAxe)
                    .scaleEffect(0.7)
                    .frame(width: 34, height: 40)
                Text("\(game.equippedAxe.displayName) axe equipped")
                    .font(.stat(13))
                    .foregroundStyle(SylvanTheme.textOnParchment)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .parchmentCard()
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lifetime")
                .font(.display(18))
                .foregroundStyle(SylvanTheme.textOnParchment)
            statRow(symbol: "leaf.fill", label: "Logs chopped", value: "\(game.stats.totalLogs)")
            statRow(symbol: "circlebadge.2.fill", label: "Gold earned", value: "\(game.stats.lifetimeGold) gp")
            statRow(symbol: "map.fill", label: "Distance traveled", value: "\(Int(hypot(game.player.position.x, game.player.position.y))) units")
            statRow(symbol: "hammer.fill", label: "Axes owned", value: "\(game.ownedAxes.count)/\(GameData.axes.count)")
            statRow(symbol: "sparkles", label: "Total XP", value: "\(Int(game.totalXP))")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .parchmentCard()
    }

    private func statRow(symbol: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .foregroundStyle(SylvanTheme.forestGreen)
                .frame(width: 22)
            Text(label)
                .font(.stat(14, weight: .regular))
                .foregroundStyle(SylvanTheme.textOnParchmentSecondary)
            Spacer()
            Text(value)
                .font(.stat(14))
                .foregroundStyle(SylvanTheme.textOnParchment)
                .monospacedDigit()
        }
    }

    private var achievementsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Achievements")
                    .font(.display(18))
                    .foregroundStyle(SylvanTheme.textOnParchment)
                Spacer()
                Text("\(game.unlockedAchievements.count)/\(GameData.achievements.count)")
                    .font(.stat(13))
                    .foregroundStyle(SylvanTheme.textOnParchmentSecondary)
                    .monospacedDigit()
            }

            FlowLayout(horizontalSpacing: 10, verticalSpacing: 12) {
                ForEach(GameData.achievements) { achievement in
                    AchievementBadge(
                        achievement: achievement,
                        unlocked: game.unlockedAchievements.contains(achievement.id)
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .parchmentCard()
    }
}

struct AchievementBadge: View {
    let achievement: AchievementDef
    let unlocked: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(unlocked ? SylvanTheme.heroGradient : LinearGradient(
                        colors: [SylvanTheme.locked, SylvanTheme.locked.opacity(0.7)],
                        startPoint: .top, endPoint: .bottom
                    ))
                Circle()
                    .stroke(unlocked ? SylvanTheme.gold : SylvanTheme.locked, lineWidth: 2)
                Image(systemName: unlocked ? achievement.symbol : "lock.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(unlocked ? 1 : 0.7))
            }
            .frame(width: 52, height: 52)

            Text(achievement.name)
                .font(.stat(10))
                .foregroundStyle(
                    unlocked ? SylvanTheme.textOnParchment : SylvanTheme.textOnParchmentSecondary
                )
                .lineLimit(1)
        }
        .frame(width: 76)
        .opacity(unlocked ? 1 : 0.55)
        .help(achievement.detail)
    }
}
