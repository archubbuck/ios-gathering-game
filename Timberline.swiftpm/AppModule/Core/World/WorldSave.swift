import Foundation

/// Persisted world state for Timberline: a fixed world seed, a map of
/// felled-tree respawn deadlines (seconds since 1970), and schema version.
///
/// `felledTreeDeadlines` is the single authoritative source for which trees
/// are currently stumps and when they regrow. Each entry is written when a
/// tree falls and removed (by `WorldSaveStore.clearDeadline`) when the tree
/// respawns. Trees not present in the map are treated as fully grown.
struct WorldSave: Codable {
    var schemaVersion: Int = 2
    var worldSeed: UInt64
    /// Maps tree key → Unix timestamp of the respawn deadline.
    /// Use `TimeInterval` (Double) so the value round-trips through JSON
    /// without precision loss and works on both iOS and macOS test targets.
    var felledTreeDeadlines: [String: TimeInterval] = [:]

    static var newWorld: WorldSave {
        // Use true system randomness for the world seed so every new game
        // produces a genuinely different world.  SplitMix64 is still used
        // downstream for deterministic generation once the seed is chosen.
        var sysRNG = SystemRandomNumberGenerator()
        let seed = UInt64.random(in: UInt64.min...UInt64.max, using: &sysRNG)
        return WorldSave(
            schemaVersion: WorldSaveStore.currentSchemaVersion,
            worldSeed: seed
        )
    }
}

/// Deterministic 64-bit PRNG used by world generation.
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
    static let currentSchemaVersion = 2
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
           let worldSave = migrate(try? JSONDecoder().decode(WorldSave.self, from: data))
        {
            return worldSave
        }

        if let backupData = try? Data(contentsOf: backupURL),
           let worldSave = migrate(try? JSONDecoder().decode(WorldSave.self, from: backupData))
        {
            return worldSave
        }

        // Try migrating a v1 save that has felledTreeIDs instead of deadlines.
        if let data = try? Data(contentsOf: saveURL),
           let worldSave = migrateV1(data)
        {
            return worldSave
        }
        if let backupData = try? Data(contentsOf: backupURL),
           let worldSave = migrateV1(backupData)
        {
            return worldSave
        }

        return nil
    }

    /// Returns the save if it is current; bumps schemaVersion if needed.
    private static func migrate(_ save: WorldSave?) -> WorldSave? {
        guard var save else { return nil }
        if save.schemaVersion < currentSchemaVersion {
            save.schemaVersion = currentSchemaVersion
        }
        return save
    }

    /// Handle schema v1 saves that stored `felledTreeIDs: [String]` instead
    /// of `felledTreeDeadlines: [String: TimeInterval]`.
    private static func migrateV1(_ data: Data) -> WorldSave? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawSeed = json["worldSeed"] as? UInt64 ?? (json["worldSeed"] as? NSNumber).map({ UInt64($0.uint64Value) })
        else { return nil }
        var save = WorldSave(schemaVersion: currentSchemaVersion, worldSeed: rawSeed)
        // For any previously-felled tree that had no deadline, assign a
        // generous far-future deadline so it respawns rather than staying
        // a stump forever (since the decision is: respawn after deadline).
        if let ids = json["felledTreeIDs"] as? [String] {
            let far = Date().addingTimeInterval(60 * 60).timeIntervalSince1970 // 1 hour from now
            for id in ids {
                save.felledTreeDeadlines[id] = far
            }
        }
        return save
    }

    static func save(_ worldSave: WorldSave) {
        current = worldSave
        persistToDisk(worldSave)
    }

    /// Record that a tree was felled and should respawn at `deadline`.
    static func setDeadline(for key: String, deadline: TimeInterval) {
        current.felledTreeDeadlines[key] = deadline
        persistToDisk(current)
    }

    /// Remove a respawn deadline once the tree has regrown.
    static func clearDeadline(for key: String) {
        current.felledTreeDeadlines.removeValue(forKey: key)
        persistToDisk(current)
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
            NotificationCenter.default.post(
                name: .worldSaveDidFail,
                object: nil,
                userInfo: ["error": error]
            )
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

extension Notification.Name {
    /// Posted on the default center whenever a world-save write fails.
    /// `userInfo["error"]` carries the underlying `Error`.
    static let worldSaveDidFail = Notification.Name("worldSaveDidFail")
    /// Posted on the default center whenever a player-save write fails.
    static let playerSaveDidFail = Notification.Name("playerSaveDidFail")
}
