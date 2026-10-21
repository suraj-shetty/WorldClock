# iOS plan: the lit sky and glass redesign

This is the build plan for bringing the approved redesign to the iOS/iPadOS app. The
reference is the [WorldClock for macOS design canvas](https://claude.ai/artifact/57c3xY8wR2NbZEXxK5CNh1)
(private; ask the owner for access): its **Sky** board defines the sky, and its
**Main window** board defines the lit glass. Because the app ships from one shared
SwiftUI source tree, most of this work lands on macOS as well. The Mac-specific
window layout is the last phase.

How the code is laid out today: [README.md](README.md). How the redesign fits into
it: [ARCHITECTURE.md](ARCHITECTURE.md).

## Scope

**What stays the same on iPhone and iPad:**

- The city board: the masonry grid, tap a card to select it, the selected card
  expands in place and shows its own wheel.
- The bottom wheel when nothing is selected, the ±48 h range, and snapping to
  15/30/60 minutes.
- Add City, Settings, the home city, and the SwiftData store.
- The widget's two sizes (small and medium) and its city picker.

**What changes:**

| Area | Today | Target |
|---|---|---|
| Sun | A disc with a glow | Overexposed core, layered bloom, faint diffraction spikes. Near the horizon it reddens, flattens and shows bands. |
| Sun rays | None | Soft rays of uneven width that fan upward when the sun is low. |
| Moon | Rises at 18:00 every day, no phase | Today's real phase on its real rise/set schedule, with a curved terminator, maria, craters, earthshine and a halo. |
| Mountains | Two flat ridge shapes | Four ranges with snow, mist and a pine shoreline; farther ranges are paler; slopes and rock texture are lit from the light's direction. |
| Clouds | Blurred ellipses | Noise-based cloud fields lit from the light's direction. |
| Lake | A mirrored ridge and glints | A rippled reflection of the whole scene, darker toward the near shore. |
| Stars | One colour | Varied colour and size, and a Milky Way late at night. |
| Glass (cards, wheel bar) | Fixed tint | An edge highlight and a shadow, both driven by where the sun or moon is, plus slightly more opacity in daylight. |
| Cards | Time and offset | Adds a small sun/moon arc showing where the light is in that city, and a "Yesterday" flag next to "Next day". |

**Out of scope for this plan:** Android parity (see Decisions), new features beyond
the design, and the Mac window layout (phase 6 has its own plan).

## Phases

Each phase ends in a working, committed app. Run the tests before every commit.

### 1. Light model: pure maths, no drawing (done 2026-10-22)

- Add `Sky/SkyLight.swift`: one value for "where is the light", computed from the
  hour and the date. It holds the sun and moon positions (arc t, altitude, x/y), the
  moon's age, phase and illuminated fraction, and the dominant light (sun or moon)
  with its colour, strength, direction, and the azimuth/elevation the shading uses.
- Move the moon from its fixed 18:00 rise to the real schedule. The moon transits
  12 h + (age / synodic month) × 24 h, and the phase is sampled at noon UTC on the
  given day, so it doesn't change between renders. This replaces `SunMoonPosition`'s
  moon half.
- Update the tests in `WorldClockTests/BackgroundMathTests.swift`:
  - Replace the two moon tests that assume an 18:00 rise.
  - Add tests that a new-moon date has near-zero illumination, a full-moon date near
    1, and a waxing gibbous date (2026-10-21) is high in the sky at 18:30.
  - Add a test that the dominant light switches from sun to moon after sunset.

**Done when:** the tests pass and `BackgroundView` draws the sky as before, apart
from the moon now following its real schedule.

### 2. Sky rendering, layer by layer (done 2026-10-22)

Rebuild `BackgroundView` as stacked layers fed by `SkyLight`, in this order (the
same order as the canvas):

1. Sky gradient (existing keyframes) and Milky Way
2. Stars (twinkle)
3. Sun rays
4. Bloom, moon, sun
5. Clouds
6. Haze
7. Mountain ranges with snow and mist
8. Shoreline trees
9. Lake reflection
10. Glints

- Shapes (sun, moon, ridges, trees, rays) use `Canvas`, as today.
- Anything noise-based (clouds, rock relief, moon surface, snow patches) uses Metal
  shaders through SwiftUI's `ShaderLibrary` (`.colorEffect` / `.layerEffect`).
  These are available from iOS 17 and macOS 14, the current minimums. One `.metal`
  file holds the shared noise and a few small effects.
- The reflection reuses the scene's own drawing commands, flipped, with a ripple
  `.distortionEffect`. It includes the static layers only: no stars or rays (see
  Performance rules).
- Check each layer visually before moving on. Add a `#Preview` grid that renders
  the sky at 6:30, 12:00, 16:30, 18:30 and 22:00 side by side, and compare it with
  the canvas's Sky board at the same hours.

**Done when:** the preview grid matches the canvas at those five hours, and the
performance rules below hold.

**Result:** checked by rendering the app's sky offscreen and the canvas in headless
Chrome at the five hours, both 880×540, and diffing the pixels: about 1 level of 255
mean difference per region, with only sub-point outlines left (the sun's rim, the
moon's limb). Skipped as invisible at that level: the canvas's 0.3–0.6 pt blurs on
craters and cloud coverage. The performance rules hold by construction (one render
per 15-minute step); the frame-time numbers are phase 4, on a device.

### 3. Lit glass and cards

- Add a `LitGlass` view modifier that reads `SkyLight` from the environment. It
  draws the edge highlight on the side facing the light, a contact shadow, a long
  shadow pointing away from the light (longer and softer when the light is low),
  and adds glass opacity in bright daylight. Apply it to `ClockRow`, the bottom
  wheel and `CircleIconButton`.
- Add the small sun/moon arc to `ClockRow`. It's driven by each city's own local
  hour through the same `SkyLight` maths.
- Add the "Yesterday" flag next to "Next day". It already exists in the canvas
  design, and it is just the opposite comparison in `isNextDay`.
- Keep text at 4.5:1 contrast over the brightest noon sky. Check this against the
  noon preview.

**Done when:** the cards and wheel match the canvas Main window at dusk and at noon,
and VoiceOver reads the arc as "Sun up", "Sunset", "Moon up" or "Night".

### 4. Performance and scrub smoothness

Profile on a physical iPhone 16 Pro (the floor) with Instruments' SwiftUI and
Core Animation tools:

- Scrubbing the wheel holds 60 fps, with no dropped frames when crossing a snap.
- At rest, with only the stars twinkling, the GPU sits under 15%.
- The widget extension stays under its memory limit (about 30 MB).

**Done when:** all three numbers are met and written into ARCHITECTURE.md.

### 5. Widget

- The widget gets the full sky through `BackgroundView`, shaders included, but
  without animation: WidgetKit renders a static snapshot per timeline entry, so
  twinkle and sway would be wasted there. That's one `animated: false` flag on
  `BackgroundView`, not a second view.
- Verify on device that the shader layers render in widget snapshots. If one
  doesn't, fall back for that layer only and note it here.

**Done when:** small and medium widgets match the app's sky at the same hour, on
device, within the widget memory limit.

### 6. Mac window

Brought forward on 2026-10-21; it doesn't depend on the sky work. It picks up
phases 1–5 automatically, because the sky and glass are shared.

**Done:**

- Built to the canvas Main window, Settings, Add City and MenuBar boards (compared
  side by side on 2026-10-21). `MacBoardView`: the sky fills the window behind a
  lit-glass sidebar (filter, home, cities, Add City); three columns of `MacCityCard`
  with the sun/moon arc and Tomorrow/Yesterday tags; a timeline bar with the canvas
  ruler, always shown, anchored to the selected city or home. `LitGlass` (phase 3's
  modifier) is in and lights the Mac panes; the iPhone cards adopt it in phase 3.
- Two-finger trackpad swipe and plain ← → on the timeline, and a draggable
  peek-ahead ruler in the menu bar popover.
- Menu commands:
  - File › Add City ⌘N
  - Edit › Find City ⌘F
  - View › Toggle Sidebar ⌃⌘S
  - View › 24-Hour Time ⇧⌘T
  - Time › Now ⌘0, Earlier ⌥←, Later ⌥→
  - Space deselects, ⌫ deletes the selected city (on the window, not in a menu)
- A Settings scene (⌘,) with "Show in menu bar" and "Open at login" (`SMAppService`).
- A menu bar extra: a static globe icon, and a popover with the home sky, every
  city with its offset and Tomorrow/Yesterday, and Open, Settings and Quit.

**Still to do:**

- The tall desktop widget that lists the whole board.
- A live city time in the menu bar label ("TYO 10:00" on the canvas). It needs a
  label that doesn't loop; see CLAUDE.md.
- Phases 1–2 landed on 2026-10-22, so the Mac window now draws the canvas sky.

## Performance rules (learned on the canvas)

These come from fixing scrub flicker on the design canvas, where the same scene
dropped frames three different ways:

1. **Don't redraw the expensive layers every frame.** The lighting used by the
   shaders (clouds, rock relief) changes in 15-minute steps, the same as the wheel's
   snap. While the wheel glides between snaps, those layers stay identical and are
   not redrawn.
2. **Nothing that animates belongs in the reflection.** Twinkling stars and swaying
   rays inside the reflected group forced the whole mirrored scene to redraw on
   every frame. They live outside it.
3. **Values that feed the drawing must be stable across renders.** The moon phase
   used the exact current time and changed on every render. Sample anything
   date-based per day.
4. **Hidden layers must not draw.** Anything faded out is removed from the
   hierarchy, not left at opacity 0.

## Decisions

| Decision | Choice | Why |
|---|---|---|
| Glass implementation | Custom `LitGlass`, not iOS 26 `.glassEffect()` | The minimum is iOS 17, and the design needs the edge highlight and shadow to follow the sun, which system glass doesn't do. Revisit when the minimum reaches iOS 26. |
| Noise rendering | Metal via `ShaderLibrary` | `Canvas` has no noise primitive. Shaders are built into SwiftUI from iOS 17, so there's no dependency. |
| Dependencies | None | Same as today. |
| Android | Not changed by this plan | Android's `SkyMath` still uses the fixed moon schedule. Port `SkyLight` later as its own task, so the two apps agree again. |
| Moon phase source | Computed from a known new moon (2000-01-06 18:14 UTC) and the mean synodic month | Accurate to well under a day, needs no network, and is testable. |

| Performance floor | iPhone 16 Pro | Decided 2026-10-21. |
| Widget sky | The full sky, without animation | Decided 2026-10-21; shader rendering in snapshots is checked on device in phase 5. |
