import SceneKit
import SwiftUI

/// Builds the player's SceneKit node hierarchy once — legs, torso, head, and
/// an arm pivot holding the equipped axe — and provides the axe-swing
/// `SCNAction`. `ForestSceneView.Coordinator` looks sub-nodes back up by
/// name each frame to push position/facing/animation updates; it never
/// rebuilds the hierarchy, only repositions/re-rotates it.
enum PlayerNodeFactory {
    enum NodeName {
        static let root = "player"
        static let body = "player-body"
        static let armPivot = "player-armPivot"
    }

    static let swingActionKey = "axeSwing"

    /// Builds the full hierarchy, resting the axe at its "recover" angle
    /// (-30°) so an idle spawn doesn't read as a broken T-pose.
    static func makeNode(axeTier: AxeTier) -> SCNNode {
        let root = SCNNode()
        root.name = NodeName.root

        let body = SCNNode()
        body.name = NodeName.body
        root.addChildNode(body)

        let legMaterial = material(color: SylvanTheme.darkWood)
        for xOffset in [Float(-4), Float(4)] {
            let leg = SCNNode(geometry: SCNCapsule(capRadius: 4, height: 20))
            leg.geometry?.materials = [legMaterial]
            leg.position = SCNVector3(xOffset, 10, 0)
            body.addChildNode(leg)
        }

        let torso = SCNNode(geometry: SCNBox(width: 20, height: 22, length: 12, chamferRadius: 3))
        torso.geometry?.materials = [material(color: SylvanTheme.barkLight)]
        torso.position = SCNVector3(0, 31, 0)
        body.addChildNode(torso)

        let head = SCNNode(geometry: SCNSphere(radius: 9))
        head.geometry?.materials = [material(color: Color(hex: 0xFFCC99))]
        head.position = SCNVector3(0, 49, 0)
        body.addChildNode(head)

        // Arm pivot: shoulder-height anchor the axe hangs below. Rotating
        // this node around Z is the entire axe-swing animation.
        let armPivot = SCNNode()
        armPivot.name = NodeName.armPivot
        armPivot.position = SCNVector3(11, 38, 0)
        armPivot.eulerAngles = SCNVector3(0, 0, SceneKitConversions.radians(fromDegrees: -30))
        body.addChildNode(armPivot)

        rebuildAxe(in: armPivot, tier: axeTier)

        return root
    }

    /// Swaps the axe geometry hanging off `armPivot` — called when the
    /// player's equipped tier changes, not on every frame.
    static func rebuildAxe(in armPivot: SCNNode, tier: AxeTier) {
        armPivot.childNodes.forEach { $0.removeFromParentNode() }

        let metal = AxeArt.metalColors(for: tier)

        let handle = SCNNode(geometry: SCNCylinder(radius: 1.6, height: 22))
        handle.geometry?.materials = [material(color: SylvanTheme.barkLight)]
        handle.position = SCNVector3(0, -11, 0)
        armPivot.addChildNode(handle)

        let head = SCNNode(geometry: SCNBox(width: 10, height: 7, length: 3, chamferRadius: 1))
        head.geometry?.materials = [material(color: metal.light)]
        head.position = SCNVector3(0, -1, 0)
        armPivot.addChildNode(head)
    }

    /// The repeating chop cycle, ported from the deleted `PlayerView`'s
    /// wind-up (-90°) → strike (20°) → recover (-30°) waypoints. Absolute
    /// angles via `rotateTo` (not `rotateBy`) so the cycle can't drift.
    static func swingAction() -> SCNAction {
        let windUp = SCNAction.rotateTo(
            x: 0, y: 0, z: CGFloat(SceneKitConversions.radians(fromDegrees: -90)),
            duration: 0.15, shortestUnitArc: true
        )
        let strike = SCNAction.rotateTo(
            x: 0, y: 0, z: CGFloat(SceneKitConversions.radians(fromDegrees: 20)),
            duration: 0.25, shortestUnitArc: true
        )
        let recover = SCNAction.rotateTo(
            x: 0, y: 0, z: CGFloat(SceneKitConversions.radians(fromDegrees: -30)),
            duration: 0.2, shortestUnitArc: true
        )
        let cycle = SCNAction.sequence([
            windUp, SCNAction.wait(duration: 0.03),
            strike, SCNAction.wait(duration: 0.03),
            recover, SCNAction.wait(duration: 0.15),
        ])
        return SCNAction.repeatForever(cycle)
    }

    /// Eases the axe back to its resting angle when a swing is interrupted.
    static func restAction() -> SCNAction {
        SCNAction.rotateTo(
            x: 0, y: 0, z: CGFloat(SceneKitConversions.radians(fromDegrees: -30)),
            duration: 0.15, shortestUnitArc: true
        )
    }

    private static func material(color: Color) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .lambert
        material.diffuse.contents = SceneKitConversions.uiColor(color)
        return material
    }
}
