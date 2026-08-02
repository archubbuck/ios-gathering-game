import SceneKit
import SwiftUI

/// Builds faceted low-poly SceneKit tree nodes, one per world tree
/// instance, from a small set of shared per-species `SCNGeometry` objects
/// (cached, not rebuilt per instance). Shapes come from
/// `LowPolyGeometry`; colors from `TimberlineTheme.Scene3D`, the canonical
/// species palette.
///
/// Each species caches `variantCount` distinct shape sets (different
/// jitter seeds) so the forest doesn't read as copy-pasted; per-instance
/// yaw/scale variation is applied at the node level by
/// `ForestSceneView.upsertTreeNode`.
enum TreeGeometryFactory {
    /// Number of distinct cached shape sets per species.
    static let variantCount = 2

    private struct GeometryKey: Hashable {
        let species: TreeSpecies
        let part: String
        let locked: Bool
        let variant: Int
    }

    private static var cache: [GeometryKey: SCNGeometry] = [:]

    /// A full, choppable tree: trunk + canopy, desaturated when `locked`.
    static func makeTreeNode(species: TreeSpecies, locked: Bool, variant: Int = 0) -> SCNNode {
        let root = SCNNode()
        root.name = "tree"
        let variant = ((variant % variantCount) + variantCount) % variantCount

        switch species {
        case .birch: buildBirch(into: root, locked: locked, variant: variant)
        case .oak: buildOak(into: root, locked: locked, variant: variant)
        case .willow: buildWillow(into: root, locked: locked, variant: variant)
        case .evergreen: buildEvergreen(into: root, locked: locked, variant: variant)
        case .ancientYew: buildAncientYew(into: root, locked: locked, variant: variant)
        case .elderwood: buildElderwood(into: root, locked: locked, variant: variant)
        }
        return root
    }

    /// A depleted tree, shown while its `respawnUntil` timer counts down.
    /// One faceted flared column with a parchment cut-face cap.
    static func makeStumpNode(species: TreeSpecies, variant: Int = 0) -> SCNNode {
        let root = SCNNode()
        root.name = "stump"
        let variant = ((variant % variantCount) + variantCount) % variantCount

        let key = GeometryKey(species: species, part: "stump", locked: false, variant: variant)
        let stump = node(key: key) {
            LowPolyGeometry.taperedColumn(
                baseRadius: 13,
                topRadius: 11,
                height: 18,
                flare: 0.5,
                seed: seed(for: key),
                color: TimberlineTheme.Scene3D.trunkColor(for: species),
                capColor: TimberlineTheme.parchmentEdge
            )
        }
        root.addChildNode(stump)
        return root
    }

    // MARK: - Species builders

    private static func buildBirch(into root: SCNNode, locked: Bool, variant: Int) {
        let trunkKey = GeometryKey(species: .birch, part: "trunk", locked: locked, variant: variant)
        let trunk = node(key: trunkKey) {
            LowPolyGeometry.taperedColumn(
                baseRadius: 5.5,
                topRadius: 4,
                height: 52,
                flare: 0.3,
                seed: seed(for: trunkKey),
                color: shade(TimberlineTheme.Scene3D.birchBark, locked: locked),
                patchFraction: 0.15,
                patchColor: shade(TimberlineTheme.Scene3D.birchBarkPatch, locked: locked)
            )
        }
        root.addChildNode(trunk)

        let canopy = TimberlineTheme.Scene3D.canopy(for: .birch)
        let canopyKey = GeometryKey(species: .birch, part: "canopy", locked: locked, variant: variant)
        let blob = node(key: canopyKey) {
            LowPolyGeometry.facetedBlob(
                radius: 27,
                seed: seed(for: canopyKey),
                baseColor: shade(canopy.base, locked: locked),
                highlightColor: shade(canopy.highlight, locked: locked)
            )
        }
        blob.position = SCNVector3(0, 64, 0)
        root.addChildNode(blob)
    }

