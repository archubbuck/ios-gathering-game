import SwiftUI

/// Segmented pill control used for Inventory|Bank and filter rows.
struct SegmentPills<Option: Hashable>: View {
    let options: [Option]
    let label: (Option) -> String
    @Binding var selection: Option

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selection = option
                    }
                } label: {
                    Text(label(option))
                        .font(.stat(14))
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule().fill(
                                selection == option
                                    ? SylvanTheme.forestGreen
                                    : SylvanTheme.parchmentEdge.opacity(0.45)
                            )
                        )
                        .foregroundStyle(
                            selection == option ? Color.white : SylvanTheme.textOnParchment
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
