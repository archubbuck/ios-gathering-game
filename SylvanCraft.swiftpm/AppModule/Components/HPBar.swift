import SwiftUI

/// Compact HP readout for the forest HUD's top-leading corner. HP is a real
/// hazard — chopping while exhausted drains it — so the fill turns red-hot
/// rather than reading as pure decoration.
struct HPBar: View {
    let hp: Double
    let maxHP: Double

    private var fraction: Double {
        guard maxHP > 0 else { return 0 }
        return max(0, min(1, hp / maxHP))
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "heart.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: 0xE0524C))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.35))
                    Capsule()
                        .fill(Color(hex: 0xE0524C))
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(width: 74, height: 8)

            Text("\(Int(hp.rounded()))")
                .font(.stat(11))
                .foregroundStyle(SylvanTheme.textOnWood)
                .monospacedDigit()
                .frame(width: 24, alignment: .trailing)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.black.opacity(0.3)))
    }
}
