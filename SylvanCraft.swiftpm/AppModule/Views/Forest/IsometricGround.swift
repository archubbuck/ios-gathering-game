import SwiftUI

/// A scrolling isometric diamond-tile ground that follows the camera.
/// Only tiles visible on screen are drawn; the grid appears infinite.
struct IsometricGround: View {
    let camera: Camera
    let screenSize: CGSize

    /// World-space size of one diamond tile edge-to-edge.
    private static let tileWorldWidth: CGFloat = 160
    private static let tileWorldHeight: CGFloat = 80

    var body: some View {
        Canvas { context, size in
            let camX = camera.center.x
            let camY = camera.center.y

            // Determine visible world bounds in camera space.
            let visibleHalfW = size.width / 2
            let visibleHalfH = size.height / 2

            // World bounds the camera can see (approximate).
            let minWorldX = camX - visibleHalfW - Self.tileWorldWidth
            let maxWorldX = camX + visibleHalfW + Self.tileWorldWidth
            let minWorldY = camY - visibleHalfH - Self.tileWorldHeight
            let maxWorldY = camY + visibleHalfH + Self.tileWorldHeight

            // Iterate over visible tiles in world-grid space.
            let tileStepX = Self.tileWorldWidth / 2
            let tileStepY = Self.tileWorldHeight / 2

            let startCol = Int(floor(minWorldX / tileStepX)) - 1
            let endCol = Int(ceil(maxWorldX / tileStepX)) + 1
            let startRow = Int(floor(minWorldY / tileStepY)) - 2
            let endRow = Int(ceil(maxWorldY / tileStepY)) + 2

            for col in startCol...endCol {
                for row in startRow...endRow {
                    // World position of this tile's center.
                    let wx = CGFloat(col) * tileStepX
                    let wy = CGFloat(row) * tileStepY

                    // Convert to screen position.
                    let sx = (wx - camX) + size.width / 2
                    let sy = (wy - camY) + size.height / 2

                    // Skip if completely off screen.
                    guard sx > -Self.tileWorldWidth,
                          sx < size.width + Self.tileWorldWidth,
                          sy > -Self.tileWorldHeight,
                          sy < size.height + Self.tileWorldHeight
                    else { continue }

                    var tile = Path()
                    tile.move(to: CGPoint(x: sx, y: sy - tileStepY))
                    tile.addLine(to: CGPoint(x: sx + tileStepX, y: sy))
                    tile.addLine(to: CGPoint(x: sx, y: sy + tileStepY))
                    tile.addLine(to: CGPoint(x: sx - tileStepX, y: sy))
                    tile.closeSubpath()

                    let isLight = (row + col).isMultiple(of: 2)
                    let baseColor = isLight ? SylvanTheme.groundLight : SylvanTheme.groundDark

                    // Slight biome tint based on world position.
                    let hueShift = sin(wx * 0.0003) * 0.04 + cos(wy * 0.0003) * 0.04
                    let tinted = baseColor.opacity(0.85 + hueShift)

                    context.fill(tile, with: .color(tinted))
                }
            }
        }
    }
}

