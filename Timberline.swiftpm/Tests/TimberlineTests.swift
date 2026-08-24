import XCTest
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Re-export types for testing
// The test target cannot import AppModule directly (it's an executableTarget),
// so the key data-layer types are duplicated/stubbed below at minimum fidelity
// to let us test pure-logic invariants without iOS-only dependencies.

// ---------------------------------------------------------------------------
// MARK: SplitMix64 determinism
// ---------------------------------------------------------------------------

/// Mirrors AppModule/Core/World/WorldSave.swift
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z = z ^ (z >> 31)
        return z
    }
}

class SplitMix64Tests: XCTestCase {

    /// Given the same seed, SplitMix64 must always produce the same sequence.
    func testDeterministicOutput() {
        var rng1 = SplitMix64(seed: 0xDEAD_BEEF_CAFE_1234)
        var rng2 = SplitMix64(seed: 0xDEAD_BEEF_CAFE_1234)
        for _ in 0..<1000 {
            XCTAssertEqual(rng1.next(), rng2.next())
        }
    }

    /// Different seeds must produce different first outputs.
    func testDifferentSeeds() {
        var a = SplitMix64(seed: 1)
        var b = SplitMix64(seed: 2)
        XCTAssertNotEqual(a.next(), b.next())
    }

    /// newWorld seed uses SystemRandomNumberGenerator — two calls must produce
    /// different seeds with extremely high probability.
    func testNewWorldSeedIsRandom() {
        var sys1 = SystemRandomNumberGenerator()
        var sys2 = SystemRandomNumberGenerator()
        let seed1 = UInt64.random(in: .min ... .max, using: &sys1)
        let seed2 = UInt64.random(in: .min ... .max, using: &sys2)
        // With a 64-bit uniform distribution the chance of collision is ~5e-19.
        XCTAssertNotEqual(seed1, seed2,
            "Two system-random seeds must differ; collision is astronomically unlikely")
    }
}

// ---------------------------------------------------------------------------
// MARK: WorldSave – felled-tree deadline persistence
// ---------------------------------------------------------------------------

/// Minimal WorldSave mirror for Codable round-trip tests.
struct WorldSaveStub: Codable, Equatable {
    var schemaVersion: Int = 2
    var worldSeed: UInt64
    var felledTreeDeadlines: [String: TimeInterval] = [:]
}

class WorldSaveDeadlineTests: XCTestCase {

    func testDeadlineRoundTrip() throws {
        let now = Date().timeIntervalSince1970
        var save = WorldSaveStub(worldSeed: 42)
        save.felledTreeDeadlines["0:0:1:2"] = now + 30
        save.felledTreeDeadlines["1:1:0:0"] = now + 120

        let data = try JSONEncoder().encode(save)
        let decoded = try JSONDecoder().decode(WorldSaveStub.self, from: data)

        XCTAssertEqual(decoded.felledTreeDeadlines["0:0:1:2"]!, now + 30, accuracy: 0.001)
        XCTAssertEqual(decoded.felledTreeDeadlines["1:1:0:0"]!, now + 120, accuracy: 0.001)
        XCTAssertEqual(decoded.worldSeed, 42)
    }

    func testEmptyDeadlines() throws {
        let save = WorldSaveStub(worldSeed: 99)
        let data = try JSONEncoder().encode(save)
        let decoded = try JSONDecoder().decode(WorldSaveStub.self, from: data)
        XCTAssertTrue(decoded.felledTreeDeadlines.isEmpty)
    }

    func testExpiredDeadlineIsInPast() {
        let past = Date().addingTimeInterval(-1).timeIntervalSince1970
        // A deadline in the past means the tree has respawned.
        let respawnUntil = Date(timeIntervalSince1970: past)
        XCTAssertTrue(respawnUntil <= Date(), "Past deadline should mean tree is live")
    }

