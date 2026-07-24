import Foundation
import CoreGraphics

/// Tracks the world-space point the 3D scene camera follows.
struct Camera {
    /// World-space position the camera is centered on.
    var center: CGPoint

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
