import SceneKit
import SwiftUI
import simd

/// Procedural faceted ("low-poly") mesh builders for the 3D forest.
///
/// Every builder returns a finished `SCNGeometry` with materials already
/// attached. Facets are flat-shaded by duplicating vertices per triangle
/// with a normal derived from winding order (counter-clockwise viewed from
/// outside = front face). "Lighter highlight facets" use a second
/// `SCNGeometryElement` with its own material — SceneKit maps
/// `geometry.materials[i]` to `geometry.elements[i]` — rather than
/// per-vertex colors, whose interaction with `.lambert` is undocumented.
///
/// All randomness flows through `SeededRandom`: identical seed → identical
/// mesh, so cached geometry is stable across launches.
enum LowPolyGeometry {
    // MARK: - Faceted blob (canopies, rocks)

    /// Irregular jittered sphere with visible flat facets; a fraction of
    /// facets use `highlightColor` for the "lighter polygons on the
    /// surface" look. `squash` scales Y (1 = round, <1 = flattened).
    static func facetedBlob(
        radius: Float,
        rings: Int = 3,
        sides: Int = 7,
        jitter: Float = 0.18,
        squash: Float = 1.0,
        highlightFraction: Float = 0.3,
        seed: UInt64,
        baseColor: Color,
        highlightColor: Color
    ) -> SCNGeometry {
        var rng = SeededRandom(seed: seed)
        var mesh = FacetMesh(bucketCount: 2)

        func jittered(_ p: SIMD3<Float>) -> SIMD3<Float> {
            var q = p * (1 + jitter * (rng.nextFloat() * 2 - 1))
            q.y *= squash
            return q
        }

        var ringVertices: [[SIMD3<Float>]] = []
        for ring in 1...max(rings, 1) {
            let phi = Float.pi * Float(ring) / Float(max(rings, 1) + 1)
            let phase = rng.nextFloat() * (2 * .pi / Float(sides))
            var current: [SIMD3<Float>] = []
            for side in 0..<sides {
                let theta = 2 * .pi * Float(side) / Float(sides) + phase
                let p = SIMD3<Float>(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta)) * radius
                current.append(jittered(p))
            }
            ringVertices.append(current)
        }
        let topPole = jittered(SIMD3<Float>(0, radius, 0))
        let bottomPole = jittered(SIMD3<Float>(0, -radius, 0))

        func roll() -> Int { rng.nextFloat() < highlightFraction ? 1 : 0 }

        // Top fan (CCW from outside → +Y-ish normals).
        let first = ringVertices[0]
        for side in 0..<sides {
            let next = (side + 1) % sides
            mesh.addTriangle(topPole, first[next], first[side], bucket: roll())
        }
        // Bands between adjacent rings; one bucket roll per quad so
        // highlights read as whole facets.
        for ring in 0..<(ringVertices.count - 1) {
            let upper = ringVertices[ring]
            let lower = ringVertices[ring + 1]
            for side in 0..<sides {
                let next = (side + 1) % sides
                let bucket = roll()
                mesh.addTriangle(upper[side], lower[next], lower[side], bucket: bucket)
                mesh.addTriangle(upper[side], upper[next], lower[next], bucket: bucket)
            }
        }
        // Bottom fan (winding mirrored vs. top).
        let last = ringVertices[ringVertices.count - 1]
        for side in 0..<sides {
            let next = (side + 1) % sides
            mesh.addTriangle(bottomPole, last[side], last[next], bucket: roll())
        }

