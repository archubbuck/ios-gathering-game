import SceneKit
import SwiftUI

/// Builds low-poly SceneKit tree nodes, one per world tree instance, from a
/// small set of shared per-species `SCNGeometry`/`SCNMaterial` objects
/// (cached, not rebuilt per instance). Color/shape mapping mirrors
/// `Views/Art/TreeArt.swift`, the canonical 2D source of truth, so each
/// species stays recognizable in 3D.
enum TreeGeometryFactory {
    private struct GeometryKey: Hashable {
        let species: TreeSpecies
        let part: String
        let locked: Bool
    }

    private static var cache: [GeometryKey: SCNGeometry] = [:]

    /// A full, choppable tree: trunk + canopy, desaturated when `locked`.
    static func makeTreeNode(species: TreeSpecies, locked: Bool) -> SCNNode {
        let root = SCNNode()
        root.name = "tree"

        switch species {
        case .birch: buildBirch(into: root, locked: locked)
        case .oak: buildOak(into: root, locked: locked)
        case .willow: buildWillow(into: root, locked: locked)
        case .evergreen: buildEvergreen(into: root, locked: locked)
        case .ancientYew: buildAncientYew(into: root, locked: locked)
        case .elderwood: buildElderwood(into: root, locked: locked)
        }
        return root
    }

    /// A depleted tree, shown while its `respawnUntil` timer counts down.
    static func makeStumpNode(species: TreeSpecies) -> SCNNode {
        let root = SCNNode()
        root.name = "stump"

        let trunk = node(
            key: GeometryKey(species: species, part: "stumpTrunk", locked: false),
            color: SylvanTheme.bark
        ) { SCNCylinder(radius: 12, height: 18) }
        trunk.position = SCNVector3(0, 9, 0)
        root.addChildNode(trunk)

        let top = node(
            key: GeometryKey(species: species, part: "stumpTop", locked: false),
            color: SylvanTheme.parchmentEdge
        ) { SCNCylinder(radius: 13, height: 2) }
        top.position = SCNVector3(0, 18, 0)
        root.addChildNode(top)

        return root
    }

    // MARK: - Species builders

    private static func buildBirch(into root: SCNNode, locked: Bool) {
        let trunk = node(
            key: GeometryKey(species: .birch, part: "trunk", locked: locked),
            color: shade(Color(hex: 0xECEFF1), locked: locked)
        ) { SCNCylinder(radius: 5, height: 52) }
        trunk.position = SCNVector3(0, 26, 0)
        root.addChildNode(trunk)

        let canopy = node(
            key: GeometryKey(species: .birch, part: "canopy", locked: locked),
            color: shade(SylvanTheme.canopyLight, locked: locked)
        ) { SCNSphere(radius: 28) }
        canopy.position = SCNVector3(0, 66, 0)
        root.addChildNode(canopy)
    }

    private static func buildOak(into root: SCNNode, locked: Bool) {
        let trunk = node(
            key: GeometryKey(species: .oak, part: "trunk", locked: locked),
            color: shade(SylvanTheme.bark, locked: locked)
        ) { SCNCylinder(radius: 8, height: 46) }
        trunk.position = SCNVector3(0, 23, 0)
        root.addChildNode(trunk)

        let lobeOffsets: [(CGFloat, CGFloat)] = [(-22, 44), (22, 44), (0, 64)]
        for (index, offset) in lobeOffsets.enumerated() {
            let lobe = node(
                key: GeometryKey(species: .oak, part: "lobe\(index)", locked: locked),
                color: shade(index == 2 ? SylvanTheme.forestGreen : SylvanTheme.canopyDark, locked: locked)
            ) { SCNSphere(radius: index == 2 ? 30 : 24) }
            lobe.position = SCNVector3(SceneKitConversions.float(offset.0), SceneKitConversions.float(offset.1), 0)
            root.addChildNode(lobe)
        }
    }

    private static func buildWillow(into root: SCNNode, locked: Bool) {
        let trunk = node(
            key: GeometryKey(species: .willow, part: "trunk", locked: locked),
            color: shade(SylvanTheme.bark, locked: locked)
        ) { SCNCylinder(radius: 6.5, height: 48) }
        trunk.position = SCNVector3(0, 24, 0)
        root.addChildNode(trunk)

        let canopy = node(
            key: GeometryKey(species: .willow, part: "canopy", locked: locked),
            color: shade(Color(hex: 0x7CB342), locked: locked)
        ) { SCNSphere(radius: 32) }
        canopy.position = SCNVector3(0, 60, 0)
        root.addChildNode(canopy)

        // Simplified drooping fronds → tilted cones ringing the canopy (v1
        // trim: no curved-frond geometry).
        let frondColor = shade(Color(hex: 0x689F38), locked: locked)
        for index in 0..<5 {
            let angle = Double(index) / 5 * 2 * .pi
            let frond = node(
                key: GeometryKey(species: .willow, part: "frond\(index)", locked: locked),
                color: frondColor
            ) { SCNCone(topRadius: 1.5, bottomRadius: 6, height: 22) }
            let radius: CGFloat = 26
            frond.position = SCNVector3(
                SceneKitConversions.float(cos(angle) * Double(radius)),
                40,
                SceneKitConversions.float(sin(angle) * Double(radius))
            )
            frond.eulerAngles = SCNVector3(Float.pi * 0.85, 0, 0)
            root.addChildNode(frond)
        }
    }

