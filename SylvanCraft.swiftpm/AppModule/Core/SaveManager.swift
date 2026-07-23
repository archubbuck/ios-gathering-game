import Foundation

/// Codable JSON persistence in Application Support. Writes are atomic and
/// the previous save is kept as `.bak`, which `load()` falls back to if
/// the primary file is missing or corrupt.
enum SaveManager {
    static let currentSchemaVersion = 1

    private static var directory: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0]
        return base.appendingPathComponent("SylvanCraft", isDirectory: true)
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
            // A failed save must never crash the game; the previous
            // save (or .bak) is still on disk.
            print("SaveManager.save failed: \(error)")
        }
    }

    static func wipe() {
        let fm = FileManager.default
        try? fm.removeItem(at: saveURL)
        try? fm.removeItem(at: backupURL)
    }

    private static func decode(at url: URL) -> PlayerSave? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard var save = try? JSONDecoder().decode(PlayerSave.self, from: data) else { return nil }

        // Migration hook: bump fields here as schemaVersion grows.
        if save.schemaVersion < currentSchemaVersion {
            save.schemaVersion = currentSchemaVersion
        }

        // Defensive repair: the inventory must always be exactly 28 slots.
        if save.inventory.count != GameData.inventorySlots {
            var inv = Array(save.inventory.prefix(GameData.inventorySlots))
            while inv.count < GameData.inventorySlots { inv.append(nil) }
            save.inventory = inv
        }
        return save
    }
}
