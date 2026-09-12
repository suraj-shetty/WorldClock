# WorldClock

A timezone comparison app: add cities, then drag a time wheel — either the global
one or a selected city's own inline wheel — to see every city's time shift together,
with an animated sky background that follows whichever city (or the device) is the
active anchor.

Built with SwiftUI + SwiftData, targeting iOS/iPadOS and macOS from one shared source
tree. Generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen) — see
`project.yml` for build settings; regenerate after editing it:

```bash
xcodegen generate
```
