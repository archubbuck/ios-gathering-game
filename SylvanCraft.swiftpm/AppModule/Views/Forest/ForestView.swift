import SwiftUI

/// The core gameplay screen: HUD, isometric forest scene with tappable
/// trees, floating XP drops, and the event log.
struct ForestView: View {
    @EnvironmentObject private var game: GameState

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
                }
                .clipped()
            }

            EventLogView(entries: game.eventLog)
        }
        .background(SylvanTheme.woodPanelBottom)
    }
}
