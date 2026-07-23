import SwiftUI

/// The core gameplay screen: HUD, isometric forest scene with tappable
/// trees, floating XP drops, and the event log.
struct ForestView: View {
    @EnvironmentObject private var game: GameState
    @State private var levelUpBanner: Int?
    @State private var lastSeenLevel: Int?

    var body: some View {
        VStack(spacing: 0) {
            HUDBar()

            GeometryReader { geo in
                ZStack {
                    LinearGradient(
                        colors: [SylvanTheme.skyTop, SylvanTheme.skyBottom],
                        startPoint: .top, endPoint: .bottom
                    )

                    IsometricGround()
                        .frame(height: geo.size.height * 0.85)
                        .frame(maxHeight: .infinity, alignment: .bottom)

                    ForEach(game.trees) { tree in
                        let slot = game.region.slots[tree.slotIndex]
                        TreeNodeView(
                            tree: tree,
                            slot: slot,
                            isActive: game.activeChopTreeID == tree.id,
                            isLocked: game.level < GameData.tree(for: tree.species).levelReq,
                            onTap: { game.tapTree(tree.id) }
                        )
                        .position(
                            x: slot.position.x * geo.size.width,
                            y: slot.position.y * geo.size.height
                        )
                        .zIndex(slot.position.y)
                    }

                    if let drop = game.lastXPDrop,
                        let activeID = game.activeChopTreeID,
                        game.trees.indices.contains(activeID)
                    {
                        let slot = game.region.slots[activeID]
                        XPDropOverlay(drop: drop)
                            .id(drop.id)
                            .position(
                                x: slot.position.x * geo.size.width,
                                y: slot.position.y * geo.size.height - 70 * slot.scale
                            )
                            .zIndex(10)
                    }
                    if let level = levelUpBanner {
                        LevelUpBanner(level: level)
                            .zIndex(20)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }
                .clipped()
            }

            EventLogView(entries: game.eventLog)
        }
        .background(SylvanTheme.woodPanelBottom)
        .onAppear {
            if lastSeenLevel == nil {
                lastSeenLevel = game.level
            }
        }
        .onChange(of: game.level) { newLevel in
            defer { lastSeenLevel = newLevel }
            guard let last = lastSeenLevel, newLevel > last else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                levelUpBanner = newLevel
            }
            Task {
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                withAnimation(.easeOut(duration: 0.5)) {
                    if levelUpBanner == newLevel {
                        levelUpBanner = nil
                    }
                }
            }
        }
    }
}

/// Celebration banner flashed over the scene on level-up.
private struct LevelUpBanner: View {
    let level: Int

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 22))
                .foregroundStyle(SylvanTheme.gold)
            Text("Level \(level)!")
                .font(.display(30))
                .foregroundStyle(SylvanTheme.gold)
            Text("Woodcutting")
                .font(.stat(13))
                .foregroundStyle(SylvanTheme.textOnWood.opacity(0.85))
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .woodPanel()
        .shadow(color: SylvanTheme.gold.opacity(0.5), radius: 18)
        .allowsHitTesting(false)
    }
}
