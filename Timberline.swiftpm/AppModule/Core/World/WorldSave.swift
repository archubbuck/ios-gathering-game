import Foundation

/// Persisted world state for Timberline: a fixed world seed and the
/// set of felled tree IDs that should remain stumps across launches.
struct WorldSave: Codable {
    // Keep a literal default so decoding older/missing-key payloads can
    // still materialize a valid save without touching WorldSaveStore
    // during static initialization.
    var schemaVersion: Int = 1
    var worldSeed: UInt64
    var felledTreeIDs: Set<String> = []

    static var newWorld: WorldSave {
        var rng = SplitMix64(seed: 0xC0FFEE_BABE_DEADBE)
        let seed = UInt64.random(in: UInt64.min...UInt64.max, using: &rng)
        return WorldSave(
            schemaVersion: WorldSaveStore.currentSchemaVersion,
            worldSeed: seed
        )
    }
}

/// Deterministic 64-bit PRNG used by world generation and save creation.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E3779B97F4A7C15
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z = z ^ (z >> 31)
        return z
    }
}

enum WorldSaveStore {
    static let currentSchemaVersion = 1
    private static var cachedCurrent: WorldSave?
    private static let currentLock = NSLock()

    static var current: WorldSave {
        get {
            currentLock.lock()
            defer { currentLock.unlock() }
            if let cachedCurrent {
                return cachedCurrent
            }
            let loaded = loadOrCreate()
            cachedCurrent = loaded
            return loaded
        }
        set {
            currentLock.lock()
            defer { currentLock.unlock() }
            cachedCurrent = newValue
        }
    }

    private static var directory: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0]
        return base.appendingPathComponent("Timberline", isDirectory: true)
    }

    private static var saveURL: URL { directory.appendingPathComponent("world.json") }
    private static var backupURL: URL { directory.appendingPathComponent("world.bak") }

    static func loadOrCreate() -> WorldSave {
        if let worldSave = load() {
            return worldSave
        }

        let fresh = WorldSave.newWorld
        persistToDisk(fresh)
        return fresh
    }

    static func load() -> WorldSave? {
        if let data = try? Data(contentsOf: saveURL),
           var worldSave = try? JSONDecoder().decode(WorldSave.self, from: data)
        {
            if worldSave.schemaVersion < currentSchemaVersion {
                worldSave.schemaVersion = currentSchemaVersion
            }
            return worldSave
        }

        if let backupData = try? Data(contentsOf: backupURL),
           var backupWorldSave = try? JSONDecoder().decode(WorldSave.self, from: backupData)
        {
            if backupWorldSave.schemaVersion < currentSchemaVersion {
                backupWorldSave.schemaVersion = currentSchemaVersion
            }
            return backupWorldSave
        }

        return nil
    }

    static func save(_ worldSave: WorldSave) {
        current = worldSave
        persistToDisk(worldSave)
    }

    private static func persistToDisk(_ worldSave: WorldSave) {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(worldSave)

            if fm.fileExists(atPath: saveURL.path) {
                try? fm.removeItem(at: backupURL)
                try? fm.copyItem(at: saveURL, to: backupURL)
            }
            try data.write(to: saveURL, options: .atomic)
        } catch {
            print("WorldSaveStore.save failed: \(error)")
        }
    }

    static func wipe() {
        let fm = FileManager.default
        try? fm.removeItem(at: saveURL)
        try? fm.removeItem(at: backupURL)
        let fresh = WorldSave.newWorld
        current = fresh
        persistToDisk(fresh)
    }
}
