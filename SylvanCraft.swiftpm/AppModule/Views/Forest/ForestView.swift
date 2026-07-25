import SwiftUI

/// The core gameplay screen: scrolling open world with a player character,
/// procedurally generated trees, proximity-based chopping, floating XP
/// drops, HUD bar (level, XP, gold, pack, stamina), and a frosted
/// in-scene overlay (minimap, Inventory/Skills shortcuts).
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
                    // Drag-to-move attaches to the scene itself (not the
                    // ZStack) so overlay buttons stay clean tap targets.
                    ForestSceneView(hudBridge: hudBridge)
                        .playerMovement()

                    // Chop/dwell progress ring above whichever tree is
                    // relevant, projected from 3D by SceneHUDBridge.
                    if let point = hudBridge.screenPoint, let target = hudBridge.target {
                        ChopDwellOverlay(target: target, axeTier: game.equippedAxe)
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

                    // Minimap, top-trailing.
                    MinimapView()
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .zIndex(15)
                }
                .clipped()
                // Frosted materials must read as *white* glass even when the
                // device is in dark mode; the SCNView ignores this.
                .environment(\.colorScheme, .light)
            }
        }
        .background(SylvanTheme.hudBackground)
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

/// The single chop-depletion or dwell-approach indicator, positioned at
/// `SceneHUDBridge`'s projected screen point: a frosted disc holding the
/// equipped axe's art, wrapped in a green progress ring, with bold
/// "CHOPPING…" status text beneath.
private struct ChopDwellOverlay: View {
    let target: SceneHUDBridge.Target
    let axeTier: AxeTier

    var body: some View {
        switch target {
        case .chopping(let progress):
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .background(Circle().fill(SylvanTheme.hudPanelTint))
                        .overlay(Circle().strokeBorder(SylvanTheme.hudBorder, lineWidth: 1))
                        .frame(width: 56, height: 56)
                    AxeArt(tier: axeTier)
                        .scaleEffect(0.62)
                    ProgressRing(
                        progress: progress,
                        tint: SylvanTheme.hudStamina,
                        track: .white.opacity(0.5),
                        lineWidth: 6
                    )
                    .frame(width: 64, height: 64)
                }
                VStack(spacing: 0) {
                    Text("CHOPPING...")
                        .font(.stat(12, weight: .heavy))
                        .kerning(0.5)
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.stat(14, weight: .heavy))
                        .monospacedDigit()
                }
                .hudSceneLabel()
            }
            .allowsHitTesting(false)

        case .dwelling(let progress):
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.85), lineWidth: 2.5)
                    .frame(width: 72, height: 72)
                    .scaleEffect(0.7 + CGFloat(progress) * 0.25)
                    .opacity(0.9)
                    .animation(.easeInOut(duration: 0.3), value: progress)
                    .shadow(color: .black.opacity(0.25), radius: 2)
                ProgressRing(
                    progress: progress,
                    tint: SylvanTheme.hudStamina,
                    track: .white.opacity(0.5)
                )
                .frame(width: 28, height: 28)
                .background(Circle().fill(.ultraThinMaterial))
            }
            .allowsHitTesting(false)
        }
    }
}