    func testFutureDeadlineIsStillFelled() {
        let future = Date().addingTimeInterval(60).timeIntervalSince1970
        let respawnUntil = Date(timeIntervalSince1970: future)
        XCTAssertTrue(respawnUntil > Date(), "Future deadline should mean tree is still a stump")
    }
}

// ---------------------------------------------------------------------------
// MARK: PlayerSave – clamping via repaired()
// ---------------------------------------------------------------------------

/// Minimal PlayerSave mirror for repair tests.
struct PlayerSaveStub {
    var totalXP: Double
    var gold: Int
    var inventoryCount: Int
    var ownedAxes: Set<String>
    var equippedAxe: String
    var positionX: Double
    var positionY: Double

    enum RepairError { case negativeXP, negativeGold, invalidInventory,
                                emptyAxes, unownedEquipped, nonFinitePosition }

    func repairErrors() -> [RepairError] {
        var errors: [RepairError] = []
        if totalXP < 0 { errors.append(.negativeXP) }
        if gold < 0 { errors.append(.negativeGold) }
        if inventoryCount != 28 { errors.append(.invalidInventory) }
        if ownedAxes.isEmpty { errors.append(.emptyAxes) }
        if !ownedAxes.contains(equippedAxe) { errors.append(.unownedEquipped) }
        if !positionX.isFinite || !positionY.isFinite { errors.append(.nonFinitePosition) }
        return errors
    }

    func repaired() -> PlayerSaveStub {
        var s = self
        s.totalXP = max(0, totalXP)
        s.gold = max(0, gold)
        s.inventoryCount = 28
        if s.ownedAxes.isEmpty { s.ownedAxes = ["bronze"] }
        if !s.ownedAxes.contains(s.equippedAxe) { s.equippedAxe = "bronze" }
        if !s.positionX.isFinite { s.positionX = 0 }
        if !s.positionY.isFinite { s.positionY = 0 }
        return s
    }
}

class PlayerSaveRepairTests: XCTestCase {

    func testNegativeXPClamped() {
        let bad = PlayerSaveStub(totalXP: -500, gold: 0, inventoryCount: 28,
                                  ownedAxes: ["bronze"], equippedAxe: "bronze",
                                  positionX: 0, positionY: 0)
        let fixed = bad.repaired()
        XCTAssertEqual(fixed.totalXP, 0)
    }

    func testNegativeGoldClamped() {
        let bad = PlayerSaveStub(totalXP: 0, gold: -100, inventoryCount: 28,
                                  ownedAxes: ["bronze"], equippedAxe: "bronze",
                                  positionX: 0, positionY: 0)
        XCTAssertEqual(bad.repaired().gold, 0)
    }

    func testInventoryPadded() {
        let bad = PlayerSaveStub(totalXP: 0, gold: 0, inventoryCount: 5,
                                  ownedAxes: ["bronze"], equippedAxe: "bronze",
                                  positionX: 0, positionY: 0)
        XCTAssertEqual(bad.repaired().inventoryCount, 28)
    }

    func testEmptyAxesDefaultsBronze() {
        let bad = PlayerSaveStub(totalXP: 0, gold: 0, inventoryCount: 28,
                                  ownedAxes: [], equippedAxe: "bronze",
                                  positionX: 0, positionY: 0)
        let fixed = bad.repaired()
        XCTAssertTrue(fixed.ownedAxes.contains("bronze"))
    }

    func testUnownedEquippedAxeFallsBack() {
        let bad = PlayerSaveStub(totalXP: 0, gold: 0, inventoryCount: 28,
                                  ownedAxes: ["bronze"], equippedAxe: "dragon",
                                  positionX: 0, positionY: 0)
        let fixed = bad.repaired()
        XCTAssertTrue(fixed.ownedAxes.contains(fixed.equippedAxe))
    }

    func testNonFinitePositionClamped() {
        let bad = PlayerSaveStub(totalXP: 0, gold: 0, inventoryCount: 28,
                                  ownedAxes: ["bronze"], equippedAxe: "bronze",
                                  positionX: .nan, positionY: .infinity)
        let fixed = bad.repaired()
        XCTAssertTrue(fixed.positionX.isFinite)
        XCTAssertTrue(fixed.positionY.isFinite)
    }

