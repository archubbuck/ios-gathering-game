import Foundation
import CoreGraphics
import SceneKit

/// Streams ground tiles and world decorations around the player.
final class WorldTreeStreamer {
    private var groundTiles: [ChunkCoord: SCNNode] = [:]
    private var sceneRoot: SCNNode

    init(sceneRoot: SCNNode) {
        self.sceneRoot = sceneRoot
    }

    func update(playerPosition: CGPoint) {
        let currentChunk = chunkCoord(for: playerPosition)
        let desired = loadedChunks(around: currentChunk)

        for coord in desired where groundTiles[coord] == nil {
            let tile = GroundTileGenerator.makeTileNode(coord: coord)
            sceneRoot.addChildNode(tile)
            groundTiles[coord] = tile
        }

        let staleCoords = groundTiles.keys.filter { !desired.contains($0) }
        for coord in staleCoords {
            groundTiles[coord]?.removeFromParentNode()
            groundTiles.removeValue(forKey: coord)
        }
    }

    private func loadedChunks(around coord: ChunkCoord) -> Set<ChunkCoord> {
        let radius = GameData.chunkLoadRadius
        var set = Set<ChunkCoord>()
        for dx in -radius...radius {
            for dy in -radius...radius {
                set.insert(ChunkCoord(x: coord.x + dx, y: coord.y + dy))
            }
        }
        return set
    }

    private func chunkCoord(for position: CGPoint) -> ChunkCoord {
        ChunkCoord(
            x: Int(floor(position.x / GameData.chunkSize)),
            y: Int(floor(position.y / GameData.chunkSize))
        )
    }
}
