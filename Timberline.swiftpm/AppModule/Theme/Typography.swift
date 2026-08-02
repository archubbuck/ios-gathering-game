import SwiftUI

/// Medieval-fantasy type without bundling font files: the system serif
/// design (New York) stands in for the PRD's EB Garamond headings, and
/// rounded monospaced-digit styles keep stat numerals steady.
extension Font {
    /// Serif display type for headings, level numbers, and screen titles.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Rounded numeric style for stats (XP, gold, counts).
    static func stat(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
