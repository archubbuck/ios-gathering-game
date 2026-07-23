import SwiftUI

/// Compact OSRS-style chat log pinned under the forest scene.
struct EventLogView: View {
    let entries: [EventLogEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(entries.suffix(4)) { entry in
                Text(entry.text)
                    .font(.stat(12, weight: .regular))
                    .foregroundStyle(color(for: entry.kind))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .bottomLeading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [SylvanTheme.woodPanelTop, SylvanTheme.woodPanelBottom],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    private func color(for kind: EventLogEntry.Kind) -> Color {
        switch kind {
        case .info: return SylvanTheme.textOnWood.opacity(0.75)
        case .chop: return SylvanTheme.textOnWood
        case .warning: return Color(hex: 0xFFAB91)
        case .levelUp, .achievement: return SylvanTheme.gold
        }
    }
}
