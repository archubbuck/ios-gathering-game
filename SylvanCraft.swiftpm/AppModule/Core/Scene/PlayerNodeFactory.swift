import SceneKit
import SwiftUI

/// Builds the player's SceneKit node hierarchy once — a chibi woodcutter
/// (big head, straw hat, vest over shirt, blue shorts, orange shoes) with
/// hip leg pivots for the walk cycle and elbow-articulated arms holding the
/// equipped axe with a two-handed grip — and provides the full-body
/// axe-chop `SCNAction` ensemble.
/// `ForestSceneView.Coordinator` looks sub-nodes back up by name each
/// frame to push position/facing/animation updates; it never rebuilds the
/// hierarchy, only repositions/re-rotates it.
enum PlayerNodeFactory {
    enum NodeName {
        static let root = "player"
        static let body = "player-body"
        static let head = "player-head"
        static let armPivot = "player-armPivot"
        static let armPivotLeft = "player-armPivot-L"
        static let forearmPivot = "player-forearmPivot"
        static let forearmPivotLeft = "player-forearmPivot-L"
        static let legPivotLeft = "player-legPivot-L"
        static let legPivotRight = "player-legPivot-R"
        /// Group wrapping only the axe meshes inside the forearm pivot, so a
        /// tier swap replaces the tool without amputating the arm.
        static let axe = "player-axe"
    }

    /// Shared key across all five chop-swing nodes (`body`, `armPivot`,
    /// `forearmPivot`, `armPivotLeft`, `forearmPivotLeft`) — starting/
    /// stopping them all under one key lets a single `action(forKey:)`
    /// check on any one of them stand in for "is the ensemble animating".
    static let chopSwingKey = "chopSwing"

    /// Resting shoulder/elbow angles (degrees), shared by the initial pose,
    /// the idle/walk per-frame fallback, and the chop ensemble's
    /// wind-up/recover targets — so there's never a visual snap between
    /// states.
    enum RestPose {
        static let shoulderX: Float = 8
        static let shoulderZ: Float = 15
        static let elbowX: Float = 15
        static let shoulderLeftX: Float = 0
        static let elbowLeftX: Float = 10
    }

    /// Builds the full hierarchy, resting both arms at `RestPose` so an
    /// idle spawn doesn't T-pose. Total height ≈ 58 world units (matching
    /// the old build, so camera framing and the HUD ring height stay
    /// valid).
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

        // Left arm mirrors the right arm's shoulder+elbow rig so it can
        // both swing during the walk cycle and reach for the axe handle
        // during a two-handed chop.
        makeArm(
            named: NodeName.armPivotLeft, forearmName: NodeName.forearmPivotLeft,
            shoulderX: -11.5, restShoulderX: RestPose.shoulderLeftX, restShoulderZ: 0,
            restElbowX: RestPose.elbowLeftX, parent: body
        )

        // Big chibi head with the straw hat parented to it.
        let head = SCNNode(geometry: SCNSphere(radius: 9.5))
        head.name = NodeName.head
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

        // Right arm + axe swing from the shoulder/elbow.
        let (_, rightForearmPivot) = makeArm(
            named: NodeName.armPivot, forearmName: NodeName.forearmPivot,
            shoulderX: 11.5, restShoulderX: RestPose.shoulderX, restShoulderZ: RestPose.shoulderZ,
            restElbowX: RestPose.elbowX, parent: body
        )

