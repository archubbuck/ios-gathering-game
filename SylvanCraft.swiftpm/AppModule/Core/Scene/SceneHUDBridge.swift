import CoreGraphics
import SceneKit

/// Publishes the single on-screen projection of whichever tree currently
/// matters to the HUD — the tree being chopped, or the one the player is
/// dwelling near just before chopping starts. `GameState` only ever tracks
/// one such tree at a time (single-target proximity chopping), so there's
/// only ever one point to project per frame via `SCNView.projectPoint(_:)`,
/// not one per visible tree — this is what lets the old per-tree overlay
/// `ForEach` be retired.
@MainActor
final class SceneHUDBridge: ObservableObject {
    enum Target {
        case chopping(progress: Double)
        case dwelling(progress: Double)
    }

    @Published private(set) var screenPoint: CGPoint?
    @Published private(set) var target: Target?

    /// World-space height above a tree's base the ring should hover at.
    /// Fixed rather than per-species since it only needs to clear the
    /// canopy, not hug it exactly.
    private static let ringHeight: CGFloat = 90

    func update(game: GameState, scnView: SCNView?) {
        guard let scnView else {
            screenPoint = nil
            target = nil
            return
        }

        if let key = game.activeChopTreeKey,
           let tree = game.worldTrees.first(where: { $0.key == key })
        {
            project(tree.worldPosition, in: scnView)
            target = .chopping(progress: depletionProgress(for: tree))
            return
        }

        if let key = game.player.dwellTargetKey,
           let tree = game.worldTrees.first(where: { $0.key == key })
        {
            project(tree.worldPosition, in: scnView)
            target = .dwelling(progress: dwellProgress(for: game))
            return
        }

        screenPoint = nil
        target = nil
    }

    private func project(_ worldPosition: CGPoint, in scnView: SCNView) {
        let worldPoint = SceneKitConversions.vector(worldPosition, height: Self.ringHeight)
        let projected = scnView.projectPoint(worldPoint)
        screenPoint = CGPoint(
            x: SceneKitConversions.cgFloat(projected.x),
            y: SceneKitConversions.cgFloat(projected.y)
        )
    }

    private func depletionProgress(for tree: WorldTreeState) -> Double {
        let def = GameData.tree(for: tree.species)
        guard def.logsMax > 0 else { return 0 }
        return 1 - Double(tree.logsRemaining) / Double(def.logsMax)
    }

    private func dwellProgress(for game: GameState) -> Double {
        guard let start = game.player.dwellStart else { return 0 }
        return min(1, Date().timeIntervalSince(start) / GameData.dwellDuration)
    }
}