    private static func buildOak(into root: SCNNode, locked: Bool, variant: Int) {
        let trunkKey = GeometryKey(species: .oak, part: "trunk", locked: locked, variant: variant)
        let trunk = node(key: trunkKey) {
            LowPolyGeometry.taperedColumn(
                baseRadius: 9,
                topRadius: 6.5,
                height: 46,
                seed: seed(for: trunkKey),
                color: shade(TimberlineTheme.Scene3D.trunkColor(for: .oak), locked: locked)
            )
        }
        root.addChildNode(trunk)

        let canopy = TimberlineTheme.Scene3D.canopy(for: .oak)
        let lobes: [(part: String, radius: Float, position: SCNVector3)] = [
            ("lobe0", 21, SCNVector3(-19, 46, 0)),
            ("lobe1", 21, SCNVector3(19, 46, 0)),
            ("lobe2", 27, SCNVector3(0, 62, 0)),
        ]
        for lobe in lobes {
            let key = GeometryKey(species: .oak, part: lobe.part, locked: locked, variant: variant)
            let blob = node(key: key) {
                LowPolyGeometry.facetedBlob(
                    radius: lobe.radius,
                    seed: seed(for: key),
                    baseColor: shade(canopy.base, locked: locked),
                    highlightColor: shade(canopy.highlight, locked: locked)
                )
            }
            blob.position = lobe.position
            root.addChildNode(blob)
        }
    }

    private static func buildWillow(into root: SCNNode, locked: Bool, variant: Int) {
        let trunkKey = GeometryKey(species: .willow, part: "trunk", locked: locked, variant: variant)
        let trunk = node(key: trunkKey) {
            LowPolyGeometry.taperedColumn(
                baseRadius: 7,
                topRadius: 5,
                height: 48,
                seed: seed(for: trunkKey),
                color: shade(TimberlineTheme.Scene3D.trunkColor(for: .willow), locked: locked)
            )
        }
        root.addChildNode(trunk)

        let canopy = TimberlineTheme.Scene3D.canopy(for: .willow)
        let capKey = GeometryKey(species: .willow, part: "canopy", locked: locked, variant: variant)
        let cap = node(key: capKey) {
            LowPolyGeometry.facetedBlob(
                radius: 22,
                squash: 0.8,
                seed: seed(for: capKey),
                baseColor: shade(canopy.base, locked: locked),
                highlightColor: shade(canopy.highlight, locked: locked)
            )
        }
        cap.position = SCNVector3(0, 58, 0)
        root.addChildNode(cap)

        // Drooping cascade of jagged strips ringing the canopy.
        let frondKey = GeometryKey(species: .willow, part: "fronds", locked: locked, variant: variant)
        let fronds = node(key: frondKey) {
            LowPolyGeometry.frondSkirt(
                attachRadius: 18,
                attachHeight: 56,
                dropLength: 30,
                outwardBulge: 14,
                seed: seed(for: frondKey),
                color: shade(TimberlineTheme.Scene3D.willowFrond, locked: locked),
                highlightColor: shade(canopy.highlight, locked: locked)
            )
        }
        root.addChildNode(fronds)
    }

    private static func buildEvergreen(into root: SCNNode, locked: Bool, variant: Int) {
        let trunkKey = GeometryKey(species: .evergreen, part: "trunk", locked: locked, variant: variant)
        let trunk = node(key: trunkKey) {
            LowPolyGeometry.taperedColumn(
                baseRadius: 6,
                topRadius: 5,
                height: 30,
                seed: seed(for: trunkKey),
                color: shade(TimberlineTheme.Scene3D.trunkColor(for: .evergreen), locked: locked)
            )
        }
        root.addChildNode(trunk)

        let canopy = TimberlineTheme.Scene3D.canopy(for: .evergreen)
        let layers: [(part: String, base: Float, height: Float, y: Float)] = [
            ("cone0", 30, 30, 26),
            ("cone1", 24, 26, 42),
            ("cone2", 18, 22, 58),
        ]
        for (index, layer) in layers.enumerated() {
            let key = GeometryKey(species: .evergreen, part: layer.part, locked: locked, variant: variant)
            let base = index.isMultiple(of: 2) ? canopy.base : canopy.highlight
            let highlight = index.isMultiple(of: 2) ? canopy.highlight : canopy.base
            let cone = node(key: key) {
                LowPolyGeometry.taperedColumn(
                    baseRadius: layer.base,
                    topRadius: 1.5,
                    height: layer.height,
                    flare: 0,
                    jitter: 0.12,
                    seed: seed(for: key),
                    color: shade(base, locked: locked),
                    patchFraction: 0.25,
                    patchColor: shade(highlight, locked: locked)
                )
            }
            cone.position = SCNVector3(0, layer.y, 0)
            root.addChildNode(cone)
        }
    }

