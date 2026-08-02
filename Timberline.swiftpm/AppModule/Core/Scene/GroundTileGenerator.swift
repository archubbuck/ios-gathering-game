import SceneKit
import SwiftUI
import UIKit

/// Builds a reusable ground tile plane with a tiled grass texture.
enum GroundTileGenerator {
    static let tileSize: CGFloat = GameData.chunkSize
    static let textureRepeatCount: CGFloat = 8

    static func makeTileNode(coord: ChunkCoord) -> SCNNode {
        let plane = SCNPlane(width: tileSize, height: tileSize)
        plane.firstMaterial = tileMaterial()
        plane.firstMaterial?.isDoubleSided = true

        let node = SCNNode(geometry: plane)
        node.name = "groundTile"
        node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        node.position = SceneKitConversions.vector(worldPosition(for: coord))
        node.castsShadow = false
        node.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: plane, options: nil))
        node.physicsBody?.categoryBitMask = 0x1
        node.physicsBody?.collisionBitMask = 0x1
        node.physicsBody?.contactTestBitMask = 0x1
        return node
    }

    private static func tileMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.isDoubleSided = true
        if let image = UIImage(named: "Grass_Tileable", in: Bundle.module, with: nil) {
            material.diffuse.contents = image
        } else {
            material.diffuse.contents = TimberlineTheme.Scene3D.dirt
        }
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .repeat
        material.diffuse.contentsTransform = SCNMatrix4MakeScale(
            Float(textureRepeatCount),
            Float(textureRepeatCount),
            1
        )
        material.diffuse.mipFilter = .linear
        material.diffuse.magnificationFilter = .linear
        material.roughness.contents = 0.9
        material.metalness.contents = 0.0
        material.locksAmbientWithDiffuse = true
        return material
    }

    static func worldPosition(for coord: ChunkCoord) -> CGPoint {
        CGPoint(
            x: CGFloat(coord.x) * tileSize + tileSize / 2,
            y: CGFloat(coord.y) * tileSize + tileSize / 2
        )
    }
}
