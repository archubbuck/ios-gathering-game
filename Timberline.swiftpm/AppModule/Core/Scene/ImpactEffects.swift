import Foundation
import CoreGraphics

/// Shared renderer-agnostic values for the physical chop response.
enum ImpactEffects {
    static let contactPoint = CGPoint(x: 8, y: 22)
    static let chipLifetime: TimeInterval = 0.42
    static let treeShakeAngle: CGFloat = 0.045
    static let logBounceHeight: CGFloat = 20
}
