import SwiftUI

/// Initial-letter avatar. The same two identities — "You" (theme gradient)
/// and the partner (solid accent) — recur across the pairing bar, the match
/// hero, and Settings (Decision 5 of DESIGN_RATIONALE.md), so this is the one
/// place that visual motif lives.
struct GradientAvatarView: View {
    enum Shape { case circle, roundedSquare }

    let initial: String
    private let fill: AnyShapeStyle
    var shape: Shape = .circle
    var size: CGFloat = 46

    init(initial: String, fill: some ShapeStyle, shape: Shape = .circle, size: CGFloat = 46) {
        self.initial = initial
        self.fill = AnyShapeStyle(fill)
        self.shape = shape
        self.size = size
    }

    var body: some View {
        ZStack {
            switch shape {
            case .circle:
                Circle().fill(fill)
            case .roundedSquare:
                RoundedRectangle(cornerRadius: size * 0.32).fill(fill)
            }
            Text(initial.uppercased())
                .font(.display(size * 0.42))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}
