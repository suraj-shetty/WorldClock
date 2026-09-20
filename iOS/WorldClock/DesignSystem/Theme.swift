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

/// Shared clock-display formatting — time labels, home-offset labels, and the
/// "one representative city" name derived from an IANA identifier. Pulled out
/// since the same math was independently reimplemented in ClockListView,
/// AddTimeZoneView, TimeWheelView, and SettingsView.
enum ClockFormatting {
    /// Unicode minus (U+2212), used instead of ASCII '-' for negative offsets throughout.
    static let minusSign = "\u{2212}"

    /// "3:45" + "PM" (or "15:45" + "" in 24h mode). Split so the AM/PM suffix can
    /// render smaller than the digits.
    static func timeComponents(hour: Int, minute: Int, use24Hour: Bool) -> (main: String, period: String) {
        if use24Hour { return (String(format: "%02d:%02d", hour, minute), "") }
        let displayHour = hour % 12 == 0 ? 12 : hour % 12
        return (String(format: "%d:%02d", displayHour, minute), hour < 12 ? "AM" : "PM")
    }

    /// "Home", "+3h", or "−1.5h" — how far a zone sits from home at a given moment,
    /// from each side's seconds-from-GMT offset.
    static func offsetLabel(homeOffsetSeconds: Int, zoneOffsetSeconds: Int) -> String {
        let diffMinutes = (zoneOffsetSeconds - homeOffsetSeconds) / 60
        if diffMinutes == 0 { return "Home" }
        let sign = diffMinutes > 0 ? "+" : minusSign
        let magnitude = abs(diffMinutes)
        let hours = magnitude / 60, minutes = magnitude % 60
        // Rounded, not truncated: minutes=45 is 0.75h, which rounds to ".8h".
        let tenths = Int((Double(minutes) / 6).rounded())
        return minutes == 0 ? "\(sign)\(hours)h" : "\(sign)\(hours).\(tenths)h"
    }

    /// An IANA identifier's representative city name, e.g. "Asia/Kolkata" -> "Kolkata".
    static func displayLabel(for identifier: String) -> String {
        identifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? identifier
    }
}