    func testValidSavePassesWithNoErrors() {
        let good = PlayerSaveStub(totalXP: 1000, gold: 500, inventoryCount: 28,
                                   ownedAxes: ["bronze", "iron"], equippedAxe: "iron",
                                   positionX: 300, positionY: -200)
        XCTAssertTrue(good.repairErrors().isEmpty)
    }
}

// ---------------------------------------------------------------------------
// MARK: WorldSave – save/load with corrupt primary, healthy backup
// ---------------------------------------------------------------------------

class WorldSavePersistenceTests: XCTestCase {

    private var dir: URL!

    override func setUp() {
        super.setUp()
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimberlineTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    private func saveURL() -> URL { dir.appendingPathComponent("world.json") }
    private func backupURL() -> URL { dir.appendingPathComponent("world.bak") }

    private func write(_ save: WorldSaveStub, to url: URL) throws {
        let data = try JSONEncoder().encode(save)
        try data.write(to: url, options: .atomic)
    }

    private func load() -> WorldSaveStub? {
        // Mirrors WorldSaveStore.load() logic.
        if let data = try? Data(contentsOf: saveURL()),
           let save = try? JSONDecoder().decode(WorldSaveStub.self, from: data) {
            return save
        }
        if let data = try? Data(contentsOf: backupURL()),
           let save = try? JSONDecoder().decode(WorldSaveStub.self, from: data) {
            return save
        }
        return nil
    }

    func testHealthyPrimaryLoads() throws {
        let expected = WorldSaveStub(worldSeed: 12345)
        try write(expected, to: saveURL())
        let loaded = load()
        XCTAssertEqual(loaded?.worldSeed, 12345)
    }

    func testCorruptPrimaryFallsBackToBackup() throws {
        let backup = WorldSaveStub(worldSeed: 99999)
        try write(backup, to: backupURL())
        // Write corrupt data to primary.
        try "not json at all!!".data(using: .utf8)!.write(to: saveURL())
        let loaded = load()
        XCTAssertEqual(loaded?.worldSeed, 99999, "Should fall back to backup")
    }

    func testBothCorruptReturnsNil() throws {
        try "bad".data(using: .utf8)!.write(to: saveURL())
        try "bad".data(using: .utf8)!.write(to: backupURL())
        XCTAssertNil(load(), "Both corrupt should return nil (fresh world)")
    }

    func testMissingSchemaVersionDecodesWithDefault() throws {
        // Encode a JSON object without schemaVersion.
        let json = """
        {"worldSeed": 55555, "felledTreeDeadlines": {}}
        """.data(using: .utf8)!
        try json.write(to: saveURL())
        let loaded = try JSONDecoder().decode(WorldSaveStub.self, from: json)
        XCTAssertEqual(loaded.worldSeed, 55555)
        XCTAssertEqual(loaded.schemaVersion, 2, "Default schema version should be 2")
    }

    func testWipeProducesFreshSave() throws {
        let original = WorldSaveStub(worldSeed: 1111)
        try write(original, to: saveURL())
        // Simulate wipe.
        try FileManager.default.removeItem(at: saveURL())
        try? FileManager.default.removeItem(at: backupURL())
        XCTAssertNil(load(), "After wipe, load should return nil so a new world is created")
    }

    func testDeadlineRoundTripSurvivesDiskWrite() throws {
        let deadline = Date().addingTimeInterval(300).timeIntervalSince1970
        var save = WorldSaveStub(worldSeed: 7777)
        save.felledTreeDeadlines["3:4:2:1"] = deadline
        try write(save, to: saveURL())
        let loaded = load()
        XCTAssertEqual(loaded?.felledTreeDeadlines["3:4:2:1"], deadline, accuracy: 0.001)
    }
}

// ---------------------------------------------------------------------------
// MARK: SeededNoise / chunk determinism
// ---------------------------------------------------------------------------

/// Minimal SeededNoise2D mirror for determinism tests.
struct SeededNoise2D {
    private let seed: UInt64

