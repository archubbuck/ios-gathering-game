import RealityKit
import SwiftUI
import UIKit

/// Builds a reusable ground tile plane for the RealityKit scene.
enum GroundTileGenerator {
    static let tileSize: CGFloat = GameData.chunkSize
    static let textureRepeatCount: CGFloat = 8

    static func makeTileEntity(coord: ChunkCoord) -> ModelEntity {
        let material = SimpleMaterial(
            color: UIColor(TimberlineTheme.Scene3D.dirt),
            roughness: 0.95,
            isMetallic: false
        )

        let mesh = MeshResource.generatePlane(width: Float(tileSize), height: Float(tileSize))
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = SIMD3<Float>(
            Float(worldPosition(for: coord).x),
            -0.01,
            Float(worldPosition(for: coord).y)
        )
        entity.transform.rotation = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))
        entity.name = "groundTile"
        return entity
    }

    static func worldPosition(for coord: ChunkCoord) -> CGPoint {
        CGPoint(
            x: CGFloat(coord.x) * tileSize + tileSize / 2,
            y: CGFloat(coord.y) * tileSize + tileSize / 2
        )
    }
}
