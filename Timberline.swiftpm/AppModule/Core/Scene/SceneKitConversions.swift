import CoreGraphics
import SceneKit
import SwiftUI

/// Single choke point for the two "compiles fine, wrong at runtime" traps in
/// the SceneKit rewrite: `CGFloat`→`Float` narrowing, and `Color`→`UIColor`
/// conversion for `SCNMaterial`/`SCNLight` properties (which are typed
/// `Any?` and silently accept — and misrender — a raw SwiftUI `Color`).
enum SceneKitConversions {
    static func float(_ value: CGFloat) -> Float { Float(value) }

    static func cgFloat(_ value: Float) -> CGFloat { CGFloat(value) }

    /// Maps a 2D world-space point onto the SceneKit ground plane (XZ),
    /// with `height` controlling the Y (up) coordinate.
    static func vector(_ worldPoint: CGPoint, height: CGFloat = 0) -> SCNVector3 {
        SCNVector3(float(worldPoint.x), float(height), float(worldPoint.y))
    }

    /// The only sanctioned way to hand a SwiftUI `Color` to
    /// `SCNMaterial.diffuse.contents`, `SCNMaterial.emission.contents`, or
    /// `SCNLight.color`. Never assign a raw `Color` at those sites.
    static func uiColor(_ color: Color) -> UIColor { UIColor(color) }

    static func radians(fromDegrees degrees: Double) -> Float { Float(degrees * .pi / 180) }
}
