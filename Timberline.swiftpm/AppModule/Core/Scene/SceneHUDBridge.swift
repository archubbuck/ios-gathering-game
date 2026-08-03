import ARKit
import CoreGraphics
import RealityKit
import SceneKit

/// Publishes the single on-screen projection of whichever tree currently
/// matters to the HUD — the tree being chopped, or the one the player is
/// dwelling near just before chopping starts.
@MainActor
final class SceneHUDBridge: ObservableObject {
    enum Target: Equatable {
        case chopping(progress: Double)
        case dwelling(progress: Double)
    }

    @Published private(set) var screenPoint: CGPoint?
    @Published private(set) var target: Target?

    /// World-space height above a tree's base the ring should hover at.
    /// Fixed rather than per-species since it only needs to clear the
    /// canopy, not hug it exactly.
    private static let ringHeight: CGFloat = 90

    /// True once an `update(game:scnView:)` call has computed values that
    /// differ from what's published and scheduled the actual publish for
    /// the next run-loop turn. Coalesces bursts of `updateUIView` calls
    /// (which can fire faster than once per display refresh) into a
    /// single deferred publish, and guarantees the publish never happens
    /// synchronously inside a SwiftUI view-update pass — doing so there
    /// would re-invalidate this bridge's observers mid-update.
    private var publishScheduled = false
    private var pendingScreenPoint: CGPoint?
    private var pendingTarget: Target?

    func update(game: GameState, scnView: SCNView? = nil, arView: ARView? = nil) {
        let (newPoint, newTarget) = computeState(game: game, scnView: scnView, arView: arView)

        guard newPoint != screenPoint || newTarget != target else { return }

        pendingScreenPoint = newPoint
        pendingTarget = newTarget
        guard !publishScheduled else { return }
        publishScheduled = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.publishScheduled = false
            self.screenPoint = self.pendingScreenPoint
            self.target = self.pendingTarget
        }
    }

    private func computeState(game: GameState, scnView: SCNView?, arView: ARView?) -> (CGPoint?, Target?) {
        if let key = game.activeChopTreeKey,
           let tree = game.worldTrees.first(where: { $0.key == key })
        {
            let point = project(tree.worldPosition, in: scnView, arView: arView)
            return (point, .chopping(progress: depletionProgress(for: tree)))
        }

        if let key = game.player.dwellTargetKey,
           let tree = game.worldTrees.first(where: { $0.key == key })
        {
            let point = project(tree.worldPosition, in: scnView, arView: arView)
            return (point, .dwelling(progress: dwellProgress(for: game)))
        }

        return (nil, nil)
    }

    private func project(_ worldPosition: CGPoint, in scnView: SCNView?, arView: ARView?) -> CGPoint? {
        if let arView {
            let projected = arView.project(SIMD3<Float>(Float(worldPosition.x), Float(Self.ringHeight), Float(worldPosition.y)))
            return CGPoint(x: projected.x, y: projected.y)
        }

        guard let scnView else { return nil }
        let worldPoint = SceneKitConversions.vector(worldPosition, height: Self.ringHeight)
        let projected = scnView.projectPoint(worldPoint)
        return CGPoint(
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