    init(seed: UInt64) { self.seed = seed }

    func noise(x: Double, y: Double) -> Double {
        // Simplified: just verify same input → same output.
        var h = seed
        h ^= UInt64(bitPattern: Int64(x * 1000))
        h ^= UInt64(bitPattern: Int64(y * 1000)) &* 0x9E3779B97F4A7C15
        h = h ^ (h >> 30)
        h &*= 0xBF58476D1CE4E5B9
        // Return normalised to [0, 1).
        return Double(h >> 11) / Double(UInt64.max >> 11)
    }
}

class ChunkDeterminismTests: XCTestCase {

    func testSameNoiseInputsProduceSameOutput() {
        let noise = SeededNoise2D(seed: 0xABCD1234)
        let v1 = noise.noise(x: 1.5, y: 2.5)
        let v2 = noise.noise(x: 1.5, y: 2.5)
        XCTAssertEqual(v1, v2)
    }

    func testDifferentInputsProduceDifferentOutput() {
        let noise = SeededNoise2D(seed: 0xABCD1234)
        let v1 = noise.noise(x: 1.5, y: 2.5)
        let v2 = noise.noise(x: 2.5, y: 1.5)
        XCTAssertNotEqual(v1, v2)
    }

    func testChunkHashDeterministic() {
        // Verify the chunk hash formula (from WorldGenerator) gives consistent output.
        func chunkHash(worldSeed: UInt64, x: Int, y: Int) -> UInt64 {
            var h = worldSeed
            h = h &* 0x9E3779B97F4A7C15 &+ UInt64(bitPattern: Int64(x))
            h = h &* 0x9E3779B97F4A7C15 &+ UInt64(bitPattern: Int64(y))
            return h
        }
        let h1 = chunkHash(worldSeed: 12345, x: 3, y: -2)
        let h2 = chunkHash(worldSeed: 12345, x: 3, y: -2)
        XCTAssertEqual(h1, h2)
    }

    func testDifferentWorldSeedsProduceDifferentChunks() {
        func chunkHash(worldSeed: UInt64, x: Int, y: Int) -> UInt64 {
            var h = worldSeed
            h = h &* 0x9E3779B97F4A7C15 &+ UInt64(bitPattern: Int64(x))
            h = h &* 0x9E3779B97F4A7C15 &+ UInt64(bitPattern: Int64(y))
            return h
        }
        let h1 = chunkHash(worldSeed: 111, x: 0, y: 0)
        let h2 = chunkHash(worldSeed: 222, x: 0, y: 0)
        XCTAssertNotEqual(h1, h2)
    }
}

// ---------------------------------------------------------------------------
// MARK: Coordinate boundary clamping
// ---------------------------------------------------------------------------

class CoordinateBoundaryTests: XCTestCase {

    /// Tree positions must be within chunk bounds (from WorldGenerator logic).
    func testTreePositionClampedToChunk() {
        let chunkSize: Double = 1200
        let margin: Double = 10

        // Simulate the clamp logic from WorldGenerator.generateChunk.
        func clamped(_ v: Double) -> Double {
            max(margin, min(chunkSize - margin, v))
        }

        XCTAssertEqual(clamped(-50), margin)
        XCTAssertEqual(clamped(1300), chunkSize - margin)
        XCTAssertEqual(clamped(600), 600)
    }

    /// Player position must be finite after repair.
    func testNaNPositionRepaired() {
        var pos = (x: Double.nan, y: Double.infinity)
        if !pos.x.isFinite { pos.x = 0 }
        if !pos.y.isFinite { pos.y = 0 }
        XCTAssertEqual(pos.x, 0)
        XCTAssertEqual(pos.y, 0)
    }
}
