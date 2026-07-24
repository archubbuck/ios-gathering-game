import SwiftUI

/// Compact OSRS-style chat log, floating as a frosted panel over the
/// forest scene's bottom-leading corner.
struct EventLogView: View {
    let entries: [EventLogEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(entries.suffix(4)) { entry in
                Text(entry.text)
                    .font(.stat(12, weight: .medium))
                    .foregroundStyle(color(for: entry.kind))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: 250, minHeight: 62, alignment: .bottomLeading)
        .padding(12)
        .hudPanel(cornerRadius: 18, tint: 0.5)
        .allowsHitTesting(false)
    }

    private func color(for kind: EventLogEntry.Kind) -> Color {
        switch kind {
        case .info: return SylvanTheme.hudTextDark.opacity(0.75)
        case .chop: return SylvanTheme.hudTextDark
        case .warning: return SylvanTheme.hudLogWarning
        case .levelUp, .achievement: return SylvanTheme.hudLogGold
        }
    }
}
