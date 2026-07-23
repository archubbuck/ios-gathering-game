import SwiftUI

/// Native substitutes for the handoff's two web fonts (README "Typography"
/// section explicitly sanctions this): Bricolage Grotesque → SF Pro Rounded
/// for names/numbers/headers; Nunito Sans → default SF Pro Text for body
/// copy. No font files to bundle.
extension Font {
    /// Display type for names, big numbers, and section headers.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
