import CoreGraphics
import Foundation

/// World-position helper retained for reference; the ground tile mesh
/// builders that required SceneKit/RealityKit have been removed in the
/// 2D conversion. `ForestSceneView` now creates `SKSpriteNode` ground
/// tiles directly.
enum GroundTileGenerator {
    static let tileSize: CGFloat = GameData.chunkSize

    static func worldPosition(for coord: ChunkCoord) -> CGPoint {
        CGPoint(
            x: CGFloat(coord.x) * tileSize + tileSize / 2,
            y: CGFloat(coord.y) * tileSize + tileSize / 2
        )
    }
}
