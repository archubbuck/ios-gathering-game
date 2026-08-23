import CoreGraphics
import Foundation

/// Ground-tile streaming helper. SceneKit node management has been removed
/// in the 2D conversion; `ForestSceneView.Coordinator` now handles tile
/// lifecycle directly using `SKSpriteNode`s.
final class WorldTreeStreamer {
    private var loadedCoords = Set<ChunkCoord>()

    /// Returns the set of chunk coordinates that should be loaded for the
    /// given player position (identical logic as `ChunkManager`).
    func desiredCoords(for playerPosition: CGPoint) -> Set<ChunkCoord> {
        ChunkManager.loadedChunkSet(around: playerPosition)
    }
}
