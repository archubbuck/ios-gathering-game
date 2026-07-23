import Foundation
import CoreGraphics

/// Translates between world-space coordinates and screen-space positions.
/// The camera follows the player so the player character always renders
/// at a fixed position slightly below the screen center (isometric
/// perspective).
struct Camera {
    /// World-space position the camera is centered on.
    var center: CGPoint

    /// The player's on-screen anchor — slightly below center to leave
    /// room for the sky and overhead UI.
    static let playerScreenAnchor = CGPoint(x: 0.5, y: 0.58)

    /// Convert a world-space point to a screen position within the given
    /// container size. Returns normalized unit coordinates (0–1).
    func screenUnit(for worldPos: CGPoint) -> CGPoint {
        let offsetX = worldPos.x - center.x
        let offsetY = worldPos.y - center.y
        return CGPoint(x: 0.5 + offsetX, y: 0.5 + offsetY)
    }

    /// Convert a world-space point to an absolute pixel position.
    func screenPoint(for worldPos: CGPoint, in size: CGSize) -> CGPoint {
        let unit = screenUnit(for: worldPos)
        return CGPoint(x: unit.x * size.width, y: unit.y * size.height)
    }

    /// The pixel position where the player should be drawn.
    func playerScreenPoint(in size: CGSize) -> CGPoint {
        CGPoint(
            x: Self.playerScreenAnchor.x * size.width,
            y: Self.playerScreenAnchor.y * size.height
        )
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
