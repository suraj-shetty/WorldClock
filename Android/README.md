# WorldClock (Android)

A timezone comparison app — Android skeleton, built with Kotlin + Jetpack Compose.
Mirrors the iOS app's core data model (a saved city is a timezone identifier plus a
label) but not yet its visual design; see [`../iOS/`](../iOS/) for the full-featured
SwiftUI app this is porting from.

## What's here

- City list with live times, ticking every second.
- Add a city: search all IANA timezone ids (`ZoneId.getAvailableZoneIds()`), tap to add.
- Delete a city.
- The list persists across restarts (SharedPreferences, as JSON — swap for Room if
  this ever needs querying).

## What's not here yet

- The "Nocturne" sky illustration (gradient/stars/sun-moon/clouds/terrain) from
  `iOS/WorldClock/Views/BackgroundView.swift` — that's ~500 lines of bespoke
  Canvas/gradient math and would be its own large port.
- The scrub wheel, home city, and Settings screen.
- 12/24-hour toggle, next-day flagging, country flags.

## Structure

- `app/src/main/java/org/surajshetty/worldclockapp/`
  - `ClockEntry.kt` — the saved-city data model.
  - `ClockRepository.kt` — SharedPreferences-backed persistence.
  - `ClockViewModel.kt` — in-memory list + persistence, exposed as a `StateFlow`.
  - `MainActivity.kt` — the Compose UI: city list, add-city dialog, delete.

## Building

Open this folder (`Android/`) directly in Android Studio and let it sync, or from
the command line:

```bash
cd Android
./gradlew :app:assembleDebug
```

Requires an Android SDK with platform 35 installed (`compileSdk`/`targetSdk` = 35,
`minSdk` = 26). `local.properties` (pointing `sdk.dir` at your SDK) is gitignored —
Android Studio creates it automatically on first open; from the command line, create
it yourself or set `$ANDROID_HOME`.
