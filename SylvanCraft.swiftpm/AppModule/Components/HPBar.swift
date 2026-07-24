import SwiftUI

/// Frosted HP pill for the forest HUD's top-leading corner: icon tile,
/// "HP" caps label, and a wide value bar. HP is a real hazard — chopping
/// while exhausted drains it — so the fill stays saturated red rather
/// than reading as pure decoration.
struct HPBar: View {
    let hp: Double
    let maxHP: Double

    private var fraction: Double {
        guard maxHP > 0 else { return 0 }
        return max(0, min(1, hp / maxHP))
    }

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.85))
                .frame(width: 26, height: 26)
                .overlay(
                    Image(systemName: "heart.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SylvanTheme.hudHP)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("HP")
                    .font(.stat(10, weight: .heavy))
                    .kerning(0.5)
                    .foregroundStyle(SylvanTheme.hudTextDark.opacity(0.85))

                ZStack(alignment: .leading) {
                    Capsule().fill(SylvanTheme.hudTrack)
                    Capsule()
                        .fill(SylvanTheme.hudHP)
                        .frame(width: 150 * fraction)
                    Capsule().strokeBorder(Color.black.opacity(0.1), lineWidth: 1)
                }
                .frame(width: 150, height: 16)
                .overlay(
                    Text("\(Int(hp.rounded()))/\(Int(maxHP.rounded()))")
                        .font(.stat(10, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 1, y: 0.5)
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .hudPanel(cornerRadius: 16)
    }
}
