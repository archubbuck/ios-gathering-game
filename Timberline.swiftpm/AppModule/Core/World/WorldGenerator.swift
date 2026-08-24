import Foundation
import CoreGraphics

/// Deterministic chunk generation. Same seed + coord → same layout.
enum WorldGenerator {

    /// Generate all trees for a given chunk coordinate.
    static func generateChunk(coord: ChunkCoord) -> Chunk {
        let chunkOriginX = CGFloat(coord.x) * GameData.chunkSize
        let chunkOriginY = CGFloat(coord.y) * GameData.chunkSize

        // Seed for this chunk is a mix of world seed and chunk coords.
        let chunkSeed = hash(coord)
        var rng = SeededRandom(seed: chunkSeed)

        // Determine eligible species for this chunk's center distance.
        let centerX = chunkOriginX + GameData.chunkSize / 2
        let centerY = chunkOriginY + GameData.chunkSize / 2
        let distFromOrigin = hypot(centerX, centerY)
        let eligible = GameData.eligibleSpecies(atDistance: distFromOrigin)

        var trees: [WorldTreeState] = []
        var clusterCenters: [CGPoint] = []

        let patchNoise = SeededNoise2D(seed: combineSeed(GameData.worldSeed, coord: coord))
        for clusterIdx in 0..<GameData.clustersPerChunk {
            // Find a cluster center that doesn't overlap existing ones.
            let center = findClusterCenter(
                in: CGSize(width: GameData.chunkSize, height: GameData.chunkSize),
                rng: &rng,
                existingCenters: clusterCenters
            )
            clusterCenters.append(center)

            let species = pickSpecies(from: eligible, coord: coord, center: center, noise: patchNoise)
            let def = GameData.tree(for: species)
            let treeCount = clusterTreeCount(baseRng: &rng, noise: patchNoise, center: center)

            for treeIdx in 0..<treeCount {
                // Scatter trees around the cluster center.
                let angle = rng.nextCGFloat() * .pi * 2
                let radius = rng.nextCGFloat() * 140 + 20
                let tx = center.x + cos(angle) * radius
                let ty = center.y + sin(angle) * radius

                // Keep within chunk bounds (allow slight bleeding for edge clusters).
                let clampedX = max(10, min(GameData.chunkSize - 10, tx))
                let clampedY = max(10, min(GameData.chunkSize - 10, ty))

                let worldPos = CGPoint(
                    x: chunkOriginX + clampedX,
                    y: chunkOriginY + clampedY
                )

                let key = "\(coord.x):\(coord.y):\(clusterIdx):\(treeIdx)"
                let deadlineStamp = WorldSaveStore.current.felledTreeDeadlines[key]
                let respawnUntil: Date? = deadlineStamp.map { Date(timeIntervalSince1970: $0) }
                let isFelled = respawnUntil.map { $0 > Date() } ?? false
                trees.append(WorldTreeState(
                    key: key,
                    species: species,
                    worldPosition: worldPos,
                    logsRemaining: isFelled ? 0 : Int(randomIn: def.logsMin...def.logsMax, using: &rng),
                    respawnUntil: isFelled ? respawnUntil : nil,
                    clusterID: "\(coord.x):\(coord.y):\(clusterIdx)"
                ))
            }
        }

        return Chunk(coord: coord, trees: trees)
    }

    // MARK: - Private helpers

    /// Unstable hash mixing chunk x/y into a UInt64 seed.
    private static func hash(_ coord: ChunkCoord) -> UInt64 {
        var h = GameData.worldSeed
        h = h &* 0x9E3779B97F4A7C15 &+ UInt64(bitPattern: Int64(coord.x))
        h = h &* 0x9E3779B97F4A7C15 &+ UInt64(bitPattern: Int64(coord.y))
        return h
    }

