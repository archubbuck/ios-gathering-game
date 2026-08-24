import Foundation

/// Codable JSON persistence in Application Support. Writes are atomic and
/// the previous save is kept as `.bak`, which `load()` falls back to if
/// the primary file is missing or corrupt.
enum SaveManager {
    static let currentSchemaVersion = 2

    private static var directory: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0]
        return base.appendingPathComponent("Timberline", isDirectory: true)
    }

    private static var saveURL: URL { directory.appendingPathComponent("save.json") }
    private static var backupURL: URL { directory.appendingPathComponent("save.bak") }

    static func load() -> PlayerSave? {
        if let save = decode(at: saveURL) { return save }
        return decode(at: backupURL)
    }

    static func save(_ save: PlayerSave) {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(save)

            if fm.fileExists(atPath: saveURL.path) {
                try? fm.removeItem(at: backupURL)
                try? fm.copyItem(at: saveURL, to: backupURL)
            }
            try data.write(to: saveURL, options: .atomic)
        } catch {
            NotificationCenter.default.post(
                name: .playerSaveDidFail,
                object: nil,
                userInfo: ["error": error]
            )
        }
    }

    static func wipe() {
        let fm = FileManager.default
        try? fm.removeItem(at: saveURL)
        try? fm.removeItem(at: backupURL)
    }

    private static func decode(at url: URL) -> PlayerSave? {
        guard let data = try? Data(contentsOf: url) else { return nil }

        // Try v2+ format first.
        if var save = try? JSONDecoder().decode(PlayerSave.self, from: data) {
            // Migration: bump schemaVersion.
            if save.schemaVersion < currentSchemaVersion {
                save.schemaVersion = currentSchemaVersion
            }
            return repair(save)
        }

        // Fallback: try v1 format (has currentRegionID, no playerPosition).
        if let legacy = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           legacy["currentRegionID"] != nil
        {
            var save = PlayerSave.newGame
            save.schemaVersion = currentSchemaVersion
            if let v = legacy["totalXP"] as? Double { save.totalXP = v }
            if let v = legacy["gold"] as? Int { save.gold = v }
            if let arr = legacy["inventory"] as? [String?] {
                save.inventory = arr.map { s in
                    s.flatMap { TreeSpecies(rawValue: $0) }
                }
                // repaired() below will pad/trim to exactly inventorySlots.
            }
            if let arr = legacy["bank"] as? [[String: Any]] {
                save.bank = arr.compactMap { dict -> ItemStack? in
                    guard let raw = dict["species"] as? String,
                          let species = TreeSpecies(rawValue: raw),
                          let count = dict["count"] as? Int
                    else { return nil }
                    return ItemStack(species: species, count: count)
                }
            }
            if let arr = legacy["ownedAxes"] as? [String] {
                save.ownedAxes = Set(arr.compactMap { AxeTier(rawValue: $0) })
            }
            if let v = legacy["equippedAxe"] as? String,
               let tier = AxeTier(rawValue: v) { save.equippedAxe = tier }
            if let dict = legacy["stats"] as? [String: Any] {
                save.stats = decodeLegacyStats(dict)
            }
            if let arr = legacy["unlockedAchievements"] as? [String] {
                save.unlockedAchievements = Set(arr)
            }
            // Position: if it was a region, start at origin.
            save.playerPosition = .zero
            return repair(save)
        }

        return nil
    }

    private static func repair(_ save: PlayerSave) -> PlayerSave {
        save.repaired()
    }

    private static func decodeLegacyStats(_ dict: [String: Any]) -> LifetimeStats {
        var stats = LifetimeStats()
        if let dict2 = dict["logsBySpecies"] as? [String: Int] {
            for (key, val) in dict2 {
                if let species = TreeSpecies(rawValue: key) {
                    stats.logsBySpecies[species] = val
                }
            }
        }
        stats.totalLogs = dict["totalLogs"] as? Int ?? 0
        stats.lifetimeGold = dict["lifetimeGold"] as? Int ?? 0
        if let arr = dict["regionsVisited"] as? [String] {
            stats.regionsVisited = Set(arr)
        }
        return stats
    }
}
