import Foundation

/// Pure chop-success math — Foundation only, no game state.
enum ChopMath {
    static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * min(max(t, 0), 1)
    }

    /// Per-tick success chance for one chop attempt. The tree defines its
    /// chance band from level 1 to 99; the axe multiplies it; the result
    /// is clamped so nothing is ever hopeless or guaranteed.
    static func successChance(level: Int, tree: TreeDef, axe: AxeDef) -> Double {
        let t = Double(level - 1) / 98.0
        let base = lerp(tree.successLow, tree.successHigh, t)
        return min(max(axe.power * base, 0.03), 0.95)
    }
}
