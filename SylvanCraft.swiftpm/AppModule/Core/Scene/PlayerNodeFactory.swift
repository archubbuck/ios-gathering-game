import SceneKit
import SwiftUI

/// Builds the player's SceneKit node hierarchy once — a chibi woodcutter
/// (big head, straw hat, vest over shirt, blue shorts, orange shoes) with
/// hip leg pivots for the walk cycle and an arm pivot holding the equipped
/// axe — and provides the axe-swing `SCNAction`.
/// `ForestSceneView.Coordinator` looks sub-nodes back up by name each
/// frame to push position/facing/animation updates; it never rebuilds the
/// hierarchy, only repositions/re-rotates it.
enum PlayerNodeFactory {
    enum NodeName {
        static let root = "player"
        static let body = "player-body"
        static let armPivot = "player-armPivot"
        static let legPivotLeft = "player-legPivot-L"
        static let legPivotRight = "player-legPivot-R"
        /// Group wrapping only the axe meshes inside the arm pivot, so a
        /// tier swap replaces the tool without amputating the arm.
        static let axe = "player-axe"
    }

    static let swingActionKey = "axeSwing"

    /// Builds the full hierarchy, resting the axe at its "recover" angle
    /// (-30°) so an idle spawn doesn't T-pose. Total height ≈ 58 world
    /// units (matching the old build, so camera framing and the HUD
    /// ring height stay valid).
    static func makeNode(axeTier: AxeTier) -> SCNNode {
        let root = SCNNode()
        root.name = NodeName.root

        let body = SCNNode()
        body.name = NodeName.body
        root.addChildNode(body)

        // Legs: pivot at the hip so walking is a pure X-rotation; bare
        // (skin) calf capsule with a chunky shoe, toe pointing forward.
        let legs: [(name: String, x: Float)] = [
            (NodeName.legPivotLeft, -5),
            (NodeName.legPivotRight, 5),
        ]
        for leg in legs {
            let pivot = SCNNode()
            pivot.name = leg.name
            pivot.position = SCNVector3(leg.x, 16, 0)
            body.addChildNode(pivot)

            let calf = SCNNode(geometry: SCNCapsule(capRadius: 3.5, height: 12))
            calf.geometry?.materials = [material(color: SylvanTheme.Scene3D.skin)]
            calf.position = SCNVector3(0, -6, 0)
            pivot.addChildNode(calf)

            let shoe = SCNNode(geometry: SCNBox(width: 8, height: 4, length: 10, chamferRadius: 1.5))
            shoe.geometry?.materials = [material(color: SylvanTheme.Scene3D.shoes)]
            shoe.position = SCNVector3(0, -12, 1.5)
            pivot.addChildNode(shoe)
        }

        let shorts = SCNNode(geometry: SCNBox(width: 17, height: 8, length: 11, chamferRadius: 2))
        shorts.geometry?.materials = [material(color: SylvanTheme.Scene3D.shorts)]
        shorts.position = SCNVector3(0, 19, 0)
        body.addChildNode(shorts)

        let vest = SCNNode(geometry: SCNBox(width: 18, height: 14, length: 11, chamferRadius: 3))
        vest.geometry?.materials = [material(color: SylvanTheme.Scene3D.vest)]
        vest.position = SCNVector3(0, 30, 0)
        body.addChildNode(vest)

        let collar = SCNNode(geometry: SCNBox(width: 19, height: 3, length: 12, chamferRadius: 1))
        collar.geometry?.materials = [material(color: SylvanTheme.Scene3D.shirt)]
        collar.position = SCNVector3(0, 37, 0)
        body.addChildNode(collar)

        // Left arm hangs at the side; only the right (axe) arm animates.
        let leftArm = SCNNode(geometry: SCNCapsule(capRadius: 3, height: 15))
        leftArm.geometry?.materials = [material(color: SylvanTheme.Scene3D.shirt)]
        leftArm.position = SCNVector3(-11.5, 30, 0)
        body.addChildNode(leftArm)

        let leftHand = SCNNode(geometry: SCNSphere(radius: 3.2))
        leftHand.geometry?.materials = [material(color: SylvanTheme.Scene3D.skin)]
        leftHand.position = SCNVector3(-11.5, 22, 0)
        body.addChildNode(leftHand)

        // Big chibi head with the straw hat parented to it.
        let head = SCNNode(geometry: SCNSphere(radius: 9.5))
        head.geometry?.materials = [material(color: SylvanTheme.Scene3D.skin)]
        head.position = SCNVector3(0, 46, 0)
        body.addChildNode(head)

        let brim = SCNNode(geometry: SCNCylinder(radius: 13, height: 1.4))
        brim.geometry?.materials = [material(color: SylvanTheme.Scene3D.hatStraw)]
        brim.position = SCNVector3(0, 5.5, 0)
        head.addChildNode(brim)

        let crown = SCNNode(geometry: SCNSphere(radius: 7))
        crown.geometry?.materials = [material(color: SylvanTheme.Scene3D.hatStraw)]
        crown.position = SCNVector3(0, 7.5, 0)
        head.addChildNode(crown)

        let band = SCNNode(geometry: SCNCylinder(radius: 7.3, height: 2))
        band.geometry?.materials = [material(color: SylvanTheme.Scene3D.hatBand)]
        band.position = SCNVector3(0, 6.8, 0)
        head.addChildNode(band)

        // Right arm + axe swing from the shoulder.
        let armPivot = SCNNode()
        armPivot.name = NodeName.armPivot
        armPivot.position = SCNVector3(11.5, 37, 0)
        armPivot.eulerAngles = SCNVector3(0, 0, SceneKitConversions.radians(fromDegrees: -30))
        body.addChildNode(armPivot)

        let rightArm = SCNNode(geometry: SCNCapsule(capRadius: 3, height: 14))
        rightArm.geometry?.materials = [material(color: SylvanTheme.Scene3D.shirt)]
        rightArm.position = SCNVector3(0, -6, 0)
        armPivot.addChildNode(rightArm)

        let rightHand = SCNNode(geometry: SCNSphere(radius: 3.2))
        rightHand.geometry?.materials = [material(color: SylvanTheme.Scene3D.skin)]
        rightHand.position = SCNVector3(0, -13, 0)
        armPivot.addChildNode(rightHand)

        rebuildAxe(in: armPivot, tier: axeTier)
        return root
    }

