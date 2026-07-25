import Foundation
import CoreGraphics

/// Tracks the world-space point the 3D scene camera follows.
struct Camera {
    /// World-space position the camera is centered on.
    var center: CGPoint

    /// Below this distance (world units) between `center` and the follow
    /// target, the camera is considered converged. `GameState` uses this
    /// to skip calling `follow` entirely once the camera catches up to an
    /// idle player — `center` lives behind `@Published`, so even a no-op
    /// assignment inside `follow` would still fire a change notification
    /// every frame; the caller must avoid invoking `follow` altogether.
    static let convergenceEpsilon: CGFloat = 0.05

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