    private static func buildEvergreen(into root: SCNNode, locked: Bool) {
        let trunk = node(
            key: GeometryKey(species: .evergreen, part: "trunk", locked: locked),
            color: shade(SylvanTheme.bark, locked: locked)
        ) { SCNCylinder(radius: 6, height: 30) }
        trunk.position = SCNVector3(0, 15, 0)
        root.addChildNode(trunk)

        for layer in 0..<3 {
            let color = layer.isMultiple(of: 2) ? SylvanTheme.canopyDark : SylvanTheme.forestGreen
            let cone = node(
                key: GeometryKey(species: .evergreen, part: "cone\(layer)", locked: locked),
                color: shade(color, locked: locked)
            ) { SCNCone(topRadius: 1, bottomRadius: 32 - CGFloat(layer) * 7, height: 34 - CGFloat(layer) * 5) }
            cone.position = SCNVector3(0, SceneKitConversions.float(30 + CGFloat(layer) * 16), 0)
            root.addChildNode(cone)
        }
    }

    private static func buildAncientYew(into root: SCNNode, locked: Bool) {
        let trunk = node(
            key: GeometryKey(species: .ancientYew, part: "trunk", locked: locked),
            color: shade(Color(hex: 0x4E342E), locked: locked)
        ) { SCNCylinder(radius: 10, height: 42) }
        trunk.position = SCNVector3(0, 21, 0)
        root.addChildNode(trunk)

        let canopy = node(
            key: GeometryKey(species: .ancientYew, part: "canopy", locked: locked),
            color: shade(Color(hex: 0x33691E), locked: locked)
        ) { SCNSphere(radius: 38) }
        canopy.position = SCNVector3(0, 68, 0)
        root.addChildNode(canopy)
    }

    private static func buildElderwood(into root: SCNNode, locked: Bool) {
        let trunk = node(
            key: GeometryKey(species: .elderwood, part: "trunk", locked: locked),
            color: shade(Color(hex: 0x3E2723), locked: locked)
        ) { SCNCylinder(radius: 12, height: 48) }
        trunk.position = SCNVector3(0, 24, 0)
        root.addChildNode(trunk)

        let canopy = node(
            key: GeometryKey(species: .elderwood, part: "canopy", locked: locked),
            color: shade(Color(hex: 0x4A3B78), locked: locked)
        ) { SCNSphere(radius: 36) }
        canopy.position = SCNVector3(0, 74, 0)
        root.addChildNode(canopy)

        // Faint magical glints — small emissive spheres, skipped when
        // locked (desaturation already communicates "not yet available").
        guard !locked else { return }
        let glintOffsets: [(CGFloat, CGFloat, CGFloat)] = [(-12, 60, 14), (5, 82, -10), (14, 66, 12)]
        for (index, offset) in glintOffsets.enumerated() {
            let glint = node(
                key: GeometryKey(species: .elderwood, part: "glint\(index)", locked: false),
                color: Color(hex: 0xB39DDB),
                emissive: true
            ) { SCNSphere(radius: 2.5) }
            glint.position = SCNVector3(
                SceneKitConversions.float(offset.0),
                SceneKitConversions.float(offset.1),
                SceneKitConversions.float(offset.2)
            )
            root.addChildNode(glint)
        }
    }

    // MARK: - Shared helpers

    /// Builds (or reuses a cached) `SCNGeometry`, wraps it in a fresh node.
    /// Geometry/material objects are shared across every tree of the same
    /// species; only the node (and its transform) is per-instance.
    private static func node(
        key: GeometryKey,
        color: Color,
        emissive: Bool = false,
        makeGeometry: () -> SCNGeometry
    ) -> SCNNode {
        if let cached = cache[key] {
            return SCNNode(geometry: cached)
        }
        let geometry = makeGeometry()
        let material = SCNMaterial()
        material.lightingModel = .lambert
        if emissive {
            material.emission.contents = SceneKitConversions.uiColor(color)
            material.diffuse.contents = SceneKitConversions.uiColor(color)
        } else {
            material.diffuse.contents = SceneKitConversions.uiColor(color)
        }
        geometry.materials = [material]
        geometry.subdivisionLevel = 0
        cache[key] = geometry
        return SCNNode(geometry: geometry)
    }

    /// Desaturates + darkens a color for level-locked trees, replacing the
    /// 2D lock badge (v1 trim).
    private static func shade(_ color: Color, locked: Bool) -> Color {
        guard locked else { return color }
        let ui = UIColor(color)
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        ui.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return Color(
            hue: Double(hue),
            saturation: Double(saturation) * 0.2,
            brightness: Double(brightness) * 0.75,
            opacity: Double(alpha)
        )
    }
}
