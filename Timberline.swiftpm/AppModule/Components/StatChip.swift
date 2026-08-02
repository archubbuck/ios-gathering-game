import SwiftUI

/// Small capsule stat readout. Defaults suit dark wood surfaces; pass
/// `onLight: true` for the forest HUD's light strip.
struct StatChip: View {
    let systemImage: String
    let text: String
    var tint: Color = TimberlineTheme.gold
    var onLight: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.stat(13))
                .foregroundStyle(onLight ? TimberlineTheme.hudTextDark : TimberlineTheme.textOnWood)
                .monospacedDigit()
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(onLight ? Color.black.opacity(0.08) : Color.black.opacity(0.3))
        )
    }
}
