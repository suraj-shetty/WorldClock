# WorldClock (Android)

A timezone comparison app, built natively with Kotlin + Jetpack Compose — full
feature parity with the iOS app, including the hand-drawn "Nocturne" sky
illustration. See [`../iOS/`](../iOS/) for the SwiftUI original this was ported
from; the two share the same visual design and interaction model, not just the
same data.

## What's here

- The "Nocturne" sky illustration — gradient keyframes, a deterministic star
  field, sun/moon discs with CSS-accurate glow (erfc falloff), clouds, haze, and
  a mountain/lake terrain layer with a mirrored reflection. Ported from the iOS
  app's `BackgroundView.swift`; animates smoothly between hours via
  `animateFloatAsState` (the Compose equivalent of the iOS `Animatable` fix).
- The draggable scrub wheel — drag to shift time, flick to glide-and-snap,
  mounted as either the global bottom bar or inline inside a selected row.
- City list with live times, add/delete, search across all IANA timezone ids
  plus city aliases (Bengaluru, Beijing, etc. for countries with one timezone
  covering several major cities).
- Home city picker, Settings screen (12/24-hour, show country name, animate
  sky, flag next-day cities, scrub-snap increment).
- Country flags and names (ported lookup table + flag-emoji generation).
- Tablet/wide-screen layout: `LazyVerticalStaggeredGrid` gives masonry columns
  for free — expanding a card only pushes down the cards below it in its own
  column, the rest of the board doesn't move. (The iOS app hand-rolls this same
  behavior since SwiftUI has no built-in masonry layout.)
- Persistence across restarts (SharedPreferences, as JSON — swap for Room if
  this ever needs querying).

## What's not here

- Long-press-to-delete on a collapsed row (iOS has this as a secondary
  affordance alongside the visible "Delete City" button on the expanded row,
  which this port does have).

## Structure

- `app/src/main/java/org/surajshetty/worldclockapp/`
  - `Theme.kt` — Nocturne colors/spacing, ported from the iOS `Theme.swift`.
  - `ClockEntry.kt` / `AppSettings.kt` — the saved-city and settings models.
  - `CountryLookup.kt` / `TimeZoneCatalog.kt` — country code/flag lookup and
    the searchable timezone catalog (with city aliases).
  - `ClockRepository.kt` — SharedPreferences-backed persistence.
  - `ClockViewModel.kt` — entries, settings, selection, and the shared scrub
    offset — the Compose analogue of the iOS `ClockBoardViewModel`.
  - `ClockFormat.kt` — shared time/offset-label formatting used by both the
    board rows and the add-city picker.
  - `SkyMath.kt` / `SkyBackground.kt` — the sky illustration's math and
    Canvas drawing.
  - `TimeWheel.kt` — the draggable scrub wheel.
  - `ClockRow.kt` — a single city card, collapsed or expanded.
  - `BoardScreen.kt` — the main board: header, masonry grid, bottom wheel.
  - `AddCityScreen.kt` — add-a-city (multi-select) / choose-home-city
    (single-select) — one screen doubles for both, like the iOS
    `AddTimeZoneView`.
  - `SettingsScreen.kt` — the settings screen.
  - `MainActivity.kt` — wires it together with simple state-driven navigation.
- `app/src/test/java/org/surajshetty/worldclockapp/` — JUnit tests for the sky
  math, the wheel's offset label, country lookup, and the entries JSON
  round-trip.

## Building

Open this folder (`Android/`) directly in Android Studio and let it sync, or from
the command line:

```bash
cd Android
./gradlew :app:assembleDebug :app:testDebugUnitTest
```

Requires an Android SDK with platform 35 installed (`compileSdk`/`targetSdk` = 35,
`minSdk` = 26). `local.properties` (pointing `sdk.dir` at your SDK) is gitignored —
Android Studio creates it automatically on first open; from the command line, create
it yourself or set `$ANDROID_HOME`.

Verified (not just built) on a phone-sized and a tablet-sized (2560x1600)
emulator: add/delete city, select/deselect with sky animation, wheel drag,
Settings, home city picker, and the masonry column-push-down behavior.