        return mesh.geometry(materials: [
            material(baseColor),
            material(highlightColor),
        ])
    }

    /// Squat jittered blob for boulders. Callers should sink the node by
    /// `~0.15 * radius` so the irregular underside stays buried.
    static func facetedRock(
        radius: Float,
        seed: UInt64,
        baseColor: Color,
        highlightColor: Color
    ) -> SCNGeometry {
        facetedBlob(
            radius: radius,
            rings: 2,
            sides: 6,
            jitter: 0.28,
            squash: 0.6,
            highlightFraction: 0.25,
            seed: seed,
            baseColor: baseColor,
            highlightColor: highlightColor
        )
    }

    // MARK: - Tapered column (trunks, stumps, evergreen cone layers)

    /// Faceted tapering column with origin at its base (y = 0). With
    /// `flare > 0` the bottom ring widens into a root flare up to
    /// `flareHeight`; with `flare == 0` it is a plain two-ring frustum
    /// (set a small `topRadius` for a cone). The top is capped (visible
    /// from the game's high camera). `patchFraction`/`patchColor` recolor
    /// random side facets (birch bark marks); `capColor` tints the cap
    /// (stump cut face).
    static func taperedColumn(
        baseRadius: Float,
        topRadius: Float,
        height: Float,
        sides: Int = 7,
        flare: Float = 0.35,
        flareHeight: Float = 6,
        jitter: Float = 0.08,
        seed: UInt64,
        color: Color,
        capColor: Color? = nil,
        patchFraction: Float = 0,
        patchColor: Color? = nil
    ) -> SCNGeometry {
        var rng = SeededRandom(seed: seed)
        var mesh = FacetMesh(bucketCount: 3)

        // Bottom → top ring levels (y, radius).
        let flared: [(y: Float, radius: Float)] = [
            (0, baseRadius * (1 + flare)),
            (flareHeight, baseRadius),
            (height, topRadius),
        ]
        let straight: [(y: Float, radius: Float)] = [(0, baseRadius), (height, topRadius)]
        let levels = (flare > 0 && flareHeight < height) ? flared : straight

        var ringVertices: [[SIMD3<Float>]] = []
        for level in levels {
            let phase = rng.nextFloat() * (2 * .pi / Float(sides))
            var current: [SIMD3<Float>] = []
            for side in 0..<sides {
                let theta = 2 * .pi * Float(side) / Float(sides) + phase
                let wobble = 1 + jitter * (rng.nextFloat() * 2 - 1)
                current.append(SIMD3<Float>(
                    cos(theta) * level.radius * wobble,
                    level.y,
                    sin(theta) * level.radius * wobble
                ))
            }
            ringVertices.append(current)
        }

        // Side bands, bottom ring = lower, next ring = upper.
        for ring in 0..<(ringVertices.count - 1) {
            let lower = ringVertices[ring]
            let upper = ringVertices[ring + 1]
            for side in 0..<sides {
                let next = (side + 1) % sides
                let bucket = (patchColor != nil && rng.nextFloat() < patchFraction) ? 1 : 0
                mesh.addTriangle(upper[side], lower[next], lower[side], bucket: bucket)
                mesh.addTriangle(upper[side], upper[next], lower[next], bucket: bucket)
            }
        }

        // Top cap fan around the ring's centroid.
        let top = ringVertices[ringVertices.count - 1]
        var centroid = SIMD3<Float>(0, 0, 0)
        for vertex in top { centroid += vertex }
        centroid /= Float(sides)
        let capBucket = capColor != nil ? 2 : 0
        for side in 0..<sides {
            let next = (side + 1) % sides
            mesh.addTriangle(centroid, top[next], top[side], bucket: capBucket)
        }

        return mesh.geometry(materials: [
            material(color),
            material(patchColor ?? color),
            material(capColor ?? color),
        ])
    }

    // MARK: - Ground patch (dirt/sand polygons)

    /// Irregular flat polygon in the XZ plane at y = 0, facing +Y. Callers
    /// float it slightly above the ground plane to avoid z-fighting and
    /// disable its shadow casting.
    static func groundPatch(
        radius: Float,
        sides: Int = 6,
        jitter: Float = 0.3,
        seed: UInt64,
        color: Color
    ) -> SCNGeometry {
        var rng = SeededRandom(seed: seed)
        var mesh = FacetMesh(bucketCount: 1)

        var ring: [SIMD3<Float>] = []
        for side in 0..<sides {
            let wedge = 2 * .pi / Float(sides)
            let theta = wedge * Float(side) + wedge * 0.25 * (rng.nextFloat() * 2 - 1)
            let r = radius * (1 + jitter * (rng.nextFloat() * 2 - 1))
            ring.append(SIMD3<Float>(cos(theta) * r, 0, sin(theta) * r))
        }
        let center = SIMD3<Float>(0, 0, 0)
        for side in 0..<sides {
            let next = (side + 1) % sides
            mesh.addTriangle(center, ring[next], ring[side], bucket: 0)
        }

        return mesh.geometry(materials: [material(color, doubleSided: true)])
    }

    // MARK: - Frond skirt (willow)

    /// Ring of drooping jagged strips hanging from `attachHeight`, bulging
    /// outward then curling back in toward the tips. Alternating fronds use
    /// the highlight color for a layered light/dark cascade.
    static func frondSkirt(
        attachRadius: Float,
        attachHeight: Float,
        dropLength: Float,
        outwardBulge: Float,
        fronds: Int = 10,
        frondWidth: Float = 8,
        seed: UInt64,
        color: Color,
        highlightColor: Color
    ) -> SCNGeometry {
        var rng = SeededRandom(seed: seed)
        var mesh = FacetMesh(bucketCount: 2)

        for frond in 0..<fronds {
            let wedge = 2 * .pi / Float(fronds)
            let theta = wedge * Float(frond) + wedge * 0.3 * (rng.nextFloat() * 2 - 1)
            let direction = SIMD3<Float>(cos(theta), 0, sin(theta))
            let tangent = SIMD3<Float>(-sin(theta), 0, cos(theta))

            let length = dropLength * (0.8 + 0.4 * rng.nextFloat())
            let halfWidth = tangent * (frondWidth * (0.8 + 0.4 * rng.nextFloat()) / 2)

            let attach = direction * attachRadius + SIMD3<Float>(0, attachHeight, 0)
            let mid = attach + direction * outwardBulge - SIMD3<Float>(0, 0.45 * length, 0)
            let tip = attach + direction * (0.7 * outwardBulge) - SIMD3<Float>(0, length, 0)

            let bucket = frond % 2
            // Tapering jagged strip: wide at attach, narrower at mid,
            // pointed tip. Double-sided material so winding is forgiving.
            mesh.addTriangle(attach - halfWidth, attach + halfWidth, mid + halfWidth * 0.6, bucket: bucket)
            mesh.addTriangle(attach - halfWidth, mid + halfWidth * 0.6, mid - halfWidth * 0.6, bucket: bucket)
            mesh.addTriangle(mid - halfWidth * 0.6, mid + halfWidth * 0.6, tip, bucket: bucket)
        }

        return mesh.geometry(materials: [
            material(color, doubleSided: true),
            material(highlightColor, doubleSided: true),
        ])
    }

    // MARK: - Internals

    /// Accumulates flat-shaded triangles into per-material index buckets.
    /// Vertices are duplicated per triangle so each face keeps its own
    /// normal — that duplication *is* the faceted look.
    private struct FacetMesh {
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var buckets: [[Int32]]

        init(bucketCount: Int) {
            buckets = Array(repeating: [], count: bucketCount)
        }

        mutating func addTriangle(
            _ a: SIMD3<Float>,
            _ b: SIMD3<Float>,
            _ c: SIMD3<Float>,
            bucket: Int
        ) {
            let raw = simd_cross(b - a, c - a)
            let length = simd_length(raw)
            // Degenerate (zero-area) triangles would yield NaN normals;
            // fall back to +Y rather than poisoning the vertex buffer.
            let normal = length > 1e-6 ? raw / length : SIMD3<Float>(0, 1, 0)
            let base = Int32(vertices.count)
            for point in [a, b, c] {
                vertices.append(SCNVector3(point.x, point.y, point.z))
                normals.append(SCNVector3(normal.x, normal.y, normal.z))
            }
            buckets[bucket].append(contentsOf: [base, base + 1, base + 2])
        }

        /// Zips buckets with materials, dropping empty buckets *and* their
        /// materials together so elements/materials can never misalign.
        func geometry(materials: [SCNMaterial]) -> SCNGeometry {
            let pairs = Array(zip(buckets, materials)).filter { !$0.0.isEmpty }
            let geometry = SCNGeometry(
                sources: [
                    SCNGeometrySource(vertices: vertices),
                    SCNGeometrySource(normals: normals),
                ],
                elements: pairs.map {
                    SCNGeometryElement(indices: $0.0, primitiveType: .triangles)
                }
            )
            geometry.materials = pairs.map { $0.1 }
            return geometry
        }
    }

    private static func material(_ color: Color, doubleSided: Bool = false) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .lambert
        material.diffuse.contents = SceneKitConversions.uiColor(color)
        material.isDoubleSided = doubleSided
        return material
    }
}

extension SeededRandom {
    /// Convenience mirroring `nextCGFloat()` for SceneKit-side Float math.
    mutating func nextFloat() -> Float {
        Float(nextCGFloat())
    }
}
