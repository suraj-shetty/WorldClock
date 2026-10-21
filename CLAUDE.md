# WorldClock

A timezone comparison app with a sky that shows the time. There are two native
apps that share one look (Nocturne) and no code:

- `iOS/`: SwiftUI + SwiftData for iOS, iPadOS and macOS, from one source tree, plus
  a WidgetKit extension.
- `Android/`: Kotlin + Jetpack Compose.

Read these before changing the iOS app:

- [iOS/README.md](iOS/README.md): what each file does.
- [iOS/ARCHITECTURE.md](iOS/ARCHITECTURE.md): state, time flow, widget data, how
  the sky is drawn.
- [iOS/PLAN.md](iOS/PLAN.md): the current redesign, its phases and the
  performance rules.

The design reference is the [WorldClock for macOS canvas](https://claude.ai/artifact/57c3xY8wR2NbZEXxK5CNh1).
Its Sky board is the approved look.

## Commands (run from `iOS/`)

```bash
xcodegen generate
```

Run this after editing `project.yml`. The generated `.xcodeproj` is committed;
never edit build settings in Xcode without mirroring them into `project.yml`.

```bash
xcodebuild -project WorldClock.xcodeproj -scheme WorldClock_iOS -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

That runs the unit tests. Run them before every commit. The iPhone 16 Pro is also
the performance floor. If your machine has no such simulator, list the available
ones with `xcrun simctl list devices available`.

```bash
xcodebuild -project WorldClock.xcodeproj -scheme WorldClock_macOS build
```

That checks the macOS build. Run it whenever shared code changes.

Simulator builds need no signing. For a physical device, put
`DEVELOPMENT_TEAM = <id>` in `iOS/Config/Signing.local.xcconfig`. That file is
gitignored, so never commit it or a team ID.

## Rules

- **No third-party dependencies.** Use SwiftUI, SwiftData, WidgetKit, Foundation and
  Metal through `ShaderLibrary`.
- **Shared code first.** Keep `#if os(...)` blocks small and local. Don't fork whole
  views per platform. The exception is the Mac, whose canvas boards are their own
  design: `MacBoardView` (window, city card, menu bar popover) and `MacPanels`
  (Settings, Add City). They still share the sky, `LitGlass`, the masonry columns,
  `TimeWheelView` (its `.ruler` style), `ClockFormatting` and the view model.
- **Menu bar extra label stays static.** A live label (`TimelineView` + `@Query`)
  put the status item in a 100% CPU layout loop. Live content belongs in the
  popover.
- **Pure logic takes "now" as a parameter.** Never read `Date.now` inside view-model
  or sky maths; that's what keeps them testable. Date-based sky values (moon phase)
  are sampled per day, so they stay stable across renders.
- **Nocturne:**
  - The accent `#9184D9` is only ever a line or a glow, never a fill.
  - Display text weight is capped at 500, and clock digits use tabular figures.
  - Colours come from `Theme`.
  - Text on glass meets 4.5:1 contrast, including over the noon sky.
- **One light source.** Anything that's lit (clouds, terrain, glass shadows) reads
  the same sun or moon direction. Don't hand-place shadows.
- **Sky performance.** Follow PLAN.md's performance rules:
  - Shader layers redraw only on 15-minute light steps.
  - Nothing animated goes in the lake reflection.
  - Hidden layers are removed, not left at opacity 0.
- **Accessibility.** Every icon-only button has a label, every gesture has a
  button or keyboard alternative, and Reduce Motion stops twinkle, sway and
  ripple.
- **Tests.** New maths in `BackgroundMathTests.swift` comes with a test. Views are
  checked visually against the canvas, not unit-tested.
- **Comments** explain *why* (a constraint, a bug that was fixed, a platform quirk),
  in the same voice as the existing code. Don't narrate *what* the code does.
- **Android** is not changed as a side effect of iOS work. Parity changes are their
  own task.
