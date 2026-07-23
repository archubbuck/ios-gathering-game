import SwiftUI

/// Small capsule stat readout used on dark wood surfaces (HUD, panels).
struct StatChip: View {
    let systemImage: String
    let text: String
    var tint: Color = SylvanTheme.gold

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.stat(13))
                .foregroundStyle(SylvanTheme.textOnWood)
                .monospacedDigit()
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.black.opacity(0.3)))
    }
}
