import SwiftUI

/// The 2.5D forest floor: a diamond-tile isometric grid drawn in Canvas,
/// two alternating greens with a soft vignette toward the horizon.
struct IsometricGround: View {
    var body: some View {
        Canvas { context, size in
            let tileWidth: CGFloat = size.width / 3.2
            let tileHeight = tileWidth / 2
            let originX = size.width / 2
            let originY = size.height * 0.12

            for row in -1...8 {
                for col in -4...4 {
                    let x = originX + CGFloat(col - row) * tileWidth / 2
                    let y = originY + CGFloat(col + row) * tileHeight / 2
                    guard y < size.height + tileHeight else { continue }

                    var tile = Path()
                    tile.move(to: CGPoint(x: x, y: y - tileHeight / 2))
                    tile.addLine(to: CGPoint(x: x + tileWidth / 2, y: y))
                    tile.addLine(to: CGPoint(x: x, y: y + tileHeight / 2))
                    tile.addLine(to: CGPoint(x: x - tileWidth / 2, y: y))
                    tile.closeSubpath()

                    let isLight = (row + col).isMultiple(of: 2)
                    let color = isLight ? SylvanTheme.groundLight : SylvanTheme.groundDark
                    // Fade distant rows slightly for depth.
                    let depthFade = 0.75 + 0.25 * min(1, y / size.height)
                    context.fill(tile, with: .color(color.opacity(depthFade)))
                }
            }
        }
    }
}
