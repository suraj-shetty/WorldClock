# Architecture (iOS / iPadOS / macOS)

How the app is put together and how data moves through it. For the file-by-file
list see [README.md](README.md); for the redesign roadmap see [PLAN.md](PLAN.md).
Items marked **(planned)** come from that plan and aren't in the code yet.

## Shape

One SwiftUI app, built from one source tree for iOS and macOS, plus a WidgetKit
extension. There are no third-party dependencies. The Xcode project is generated
from `project.yml` with XcodeGen, and the generated project is committed.

```
WorldClockApp            SwiftData container (on disk, falls back to in-memory)
├─ iOS: ClockListView    the board; owns the 1-second TimelineView
│  ├─ BackgroundView     the sky, drawn from one hour value
│  ├─ ClockRow ×n        a city card; expands to hold an inline TimeWheelView
│  ├─ TimeWheelView      the bottom wheel when nothing is selected
│  ├─ AddTimeZoneView    sheet (also the home-city picker in Settings)
│  └─ SettingsView       sheet
└─ macOS:
   ├─ MacBoardView       window: sky, lit-glass sidebar, board, persistent timeline bar
   │  ├─ MacCityCard ×n  the canvas card: sun/moon arc, Tomorrow/Yesterday tag
   │  └─ TimeWheelView   .ruler style, anchored to the selection or home
   ├─ BoardCommands      menus, talking to the focused window through focusedSceneValue
   ├─ Settings scene     MacSettingsView: General / Menu Bar / About tabs
   ├─ MacAddCityView     keyboard-driven Add City dialog (also the home-city picker)
   └─ MenuBarExtra       static globe icon; MenuBarView popover: home sky, cities, peek ruler
WorldClockWidget         reuses BackgroundView, Theme, ClockEntry and SharedCities
```

Adding and deleting cities goes through `ClockBoardViewModel` on both platforms, so
"deleting the selected city deselects it first" holds everywhere.

## State

There are three kinds of state, each with one owner:

| State | Owner | Lives in |
|---|---|---|
| Saved cities | SwiftData (`ClockEntry`: timezone id, label, sort order) | The app's default store. It is deliberately *not* in the App Group, because moving it would need a migration. |
| Preferences | `@AppStorage` | `use24Hour`, `showCountryName`, `animateSky`, `flagNextDayCities`, `snapMinutes`, `homeTimeZoneIdentifier`, `homeTimeZoneLabel` |
| Board session | `ClockBoardViewModel` (`@Observable`) | `selectedEntryID` and the scrub `offset`. Not persisted. |

`ClockBoardViewModel` stays pure. Every method that needs "now" takes it as a
parameter, so the tests never depend on the real clock.

### Time flow

```
TimelineView (1 s) ─▶ now
now + viewModel.offset ─▶ displayed moment
displayed moment in the anchor's zone ─▶ anchor hour (0..<24)
anchor hour ─▶ BackgroundView
```

The *anchor* is the selected city, or the home zone when nothing is selected. With
"Animate the sky" turned off, the sky ignores the scrub offset and shows the real
current time at home.

### Widget data

The widget can't read the app's SwiftData store. Instead, the app mirrors its city
list into the App Group's `UserDefaults` as JSON (`SharedCities`), whenever the list
changes. It writes only on an actual change, then reloads the widget timelines. The
widget's city picker (`CityEntity` / `CityQuery`) reads only that copy.

The widget's timeline has one entry per minute and covers 3 hours, with a reload
requested every hour. That keeps the widget ticking if iOS delays a reload. On
macOS the widget shows the local zone only, which avoids sandboxing the Mac app.

## The sky

`BackgroundView(hour:)` is a pure function of one value: the hour of day. Everything
it draws is derived from that number.

**Today:** keyframed palettes interpolated by hour (`skyPalette`), a deterministic
star field, sun and moon arcs (`sunMoonPosition`), clouds, haze, and two ridge
shapes with a mirrored lake. It's drawn in `Canvas` layers, so the expensive parts
don't redraw every second.

**Planned:** the redesign splits the sky into a model and a renderer:

```
SkyLight(hour:, date:)                  pure, tested
  sun  { t, alt, x, y }
  moon { t, alt, x, y, age, illum, waxing }   real schedule for today's phase
  light { source, colour, strength, dir, azimuth, elevation }
        │
        ├─▶ BackgroundView layers (Canvas + ShaderLibrary)
        ├─▶ LitGlass modifier, through the environment
        └─▶ ClockRow sun/moon arc, from each city's own hour
```

- **One light source for everything.** The clouds, rock relief, snow, ridge rim
  light and the glass shadows all read the same `light`. That's what makes the scene
  look consistent.
- **Rendering split.** Shapes use `Canvas`. Noise-based surfaces use Metal through
  `ShaderLibrary`, from one `.metal` file. The reflection redraws the static layers,
  flipped, through a ripple `.distortionEffect`.
- **Lite tier.** The widget passes one flag that drops the shader layers and all
  animation.
- **Redraw rule.** Layers that use shaders redraw only when the light changes by a
  15-minute step. Animated layers (stars, rays) are kept out of the reflection.
  PLAN.md's "Performance rules" explains why.

## Platform splits

The code is shared by default. Differences use `#if os(...)`, kept as small as
possible. The current splits are:

- the color types used for interpolation (`BackgroundView`)
- the sheet sizing on macOS (`AddTimeZoneView`)
- Settings layout details (`SettingsView`)
- signing entitlements, App Group on iOS only (`project.yml`)

- the Mac views (`MacBoardView.swift` and `MacPanels.swift` are wrapped in
  `#if os(macOS)` and build only for the Mac target)
- the scenes in `WorldClockApp`

The board cards, sky and models stay shared.

## Testing

All the unit tests are in `WorldClockTests/BackgroundMathTests.swift`, in four
groups:

- sky palette and sun/moon arc maths
- the wheel's offset label
- `ClockFormatting`
- view-model selection and anchor behaviour

The tests target the pure functions; views aren't unit-tested. Visual changes are
checked against the design canvas using the sky preview grid (PLAN.md phase 2).

## Performance budget

To be filled in by PLAN.md phase 4: scrub frame rate, GPU load at rest, and widget
memory, each measured on a device.
