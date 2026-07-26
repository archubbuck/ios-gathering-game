import SceneKit
import SwiftUI

/// Lightweight, procedurally-generated feedback for a successful axe
/// strike — a self-cleaning wood-chip debris burst and a brief tree
/// recoil wobble. No particle systems or textures, consistent with the
/// rest of the scene's hand-built-node approach (`LowPolyGeometry`,
/// `PickupNodeFactory`).
enum ImpactEffects {
    private static var chipGeometryCache: [TreeSpecies: SCNGeometry] = [:]

    /// A short burst of tumbling wood-chip nodes flung outward from
    /// `position` on a fake-gravity arc. Fully self-removing after ~0.6s —
    /// callers just add the returned node to the scene and forget it, no
    /// per-frame bookkeeping required.
    static func woodChipBurst(at position: SCNVector3, species: TreeSpecies, seed: UInt64) -> SCNNode {
        let root = SCNNode()
        root.position = position

        var rng = SeededRandom(seed: seed)
        let chipCount = 6 + Int(rng.next() % 3) // 6-8
        let geometry = chipGeometry(for: species)

        for _ in 0..<chipCount {
            let chip = SCNNode(geometry: geometry)
            chip.eulerAngles = SCNVector3(
                rng.nextFloat() * 2 * .pi, rng.nextFloat() * 2 * .pi, rng.nextFloat() * 2 * .pi
            )
            root.addChildNode(chip)

            let angle = rng.nextFloat() * 2 * .pi
            let outward = CGFloat(6 + rng.nextFloat() * 10)
            let rise = CGFloat(6 + rng.nextFloat() * 8)
            let dx = CGFloat(cos(angle)) * outward
            let dz = CGFloat(sin(angle)) * outward

            let up = SCNAction.moveBy(x: dx * 0.4, y: rise, z: dz * 0.4, duration: 0.18)
            up.timingMode = .easeOut
            let down = SCNAction.moveBy(x: dx * 0.6, y: -rise - 4, z: dz * 0.6, duration: 0.3)
            down.timingMode = .easeIn
            chip.runAction(.sequence([up, down]))

            let tumble = SCNAction.repeatForever(.rotateBy(
                x: CGFloat(rng.nextFloat() * 4 - 2),
                y: CGFloat(rng.nextFloat() * 4 - 2),
                z: CGFloat(rng.nextFloat() * 4 - 2),
                duration: 0.15
            ))
            chip.runAction(tumble)

            // Independent of the fall/tumble actions above so removal
            // isn't blocked by `tumble`'s `repeatForever` (a `.group`
            // completion would never fire with a non-terminating child).
            chip.runAction(.sequence([
                .wait(duration: 0.3), .fadeOut(duration: 0.2), .removeFromParentNode(),
            ]))
        }

        root.runAction(.sequence([.wait(duration: 0.6), .removeFromParentNode()]))
        return root
    }

    /// A short damped-oscillation recoil, meant to run directly on a
    /// tree's existing root node (which originates at its trunk base) so
    /// it pivots at the base like a real tree being struck.
    static func treeShake(seed: UInt64) -> SCNAction {
        var rng = SeededRandom(seed: seed)
        let axisSign: Float = rng.nextFloat() < 0.5 ? 1 : -1

        func step(_ degrees: Float, _ duration: TimeInterval) -> SCNAction {
            let action = SCNAction.rotateTo(
                x: 0, y: 0,
                z: CGFloat(SceneKitConversions.radians(fromDegrees: Double(degrees * axisSign))),
                duration: duration, usesShortestUnitArc: true
            )
            action.timingMode = .easeOut
            return action
        }

        return .sequence([step(6, 0.08), step(-3.5, 0.09), step(1.5, 0.09), step(0, 0.1)])
    }

    private static func chipGeometry(for species: TreeSpecies) -> SCNGeometry {
        if let cached = chipGeometryCache[species] { return cached }
        let material = SCNMaterial()
        material.lightingModel = .lambert
        material.diffuse.contents = SceneKitConversions.uiColor(SylvanTheme.Scene3D.trunkColor(for: species))
        let box = SCNBox(width: 1.4, height: 0.7, length: 2, chamferRadius: 0.2)
        box.materials = [material]
        chipGeometryCache[species] = box
        return box
    }
}