    private static func buildAncientYew(into root: SCNNode, locked: Bool, variant: Int) {
        let trunkKey = GeometryKey(species: .ancientYew, part: "trunk", locked: locked, variant: variant)
        let trunk = node(key: trunkKey) {
            LowPolyGeometry.taperedColumn(
                baseRadius: 11,
                topRadius: 8,
                height: 42,
                flare: 0.45,
                seed: seed(for: trunkKey),
                color: shade(TimberlineTheme.Scene3D.trunkColor(for: .ancientYew), locked: locked)
            )
        }
        root.addChildNode(trunk)

        let canopy = TimberlineTheme.Scene3D.canopy(for: .ancientYew)
        let blobs: [(part: String, radius: Float, position: SCNVector3)] = [
            ("canopy", 36, SCNVector3(0, 64, 0)),
            ("canopyTop", 20, SCNVector3(13, 80, 7)),
        ]
        for blob in blobs {
            let key = GeometryKey(species: .ancientYew, part: blob.part, locked: locked, variant: variant)
            let child = node(key: key) {
                LowPolyGeometry.facetedBlob(
                    radius: blob.radius,
                    seed: seed(for: key),
                    baseColor: shade(canopy.base, locked: locked),
                    highlightColor: shade(canopy.highlight, locked: locked)
                )
            }
            child.position = blob.position
            root.addChildNode(child)
        }
    }

    private static func buildElderwood(into root: SCNNode, locked: Bool, variant: Int) {
        let trunkKey = GeometryKey(species: .elderwood, part: "trunk", locked: locked, variant: variant)
        let trunk = node(key: trunkKey) {
            LowPolyGeometry.taperedColumn(
                baseRadius: 13,
                topRadius: 9,
                height: 48,
                flare: 0.4,
                seed: seed(for: trunkKey),
                color: shade(TimberlineTheme.Scene3D.trunkColor(for: .elderwood), locked: locked)
            )
        }
        root.addChildNode(trunk)

        let canopy = TimberlineTheme.Scene3D.canopy(for: .elderwood)
        let blobs: [(part: String, radius: Float, position: SCNVector3)] = [
            ("canopy", 34, SCNVector3(0, 72, 0)),
            ("canopyTop", 18, SCNVector3(-10, 92, 6)),
        ]
        for blob in blobs {
            let key = GeometryKey(species: .elderwood, part: blob.part, locked: locked, variant: variant)
            let child = node(key: key) {
                LowPolyGeometry.facetedBlob(
                    radius: blob.radius,
                    seed: seed(for: key),
                    baseColor: shade(canopy.base, locked: locked),
                    highlightColor: shade(canopy.highlight, locked: locked)
                )
            }
            child.position = blob.position
            root.addChildNode(child)
        }

        // Faint magical glints — small emissive spheres, skipped when
        // locked (desaturation already communicates "not yet available").
        guard !locked else { return }
        let glintOffsets: [(CGFloat, CGFloat, CGFloat)] = [(-12, 60, 14), (5, 82, -10), (14, 66, 12)]
        for (index, offset) in glintOffsets.enumerated() {
            let glint = node(
                key: GeometryKey(species: .elderwood, part: "glint\(index)", locked: false, variant: 0),
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

    /// Deterministic per-part seed. Uses the species' fixed ordinal in
    /// `allCases` plus an FNV-1a fold of the part name — never
    /// `hashValue`, which is randomized per launch and would subtly
    /// reshape cached geometry between runs.
    private static func seed(for key: GeometryKey) -> UInt64 {
        let ordinal = UInt64(TreeSpecies.allCases.firstIndex(of: key.species) ?? 0)
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in key.part.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
        }
        return hash ^ (ordinal &<< 8) ^ (UInt64(key.variant) &<< 4) ^ (key.locked ? 1 : 0)
    }

    /// Caches a fully-materialed geometry (custom `LowPolyGeometry`
    /// builders own their materials) and wraps it in a fresh node.
    private static func node(key: GeometryKey, make: () -> SCNGeometry) -> SCNNode {
        if let cached = cache[key] {
            return SCNNode(geometry: cached)
        }
        let geometry = make()
        cache[key] = geometry
        return SCNNode(geometry: geometry)
    }

    /// Builds (or reuses a cached) stock-primitive `SCNGeometry` with a
    /// single material — still used for the elderwood glints.
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
