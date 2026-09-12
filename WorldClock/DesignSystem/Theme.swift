import SwiftUI

/// Colors and constants pulled from the Stitch "Atmospheric Horizon" design-system spec
/// generated for this app. Custom fonts (Geist, JetBrains Mono) are deliberately skipped —
/// see the build plan — in favor of system SF Pro / .monospaced digit design.
enum Theme {
    static let primary = Color(hex: 0xAAC7FF)      // scrubber needle, active states
    static let secondary = Color(hex: 0xFFC07A)     // dawn/dusk/golden-hour accents
    static let tertiary = Color(hex: 0x68D3FF)      // daylight status chips

    static let background = Color(hex: 0x11131D)
    static let surfaceContainer = Color(hex: 0x1D1F2A)
    static let onSurface = Color(hex: 0xE1E1F1)
    static let onSurfaceVariant = Color(hex: 0xC0C6D6)

    enum Radius {
        static let card: CGFloat = 24   // rounded-xl
        static let control: CGFloat = 16 // rounded-lg
        static let tag: CGFloat = 8      // rounded (micro tags)
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
