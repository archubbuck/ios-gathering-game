import Foundation

/// Persisted world state for Timberline: a fixed world seed and the
/// set of felled tree IDs that should remain stumps across launches.
struct WorldSave: Codable {
    var schemaVersion: Int = WorldSaveStore.currentSchemaVersion
    var worldSeed: UInt64
    var felledTreeIDs: Set<String> = []

    static var newWorld: WorldSave {
        var rng = SystemRandomNumberGenerator()
        let seed = UInt64.random(in: UInt64.min...UInt64.max, using: &rng)
        return WorldSave(worldSeed: seed)
    }
}

enum WorldSaveStore {
    static let currentSchemaVersion = 1
    static var current = loadOrCreate()

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
        save(fresh)
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
        current = WorldSave.newWorld
        save(current)
    }
}