    /// Pick a species — early-game species are more common near origin.
    private static func pickSpecies(from eligible: [TreeSpecies],
                                    coord: ChunkCoord,
                                    center: CGPoint,
                                    noise: SeededNoise2D) -> TreeSpecies {
        guard !eligible.isEmpty else { return .birch }
        let absoluteX = CGFloat(coord.x) * GameData.chunkSize + center.x
        let absoluteY = CGFloat(coord.y) * GameData.chunkSize + center.y
        let patchValue = noise.noise(
            x: absoluteX / 2600,
            y: absoluteY / 2600
        )
        let index = min(eligible.count - 1,
                        Int((patchValue * Double(eligible.count)).rounded(.down)))
        return eligible[index]
    }

    private static func clusterTreeCount(baseRng: inout SeededRandom,
                                         noise: SeededNoise2D,
                                         center: CGPoint) -> Int {
        let absoluteX = center.x
        let absoluteY = center.y
        let density = 0.75 + noise.noise(x: absoluteX / 2200, y: absoluteY / 2200) * 0.5
        let baseCount = Int.random(in: GameData.treesPerClusterRange, using: &baseRng)
        let count = Int((Double(baseCount) * density).rounded())
        return min(GameData.treesPerClusterRange.upperBound,
                   max(GameData.treesPerClusterRange.lowerBound, count))
    }

    private static func combineSeed(_ seed: UInt64, coord: ChunkCoord) -> UInt64 {
        var h = seed ^ 0xC0FFEE_BABE_DEADBE
        h = h &* 0x9E3779B97F4A7C15 &+ UInt64(bitPattern: Int64(coord.x))
        h = h &* 0x9E3779B97F4A7C15 &+ UInt64(bitPattern: Int64(coord.y))
        return h
    }

    /// Find a random point that doesn't overlap existing cluster centers.
    private static func findClusterCenter(in size: CGSize,
                                          rng: inout SeededRandom,
                                          existingCenters: [CGPoint]) -> CGPoint {
        let margin: CGFloat = 60
        for _ in 0..<50 {
            let x = rng.nextCGFloat() * (size.width - margin * 2) + margin
            let y = rng.nextCGFloat() * (size.height - margin * 2) + margin
            let point = CGPoint(x: x, y: y)
            let tooClose = existingCenters.contains { existing in
                hypot(existing.x - point.x, existing.y - point.y) < GameData.clusterMinSeparation
            }
            if !tooClose { return point }
        }
        // Fallback: just pick something.
        return CGPoint(
            x: rng.nextCGFloat() * (size.width - margin * 2) + margin,
            y: rng.nextCGFloat() * (size.height - margin * 2) + margin
        )
    }
}

// MARK: - SeededRandom (extracted from MapView.swift)

/// Deterministic pseudo-random stream for reproducible world generation.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &* 0x9E3779B97F4A7C15 &+ 1
    }

    /// `RandomNumberGenerator` conformance — returns a UInt64.
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        // Use the full state; rotate for good distribution.
        var x = state
        x ^= x >> 33
        x &*= 0xFF51AFD7ED558CCD
        x ^= x >> 33
        x &*= 0xC4CEB9FE1A85EC53
        x ^= x >> 33
        return x
    }

    /// Convenience: returns a CGFloat in [0, 1).
    mutating func nextCGFloat() -> CGFloat {
        CGFloat(next() >> 11) / CGFloat(UInt64.max >> 11)
    }
}

extension Int {
    /// Random integer in range using SeededRandom.
    init(randomIn range: ClosedRange<Int>, using rng: inout SeededRandom) {
        let count = range.upperBound - range.lowerBound + 1
        // `nextCGFloat()` can return exactly 1.0, which would otherwise
        // produce `range.upperBound + 1` — clamp to stay in range. Uses
        // `Swift.min` because unqualified `min` inside `extension Int`
        // resolves to the `Int.min` static property, not the free
        // function `min(_:_:)`.
        let offset = Swift.min(Int(rng.nextCGFloat() * CGFloat(count)), count - 1)
        self = range.lowerBound + offset
    }
}
