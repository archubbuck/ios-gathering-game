import Foundation

/// The OSRS experience curve: level 2 = 83 XP, level 99 = 13,034,431 XP.
enum XPTable {
    static let maxLevel = 99

    /// `thresholds[level]` = total XP required to reach `level`.
    /// Indices 0 and 1 are 0 (you start at level 1).
    static let thresholds: [Double] = {
        var result: [Double] = [0, 0]
        var points = 0.0
        for level in 1..<99 {
            points += floor(Double(level) + 300.0 * pow(2.0, Double(level) / 7.0))
            result.append(floor(points / 4.0))
        }
        return result
    }()

    static func level(for xp: Double) -> Int {
        var low = 1
        var high = maxLevel
        while low < high {
            let mid = (low + high + 1) / 2
            if thresholds[mid] <= xp {
                low = mid
            } else {
                high = mid - 1
            }
        }
        return low
    }

    static func xp(for level: Int) -> Double {
        guard level >= 1 else { return 0 }
        guard level <= maxLevel else { return thresholds[maxLevel] }
        return thresholds[level]
    }

    /// Progress within the current level, for the HUD XP bar.
    static func progressToNext(xp: Double) -> (current: Double, needed: Double, fraction: Double) {
        let level = level(for: xp)
        guard level < maxLevel else { return (0, 0, 1) }
        let floor = thresholds[level]
        let ceiling = thresholds[level + 1]
        let needed = ceiling - floor
        let current = xp - floor
        return (current, needed, needed > 0 ? current / needed : 1)
    }
}