    /// Swaps the axe geometry hanging off `armPivot` — called when the
    /// equipped tier changes. Removes/rebuilds ONLY the `player-axe`
    /// group; the arm and hand nodes sharing the pivot are untouched.
    static func rebuildAxe(in armPivot: SCNNode, tier: AxeTier) {
        armPivot.childNode(withName: NodeName.axe, recursively: false)?.removeFromParentNode()
        let metal = AxeArt.metalColors(for: tier)

        let axe = SCNNode()
        axe.name = NodeName.axe
        axe.position = SCNVector3(2.5, -13, 0)
        armPivot.addChildNode(axe)

        let handle = SCNNode(geometry: SCNCylinder(radius: 1.6, height: 20))
        handle.geometry?.materials = [material(color: SylvanTheme.barkLight)]
        handle.position = SCNVector3(0, -10, 0)
        axe.addChildNode(handle)

        let head = SCNNode(geometry: SCNBox(width: 10, height: 7, length: 3, chamferRadius: 1))
        head.geometry?.materials = [material(color: metal.light)]
        head.position = SCNVector3(0, -1, 0)
        axe.addChildNode(head)
    }

    /// The repeating chop cycle, ported from the deleted `PlayerView`'s
    /// wind-up (-90°) → strike (20°) → recover (-30°) waypoints. Absolute
    /// angles via `rotateTo` (not `rotateBy`) so the cycle can't drift.
    static func swingAction() -> SCNAction {
        let windUp = SCNAction.rotateTo(
            x: 0, y: 0, z: CGFloat(SceneKitConversions.radians(fromDegrees: -90)),
            duration: 0.15, usesShortestUnitArc: true
        )
        let strike = SCNAction.rotateTo(
            x: 0, y: 0, z: CGFloat(SceneKitConversions.radians(fromDegrees: 20)),
            duration: 0.25, usesShortestUnitArc: true
        )
        let recover = SCNAction.rotateTo(
            x: 0, y: 0, z: CGFloat(SceneKitConversions.radians(fromDegrees: -30)),
            duration: 0.2, usesShortestUnitArc: true
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
            duration: 0.2, usesShortestUnitArc: true
        )
    }

    private static func material(color: Color) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .lambert
        material.diffuse.contents = SceneKitConversions.uiColor(color)
        return material
    }
}
