import SceneKit
import SwiftUI

/// Builds the SceneKit node for a Woodcutting Potion world pickup: a small
/// glowing faceted orb (reusing `LowPolyGeometry.facetedBlob`, rounder
/// than the `facetedRock` boulders) with a soft point light and a
/// continuous bob + spin `SCNAction`, so no per-frame update code is
/// needed to keep it animating.
enum PickupNodeFactory {
    private static var geometryCache: SCNGeometry?

    /// Shared bob+spin action, applied once per node at creation.
    private static let idleActionKey = "potionIdle"

    static func makePotionNode() -> SCNNode {
        let root = SCNNode()
        root.name = "potion-pickup"

        let geometry = orbGeometry()
        let orb = SCNNode(geometry: geometry)
        orb.scale = SCNVector3(1, 1, 1)
        root.addChildNode(orb)

        let light = SCNLight()
        light.type = .omni
        light.color = SceneKitConversions.uiColor(SylvanTheme.Scene3D.potionGlowLight)
        light.intensity = 60
        light.attenuationStartDistance = 5
        light.attenuationEndDistance = 90
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.position = SCNVector3(0, 4, 0)
        root.addChildNode(lightNode)

        let bob = SCNAction.sequence([
            .moveBy(x: 0, y: 4, z: 0, duration: 0.9),
            .moveBy(x: 0, y: -4, z: 0, duration: 0.9),
        ])
        bob.timingMode = .easeInEaseOut
        let spin = SCNAction.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 4))
        let idle = SCNAction.group([.repeatForever(bob), spin])
        root.runAction(idle, forKey: idleActionKey)

        return root
    }

    private static func orbGeometry() -> SCNGeometry {
        if let cached = geometryCache { return cached }
        let geometry = LowPolyGeometry.facetedBlob(
            radius: 8,
            rings: 2,
            sides: 6,
            jitter: 0.14,
            squash: 1.0,
            highlightFraction: 0.35,
            seed: 0x9070_1104,
            baseColor: SylvanTheme.Scene3D.potionGlow,
            highlightColor: SylvanTheme.Scene3D.potionGlowLight
        )
        geometryCache = geometry
        return geometry
    }
}
