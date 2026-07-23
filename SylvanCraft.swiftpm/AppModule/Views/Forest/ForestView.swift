import SwiftUI

/// The core gameplay screen: scrolling open world with a player character,
/// procedurally generated trees, proximity-based chopping, floating XP
/// drops, HUD bar, and event log.
struct ForestView: View {
    @EnvironmentObject private var game: GameState
    @State private var levelUpBanner: Int?
    @State private var lastSeenLevel: Int?

    var body: some View {
        VStack(spacing: 0) {
            HUDBar()

            GeometryReader { geo in
                let size = geo.size

                ZStack {
                    // Sky
                    LinearGradient(
                        colors: [SylvanTheme.skyTop, SylvanTheme.skyBottom],
                        startPoint: .top, endPoint: .bottom
                    )

                    // Scrolling isometric ground.
                    IsometricGround(camera: game.camera, screenSize: size)
                        .frame(height: size.height * 0.85)
                        .frame(maxHeight: .infinity, alignment: .bottom)

                    // Visible trees (cull off-screen).
                    ForEach(visibleTrees(in: size)) { tree in
                        TreeNodeView(
                            tree: tree,
                            camera: game.camera,
                            screenSize: size
                        )
                    }

                    // Player character at fixed screen position.
                    let playerScreenPos = game.camera.playerScreenPoint(in: size)
                    PlayerView()
                        .position(playerScreenPos)
                        .zIndex(5)

                    // XP drop overlay above the active tree.
                    if let drop = game.lastXPDrop,
                       let key = game.activeChopTreeKey,
                       let activeTree = game.worldTrees.first(where: { $0.key == key })
                    {
                        let treeScreenPos = game.camera.screenPoint(
                            for: activeTree.worldPosition, in: size
                        )
                        XPDropOverlay(drop: drop)
                            .id(drop.id)
                            .position(
                                x: treeScreenPos.x,
                                y: treeScreenPos.y - 60
                            )
                            .zIndex(10)
                    }

                    // Level-up celebration banner.
                    if let level = levelUpBanner {
                        LevelUpBanner(level: level)
                            .zIndex(20)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }
                .clipped()
                // Drag-to-move attaches to the entire scene.
                .playerMovement()
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

    /// Filter world trees to only those visible on screen (with padding).
    private func visibleTrees(in size: CGSize) -> [WorldTreeState] {
        let cam = game.camera.center
        let pad: CGFloat = 300
        return game.worldTrees.filter { tree in
            let sx = (tree.worldPosition.x - cam.x) + size.width / 2
            let sy = (tree.worldPosition.y - cam.y) + size.height / 2
            return sx > -pad && sx < size.width + pad &&
                   sy > -pad && sy < size.height + pad
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
