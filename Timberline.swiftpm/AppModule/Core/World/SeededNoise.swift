import CoreGraphics

/// Deterministic 2D value noise seeded from a world seed.
struct SeededNoise2D {
    let seed: UInt64

    func noise(x: CGFloat, y: CGFloat) -> Double {
        let ix0 = Int(floor(x))
        let iy0 = Int(floor(y))
        let ix1 = ix0 + 1
        let iy1 = iy0 + 1

        let fx = x - CGFloat(ix0)
        let fy = y - CGFloat(iy0)

        let v00 = value(atX: ix0, y: iy0)
        let v10 = value(atX: ix1, y: iy0)
        let v01 = value(atX: ix0, y: iy1)
        let v11 = value(atX: ix1, y: iy1)

        let ix0v = mix(v00, v10, t: cubicSmooth(Double(fx)))
        let ix1v = mix(v01, v11, t: cubicSmooth(Double(fx)))
        return mix(ix0v, ix1v, t: cubicSmooth(Double(fy)))
    }

    private func value(atX x: Int, y: Int) -> Double {
        var h = seed
        h = h &* 0x9E3779B97F4A7C15 &+ UInt64(bitPattern: Int64(x))
        h = h &* 0x9E3779B97F4A7C15 &+ UInt64(bitPattern: Int64(y))
        h = (h ^ (h >> 30)) &* 0xBF58476D1CE4E5B9
        h = (h ^ (h >> 27)) &* 0x94D049BB133111EB
        h = h ^ (h >> 31)
        return Double(h & 0xFFFFFFFF) / Double(UInt32.max)
    }

    private func mix(_ a: Double, _ b: Double, t: Double) -> Double {
        a * (1 - t) + b * t
    }

    private func cubicSmooth(_ x: Double) -> Double {
        x * x * (3 - 2 * x)
    }
}
