import SwiftUI

/// Colors and constants from the "Nocturne" design system (Claude Design handoff:
/// `World Clock.dc.html` / `Sky.dc.html`). Custom typefaces (Inter) are deliberately
/// skipped in favor of the system font — same call made for the earlier Geist/JetBrains
/// Mono spec — since embedding fonts isn't worth it for a size/weight-driven hierarchy
/// system fonts already express (weight capped at 500, tabular numerals for clock digits).
enum Theme {
    static let ground = Color(hex: 0x161826)

    static let text = Color(hex: 0xe9e9ed)
    static let textBright = Color(hex: 0xf3f5fe)
    static let textBrightest = Color(hex: 0xf5f4ff)

    static let accent = Color(hex: 0x9184d9)     // center caret, selected row edge, glows
    static let accentText = Color(hex: 0xb5abfc)  // accent-colored labels/icons on dark
    static let accentLight = Color(hex: 0xc7c0fd)  // near-center wheel ticks

    static let glass = Color(hex: 0x121221)         // collapsed row / bottom wheel base
    static let glassExpanded = Color(hex: 0x10121e) // expanded row base

    static var hairline: Color { text.opacity(0.13) }

    enum Radius {
        static let row: CGFloat = 14
        static let bottomWheel: CGFloat = 16
        static let badge: CGFloat = 5
        static let pill: CGFloat = 999
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let base: CGFloat = 16
        static let lg: CGFloat = 20
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
