import SwiftUI

/// The core gameplay screen: scrolling open world with a player character,
/// procedurally generated trees, proximity-based chopping, floating XP
/// drops, HUD bar, and event log.
struct ForestView: View {
    @EnvironmentObject private var game: GameState
    @StateObject private var hudBridge = SceneHUDBridge()
    @State private var levelUpBanner: Int?
    @State private var lastSeenLevel: Int?

    var body: some View {
        VStack(spacing: 0) {
            HUDBar()

            GeometryReader { _ in
                ZStack {
                    // Low-poly 3D forest scene: ground, trees, and player.
                    ForestSceneView(hudBridge: hudBridge)

                    // Chop/dwell progress ring above whichever tree is
                    // relevant, projected from 3D by SceneHUDBridge.
                    if let point = hudBridge.screenPoint, let target = hudBridge.target {
                        ChopDwellOverlay(target: target)
                            .position(point)
                            .zIndex(9)
                    }

                    // XP drop overlay above the active tree.
                    if let drop = game.lastXPDrop, let point = hudBridge.screenPoint {
                        XPDropOverlay(drop: drop)
                            .id(drop.id)
                            .position(x: point.x, y: point.y - 20)
                            .zIndex(10)
                    }

                    // Level-up celebration banner.
                    if let level = levelUpBanner {
                        LevelUpBanner(level: level)
                            .zIndex(20)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }

                    // HP/Stamina vitals, top-leading.
                    VStack(alignment: .leading, spacing: 6) {
                        HPBar(hp: game.hp, maxHP: GameData.maxHP)
                        StaminaBar(stamina: game.stamina, maxStamina: GameData.maxStamina)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .allowsHitTesting(false)
                    .zIndex(15)

                    // Minimap, top-trailing.
                    MinimapView()
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .zIndex(15)
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

/// The single chop-depletion or dwell-approach ring, positioned by
/// `SceneHUDBridge`'s projected screen point. Mirrors the pre-3D
/// `TreeNodeView`'s `ProgressRing` conventions.
private struct ChopDwellOverlay: View {
    let target: SceneHUDBridge.Target

    var body: some View {
        switch target {
        case .chopping(let progress):
            ProgressRing(progress: progress)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.black.opacity(0.25)))

        case .dwelling(let progress):
            ZStack {
                Circle()
                    .stroke(SylvanTheme.gold, lineWidth: 2.5)
                    .frame(width: 72, height: 72)
                    .scaleEffect(0.7 + CGFloat(progress) * 0.25)
                    .opacity(0.9)
                    .animation(.easeInOut(duration: 0.3), value: progress)
                ProgressRing(progress: progress)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.black.opacity(0.2)))
            }
        }
    }
}