        rebuildAxe(in: rightForearmPivot, tier: axeTier)
        return root
    }

    /// Builds one shoulder→elbow→hand chain and parents it to `parent`.
    /// Returns `(shoulderPivot, forearmPivot)` so the caller can attach the
    /// axe (right arm only) without a second name lookup.
    @discardableResult
    private static func makeArm(
        named shoulderName: String,
        forearmName: String,
        shoulderX: Float,
        restShoulderX: Float,
        restShoulderZ: Float,
        restElbowX: Float,
        parent: SCNNode
    ) -> (shoulder: SCNNode, forearm: SCNNode) {
        let shoulderPivot = SCNNode()
        shoulderPivot.name = shoulderName
        shoulderPivot.position = SCNVector3(shoulderX, 37, 0)
        shoulderPivot.eulerAngles = SCNVector3(
            SceneKitConversions.radians(fromDegrees: Double(restShoulderX)),
            0,
            SceneKitConversions.radians(fromDegrees: Double(restShoulderZ))
        )
        parent.addChildNode(shoulderPivot)

        let upperArm = SCNNode(geometry: SCNCapsule(capRadius: 3, height: 8))
        upperArm.geometry?.materials = [material(color: SylvanTheme.Scene3D.shirt)]
        upperArm.position = SCNVector3(0, -4, 0)
        shoulderPivot.addChildNode(upperArm)

        let forearmPivot = SCNNode()
        forearmPivot.name = forearmName
        forearmPivot.position = SCNVector3(0, -8, 0)
        forearmPivot.eulerAngles = SCNVector3(
            SceneKitConversions.radians(fromDegrees: Double(restElbowX)), 0, 0
        )
        shoulderPivot.addChildNode(forearmPivot)

        let forearm = SCNNode(geometry: SCNCapsule(capRadius: 2.6, height: 7))
        forearm.geometry?.materials = [material(color: SylvanTheme.Scene3D.skin)]
        forearm.position = SCNVector3(0, -3.5, 0)
        forearmPivot.addChildNode(forearm)

        let hand = SCNNode(geometry: SCNSphere(radius: 3.2))
        hand.geometry?.materials = [material(color: SylvanTheme.Scene3D.skin)]
        hand.position = SCNVector3(0, -7, 0)
        forearmPivot.addChildNode(hand)

        return (shoulderPivot, forearmPivot)
    }

    /// Swaps the axe geometry hanging off the right forearm pivot — called
    /// when the equipped tier changes. Removes/rebuilds ONLY the
    /// `player-axe` group; the arm and hand nodes sharing the pivot are
    /// untouched. Parented to the forearm (not the shoulder) so bending the
    /// elbow doesn't detach the axe head from the hand.
    static func rebuildAxe(in forearmPivot: SCNNode, tier: AxeTier) {
        forearmPivot.childNode(withName: NodeName.axe, recursively: false)?.removeFromParentNode()
        let metal = AxeArt.metalColors(for: tier)

        let axe = SCNNode()
        axe.name = NodeName.axe
        axe.position = SCNVector3(2.5, -7, 0)
        forearmPivot.addChildNode(axe)

        let handle = SCNNode(geometry: SCNCylinder(radius: 1.6, height: 20))
        handle.geometry?.materials = [material(color: SylvanTheme.barkLight)]
        handle.position = SCNVector3(0, -10, 0)
        axe.addChildNode(handle)

        let head = SCNNode(geometry: SCNBox(width: 10, height: 7, length: 3, chamferRadius: 1))
        head.geometry?.materials = [material(color: metal.light)]
        head.position = SCNVector3(0, -1, 0)
        axe.addChildNode(head)
    }

    // MARK: - Chop swing

    /// One phase of the chop ensemble: target angles (degrees) for the
    /// right shoulder (x, z) and elbow (x), the left shoulder (x) and
    /// elbow (x) — reaching toward the axe handle for a two-handed grip —
    /// and the torso's twist/lean (degrees) plus vertical dip (world
    /// units). `duration`/`timing` are fractions resolved against the
    /// caller's total swing duration.
    private struct SwingPhase {
        let durationFraction: Double
        let timing: SCNActionTimingMode
        let shoulderX: Float
        let shoulderZ: Float
        let elbowX: Float
        let shoulderLeftX: Float
        let elbowLeftX: Float
        let torsoTwistY: Float
        let torsoLeanX: Float
        let torsoDipY: Float
    }

    /// Fixed lengths (as fractions of the total swing) for the strike and
    /// follow-through phases; wind-up and recover are derived below so the
    /// strike keyframe always lands exactly at `GameData.chopStrikeFraction`
    /// — the same instant `GameState.performChopTick()` resolves.
    private static let strikePhaseFraction = 0.13
    private static let followPhaseFraction = 0.20

    /// Wind-up (anticipation) → strike (power stroke, lands at
    /// `GameData.chopStrikeFraction`) → follow-through → recover/hold,
    /// ported from real chopping biomechanics: a slow deliberate rise,
    /// a fast downward-diagonal power stroke that carries the axe up and
    /// back over the shoulder rather than a flat side-to-side pendulum,
    /// torso coil/uncoil for weight transfer, and a two-handed grip via
    /// the off-hand reaching toward the handle through the stroke.
    private static var swingPhases: [SwingPhase] {
        let windUpFraction = GameData.chopStrikeFraction - strikePhaseFraction
        let recoverFraction = 1 - GameData.chopStrikeFraction - followPhaseFraction
        return [
            SwingPhase(
                durationFraction: windUpFraction, timing: .easeOut,
                shoulderX: -55, shoulderZ: -95, elbowX: 85,
                shoulderLeftX: -70, elbowLeftX: 95,
                torsoTwistY: -14, torsoLeanX: -4, torsoDipY: -0.6
            ),
            SwingPhase(
                durationFraction: strikePhaseFraction, timing: .easeIn,
                shoulderX: 20, shoulderZ: 25, elbowX: 10,
                shoulderLeftX: -20, elbowLeftX: 45,
                torsoTwistY: 10, torsoLeanX: 8, torsoDipY: -1.4
            ),
            SwingPhase(
                durationFraction: followPhaseFraction, timing: .easeOut,
                shoulderX: RestPose.shoulderX, shoulderZ: RestPose.shoulderZ, elbowX: 25,
                shoulderLeftX: -25, elbowLeftX: 50,
                torsoTwistY: 4, torsoLeanX: 5, torsoDipY: -0.8
            ),
            SwingPhase(
                durationFraction: recoverFraction, timing: .easeInEaseOut,
                shoulderX: RestPose.shoulderX, shoulderZ: RestPose.shoulderZ, elbowX: RestPose.elbowX,
                shoulderLeftX: RestPose.shoulderLeftX, elbowLeftX: RestPose.elbowLeftX,
                torsoTwistY: 0, torsoLeanX: 0, torsoDipY: 0
            ),
        ]
    }

    /// Starts (or restarts) the full-body chop ensemble across all five
    /// animated nodes, sized to `duration` — the real gameplay chop-tick
    /// interval — so the strike keyframe lands in lockstep with
    /// `GameState.performChopTick()` actually resolving, rather than
    /// looping on an independent clock.
    static func applyChopSwing(
        body: SCNNode, armPivot: SCNNode, forearmPivot: SCNNode,
        armPivotLeft: SCNNode, forearmPivotLeft: SCNNode,
        duration: TimeInterval
    ) {
        var armPivotSteps: [SCNAction] = []
        var forearmSteps: [SCNAction] = []
        var armPivotLeftSteps: [SCNAction] = []
        var forearmLeftSteps: [SCNAction] = []
        var bodyRotateSteps: [SCNAction] = []
        var bodyMoveSteps: [SCNAction] = []

        for phase in swingPhases {
            let stepDuration = duration * phase.durationFraction

            armPivotSteps.append(rotateStep(x: phase.shoulderX, z: phase.shoulderZ, duration: stepDuration, timing: phase.timing))
            forearmSteps.append(rotateStep(x: phase.elbowX, duration: stepDuration, timing: phase.timing))
            armPivotLeftSteps.append(rotateStep(x: phase.shoulderLeftX, duration: stepDuration, timing: phase.timing))
            forearmLeftSteps.append(rotateStep(x: phase.elbowLeftX, duration: stepDuration, timing: phase.timing))

            let rotate = SCNAction.rotateTo(
                x: CGFloat(SceneKitConversions.radians(fromDegrees: Double(phase.torsoLeanX))),
                y: CGFloat(SceneKitConversions.radians(fromDegrees: Double(phase.torsoTwistY))),
                z: 0, duration: stepDuration, usesShortestUnitArc: true
            )
            rotate.timingMode = phase.timing
            bodyRotateSteps.append(rotate)

            let move = SCNAction.move(to: SCNVector3(0, phase.torsoDipY, 0), duration: stepDuration)
            move.timingMode = phase.timing
            bodyMoveSteps.append(move)
        }

        armPivot.runAction(.sequence(armPivotSteps), forKey: chopSwingKey)
        forearmPivot.runAction(.sequence(forearmSteps), forKey: chopSwingKey)
        armPivotLeft.runAction(.sequence(armPivotLeftSteps), forKey: chopSwingKey)
        forearmPivotLeft.runAction(.sequence(forearmLeftSteps), forKey: chopSwingKey)
        body.runAction(.group([.sequence(bodyRotateSteps), .sequence(bodyMoveSteps)]), forKey: chopSwingKey)
    }

    /// Eases all five chop nodes back to their shared resting pose when
    /// chopping stops (moved away, pack full, tree felled). Keyed the same
    /// as the swing itself, so `action(forKey: chopSwingKey)` stays a
    /// reliable "still animating" check until this finishes.
    static func easeChopToRest(
        body: SCNNode, armPivot: SCNNode, forearmPivot: SCNNode,
        armPivotLeft: SCNNode, forearmPivotLeft: SCNNode
    ) {
        let duration: TimeInterval = 0.22
        armPivot.runAction(rotateStep(x: RestPose.shoulderX, z: RestPose.shoulderZ, duration: duration, timing: .easeOut), forKey: chopSwingKey)
        forearmPivot.runAction(rotateStep(x: RestPose.elbowX, duration: duration, timing: .easeOut), forKey: chopSwingKey)
        armPivotLeft.runAction(rotateStep(x: RestPose.shoulderLeftX, duration: duration, timing: .easeOut), forKey: chopSwingKey)
        forearmPivotLeft.runAction(rotateStep(x: RestPose.elbowLeftX, duration: duration, timing: .easeOut), forKey: chopSwingKey)

        let rotate = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: duration, usesShortestUnitArc: true)
        rotate.timingMode = .easeOut
        let move = SCNAction.move(to: SCNVector3(0, 0, 0), duration: duration)
        move.timingMode = .easeOut
        body.runAction(.group([rotate, move]), forKey: chopSwingKey)
    }

    private static func rotateStep(x: Float, z: Float = 0, duration: TimeInterval, timing: SCNActionTimingMode) -> SCNAction {
        let action = SCNAction.rotateTo(
            x: CGFloat(SceneKitConversions.radians(fromDegrees: Double(x))),
            y: 0,
            z: CGFloat(SceneKitConversions.radians(fromDegrees: Double(z))),
            duration: duration, usesShortestUnitArc: true
        )
        action.timingMode = timing
        return action
    }

    private static func material(color: Color) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .lambert
        material.diffuse.contents = SceneKitConversions.uiColor(color)
        return material
    }
}
