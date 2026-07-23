import SwiftUI

/// Settings → Theme color: 5 gradient swatches, selected = double ring in
/// that palette's own accent. Choosing "their" color is a one-tap,
/// low-commitment delight that creates ownership (Decision 8).
struct ThemeSwatchPicker: View {
    @Binding var selection: Palette

    var body: some View {
        HStack(spacing: 14) {
            ForEach(Palette.allCases) { palette in
                let swatchTheme = palette.theme
                Button {
                    selection = palette
                } label: {
                    Circle()
                        .fill(swatchTheme.heroGradient)
                        .frame(width: 34, height: 34)
                        .overlay {
                            if selection == palette {
                                Circle()
                                    .strokeBorder(swatchTheme.accent, lineWidth: 3)
                                    .padding(-4)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(palette.displayName)
                .accessibilityAddTraits(selection == palette ? .isSelected : [])
            }
        }
    }
}
