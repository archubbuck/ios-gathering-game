import Foundation
import CoreGraphics

/// Tracks the world-space point the 3D scene camera follows.
struct Camera {
    /// World-space position the camera is centered on.
    var center: CGPoint

    /// Pinch-to-zoom multiplier applied to `ForestSceneView`'s base
    /// orthographic scale (>1 zooms in/closer, <1 zooms out/farther).
    /// Purely visual — not persisted, so zoom resets to default on
    /// relaunch like `stamina` and other transient state.
    var zoomScale: CGFloat = 1.0

    /// Below this distance (world units) between `center` and the follow
    /// target, the camera is considered converged. `GameState` uses this
    /// to skip calling `follow` entirely once the camera catches up to an
    /// idle player — `center` lives behind `@Published`, so even a no-op
    /// assignment inside `follow` would still fire a change notification
    /// every frame; the caller must avoid invoking `follow` altogether.
    static let convergenceEpsilon: CGFloat = 0.05

    /// Pinch-zoom bounds, tuned around `ForestSceneView`'s base
    /// orthographic scale of 350: 0.5 zooms out to a ~700-unit-tall view,
    /// 2.5 zooms in to a ~140-unit-tall view.
    static let minZoomScale: CGFloat = 0.5
    static let maxZoomScale: CGFloat = 2.5

    /// Clamps a raw pinch-gesture multiplier to `minZoomScale...maxZoomScale`.
    static func clampedZoom(_ value: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minZoomScale), maxZoomScale)
    }

    /// Smoothly interpolate the camera toward a target world position.
    mutating func follow(target worldPos: CGPoint, lerp factor: CGFloat = 0.12) {
        center.x += (worldPos.x - center.x) * factor
        center.y += (worldPos.y - center.y) * factor
    }

    /// Snap the camera instantly to a position (used on initial load).
    mutating func snap(to worldPos: CGPoint) {
        center = worldPos
    }
}
