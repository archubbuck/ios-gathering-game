import CoreGraphics
import Foundation

/// Publishes the single on-screen position of whichever tree currently
/// matters to the HUD — the tree being chopped, or the one the player is
/// dwelling near just before chopping starts.
///
/// In the 2D scene there is no 3D projection: world coordinates are
/// converted to screen coordinates by a simple affine transform derived
/// from the camera centre, zoom level, and the viewport size that
/// `ForestSceneView` reports on each update.
@MainActor
final class SceneHUDBridge: ObservableObject {
    enum Target: Equatable {
        case chopping(progress: Double)
        case dwelling(progress: Double)
    }

    @Published private(set) var screenPoint: CGPoint?
    @Published private(set) var target: Target?

    /// The most recent viewport size, stored so `screenPoint` can be
    /// recomputed if it was set before the view had a non-zero frame.
    private var lastViewSize: CGSize = .zero

    /// Coalesces bursts of `update` calls into a single deferred publish
    /// so the bridge never fires a `@Published` change synchronously
    /// inside a SwiftUI view-update pass.
    private var publishScheduled = false
    private var pendingScreenPoint: CGPoint?
    private var pendingTarget: Target?

    /// Called every frame by `ForestSceneView.updateUIView`.
    func update(game: GameState, viewSize: CGSize) {
        if viewSize != .zero { lastViewSize = viewSize }
        let (newPoint, newTarget) = computeState(game: game, viewSize: lastViewSize)

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

    // MARK: - Private helpers

    private func computeState(game: GameState, viewSize: CGSize) -> (CGPoint?, Target?) {
        if let key = game.activeChopTreeKey,
           let tree = game.worldTrees.first(where: { $0.key == key })
        {
            let point = worldToScreen(tree.worldPosition, game: game, viewSize: viewSize)
            return (point, .chopping(progress: depletionProgress(for: tree)))
        }

        if let key = game.player.dwellTargetKey,
           let tree = game.worldTrees.first(where: { $0.key == key })
        {
            let point = worldToScreen(tree.worldPosition, game: game, viewSize: viewSize)
            return (point, .dwelling(progress: dwellProgress(for: game)))
        }

        return (nil, nil)
    }

    /// Converts a 2D world-space position to a screen-space point.
    ///
    /// The formula mirrors `ForestSceneView`'s camera setup:
    ///  - The viewport shows `baseVisibleWorldHeight / zoomScale` world
    ///    units vertically at any given zoom level.
    ///  - The camera is centred on `game.camera.center`.
    private func worldToScreen(_ worldPos: CGPoint, game: GameState, viewSize: CGSize) -> CGPoint? {
        guard viewSize.width > 0, viewSize.height > 0 else { return nil }

        let zoom = game.camera.zoomScale
        // Pixels per world unit at the current zoom level.
        let ppu = viewSize.height / (ForestSceneView.baseVisibleWorldHeight / zoom)

        let dx = worldPos.x - game.camera.center.x
        let dy = worldPos.y - game.camera.center.y

        return CGPoint(
            x: viewSize.width  / 2 + dx * ppu,
            y: viewSize.height / 2 + dy * ppu
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
