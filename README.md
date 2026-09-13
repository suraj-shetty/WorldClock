# WorldClock

A timezone comparison app: add cities, then drag a time wheel — either the global
one or a selected city's own inline wheel — to see every city's time shift together,
over a parametric sky illustration (gradient, stars, sun/moon arc, clouds, mountains,
and a reflecting lake) that follows whichever city, or the device, is the active
anchor.

Visual design follows the "Nocturne" system: dark glass cards, a single accent color
(`#9184D9`) used only as a line or a glow, and a wheel scaled to 1.5pt per minute with
half-hour labels, a glowing center caret, and snap-to-15-minutes on release.

Built with SwiftUI + SwiftData, targeting iOS/iPadOS and macOS from one shared source
tree. Generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen) — see
`project.yml` for build settings; regenerate after editing it:

```bash
xcodegen generate
```

## Structure

- `WorldClockApp.swift` — app entry, SwiftData model container.
- `DesignSystem/Theme.swift` — Nocturne colors, spacing, and radii.
- `Models/ClockEntry.swift` — a saved city (timezone identifier, label, sort order).
- `ViewModels/ClockBoardViewModel.swift` — selection state, wheel offset, and the
  anchor-swap logic that moves the sky/wheel between the device and a selected city.
- `Views/ClockListView.swift` — the board: header, city rows (collapsed/expanded),
  and the global bottom wheel.
- `Views/TimeWheelView.swift` — the draggable time ruler, mounted either as the
  bottom bar or inline inside a selected row.
- `Views/BackgroundView.swift` — the sky: a `Canvas`-drawn illustration keyed to
  hour-of-day (gradient keyframes, a deterministic star field, sun/moon discs with
  CSS-accurate glow, clouds, haze, and a mountain/lake terrain layer with a mirrored
  reflection).
- `Views/AddTimeZoneView.swift` / `SettingsView.swift` — add-city search sheet and
  the 12/24-hour toggle.
- `WorldClockTests/` — sky palette math and view-model offset/anchor tests.

## Testing

```bash
xcodebuild -project WorldClock.xcodeproj -scheme WorldClock_iOS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```
