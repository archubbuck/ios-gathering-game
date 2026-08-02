import Foundation
import CoreGraphics

/// Manages which chunks are loaded based on the player's world position.
enum ChunkManager {

    /// The set of chunk coordinates that should be loaded when the player
    /// is at the given world position.
    static func loadedChunkSet(around position: CGPoint) -> Set<ChunkCoord> {
        let chunkX = Int(floor(position.x / GameData.chunkSize))
        let chunkY = Int(floor(position.y / GameData.chunkSize))
        let r = GameData.chunkLoadRadius
        var set = Set<ChunkCoord>()
        for dx in -r...r {
            for dy in -r...r {
                set.insert(ChunkCoord(x: chunkX + dx, y: chunkY + dy))
            }
        }
        return set
    }

    /// Generate the initial batch of chunks on game start / reset.
    static func generateInitial(around position: CGPoint) -> [WorldTreeState] {
        let coords = loadedChunkSet(around: position)
        return coords.flatMap { WorldGenerator.generateChunk(coord: $0).trees }
    }

    /// Generate the initial batch of potion pickups on game start / reset.
    static func generateInitialPickups(around position: CGPoint) -> [PotionPickupState] {
        let coords = loadedChunkSet(around: position)
        return coords.flatMap { PickupGenerator.generate(for: $0) }
    }
}
