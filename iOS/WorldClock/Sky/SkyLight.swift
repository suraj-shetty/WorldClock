import SwiftUI

// The sky's model, ported formula for formula from the canvas's Sky board (`Sky.dc.html`):
// the palette keyframes, the sun's arc, and the moon's real phase and schedule. Pure and
// tested; BackgroundView draws from it, and the Mac glass and card arcs read the same light.

/// An 8-bit sRGB colour, mixed the way the canvas mixes: rounded to whole values at every
/// step, so nested mixes land on exactly the canvas's colours.
struct RGB: Equatable {
    var r, g, b: Double

    init(_ hex: UInt32) {
        r = Double((hex >> 16) & 0xFF)
        g = Double((hex >> 8) & 0xFF)
        b = Double(hex & 0xFF)
    }

    init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }

    func mix(_ other: RGB, _ t: Double) -> RGB {
        let t = clamp01(t)
        return RGB(r: (r + (other.r - r) * t).rounded(), g: (g + (other.g - g) * t).rounded(), b: (b + (other.b - b) * t).rounded())
    }

    var color: Color { Color(red: r / 255, green: g / 255, blue: b / 255) }
    func color(_ opacity: Double) -> Color { color.opacity(opacity) }
}

func clamp01(_ v: Double) -> Double { min(max(v, 0), 1) }

func normalizedHour(_ hour: Double) -> Double {
    let raw = hour.truncatingRemainder(dividingBy: 24)
    return raw < 0 ? raw + 24 : raw
}

/// The canvas's seeded generator (Park–Miller), so stars, peaks, rays and trees land
/// where the design put them.
func seededRandom(_ seed: Int) -> () -> Double {
    var s = seed
    return {
        s = (s * 16807) % 2147483647
        return Double(s) / 2147483647
    }
}

struct SkyPalette: Equatable {
    let top, up, mid, hz, cloud, haze: RGB
    let star, cloudAlpha: Double

    private static let keys: [(Double, UInt32, UInt32, UInt32, UInt32, Double, UInt32, Double, UInt32)] = [
        (0, 0x0b0d1c, 0x101228, 0x141830, 0x1d2140, 1, 0x3a3f63, 0.42, 0x141731),
        (4.5, 0x101227, 0x181b38, 0x22254a, 0x3c3358, 0.5, 0x413f68, 0.5, 0x241f3d),
        (6.5, 0x2b2c52, 0x4a4470, 0x6e5f85, 0xc49a8d, 0.04, 0xb48d94, 0.58, 0x8d6f78),
        (9, 0x3a4570, 0x606b95, 0x7f8aae, 0xbcc2d2, 0, 0xd2d8e6, 0.52, 0x9aa3bb),
        (12, 0x47528a, 0x6b77a6, 0x8b98bd, 0xc6cddb, 0, 0xe2e7f0, 0.58, 0xa5aec6),
        (15, 0x414877, 0x6a6c99, 0x8a86ab, 0xcbb3ae, 0, 0xd6c9d0, 0.54, 0xa08e9e),
        (18, 0x1e2144, 0x413d67, 0x6d5b88, 0xc08e7f, 0.16, 0x8e7489, 0.6, 0x7d5c69),
        (20.5, 0x131628, 0x1f2140, 0x33305a, 0x5c4a6e, 0.58, 0x4c4666, 0.5, 0x33294a),
        (24, 0x0b0d1c, 0x101228, 0x141830, 0x1d2140, 1, 0x3a3f63, 0.42, 0x141731),
    ]

    init(hour: Double) {
        let h = normalizedHour(hour)
        var i = 0
        while i < Self.keys.count - 2 && h >= Self.keys[i + 1].0 { i += 1 }
        let a = Self.keys[i], b = Self.keys[i + 1]
        var f = (h - a.0) / (b.0 - a.0)
        f = f * f * (3 - 2 * f)
        top = RGB(a.1).mix(RGB(b.1), f)
        up = RGB(a.2).mix(RGB(b.2), f)
        mid = RGB(a.3).mix(RGB(b.3), f)
        hz = RGB(a.4).mix(RGB(b.4), f)
        star = a.5 + (b.5 - a.5) * f
        cloud = RGB(a.6).mix(RGB(b.6), f)
        cloudAlpha = a.7 + (b.7 - a.7) * f
        haze = RGB(a.8).mix(RGB(b.8), f)
    }
}

/// A point on the sun/moon arc, in fractions of the sky's width and height.
struct SkyArcPoint: Equatable {
    let x, y, alt: Double
    init(t: Double) {
        x = 0.08 + 0.84 * t
        y = 0.71 - sin(.pi * t) * 0.6
        alt = sin(.pi * t)
    }
}

struct MoonPhase: Equatable {
    static let synodicMonth = 29.530588853
    /// A known new moon: 2000-01-06 18:14 UTC.
    static let epoch: TimeInterval = 947_182_440

    /// Days since new moon, 0 ..< 29.53.
    let age: Double
    let illumination: Double
    let waxing: Bool
    /// The hour the moon's arc starts: it transits about 0.8 h later each day of its age.
    let rise: Double

    /// Sampled at noon UTC on `day`'s date, so it holds still across renders and scrubs.
    init(day: Date) {
        let noon = (day.timeIntervalSince1970 / 86400).rounded(.down) * 86400 + 43200
        let syn = Self.synodicMonth
        age = (((noon - Self.epoch) / 86400).truncatingRemainder(dividingBy: syn) + syn).truncatingRemainder(dividingBy: syn)
        illumination = (1 - cos(2 * .pi * age / syn)) / 2
        waxing = age < syn / 2
        rise = 12 + age / syn * 24 - 6
    }

    var phaseAngle: Double { 2 * .pi * age / Self.synodicMonth }
}

/// Where the light is at `hour`, and how strong: the sun by day (and through twilight),
/// the moon once the sun's glow is gone.
struct SkyLight: Equatable {
    let hour: Double
    let palette: SkyPalette
    let moonPhase: MoonPhase
    let sun, moon: SkyArcPoint
    /// The sun's glow, which lingers about 40 minutes past the horizon.
    let glow: Double
    let sunUp: Double
    /// The moon's visibility: rises and sets softly, and is washed out (not hidden) by day.
    let moonVisibility: Double
    let usesSun: Bool
    /// 0 … 1: what the lit surfaces (rims, snow, glass) take from the light.
    let strength: Double

    init(hour: Double, day: Date) {
        let h = normalizedHour(hour)
        self.hour = h
        palette = SkyPalette(hour: h)
        moonPhase = MoonPhase(day: day)
        sun = SkyArcPoint(t: (h - 6) / 12)
        moon = SkyArcPoint(t: normalizedHour(h - moonPhase.rise) / 12)
        glow = clamp01((sun.alt + 0.12) / 0.35)
        sunUp = clamp01(sun.alt)
        moonVisibility = clamp01((moon.alt + 0.04) / 0.12) * (1 - 0.68 * glow * min(1, sunUp * 2.5))
        usesSun = glow > 0.06
        strength = usesSun ? glow : 0.5 * moonVisibility
    }

    var light: SkyArcPoint { usesSun ? sun : moon }
    var lightAltitude: Double { clamp01(light.alt) }
    var glowColor: RGB { RGB(0xe7743f).mix(RGB(0xf8ecd2), sunUp) }
    var lightColor: RGB { usesSun ? glowColor : RGB(0xd6d1f7) }
}

/// The glass's view of the light (canvas Main window): direction from the window's
/// centre, strength and colour. Uses the canvas window's proportions so the angles match.
struct GlassLight: Equatable {
    let dx, dy: Double
    let strength: Double
    let altitude: Double
    let sunUp: Double
    let isSun: Bool

    /// Warm white high sun, amber low sun, cool moon.
    var hex: UInt32 { isSun ? (sunUp > 0.5 ? 0xf6e6c4 : 0xf0b48a) : 0xcfc9f7 }

    init(_ sky: SkyLight) {
        let l = sky.light
        let vx = (l.x - 0.5) * 1384, vy = (l.y - 0.5) * 844
        let n = max(hypot(vx, vy), 1)
        dx = vx / n
        dy = vy / n
        strength = sky.strength
        altitude = sky.lightAltitude
        sunUp = sky.sunUp
        isSun = sky.usesSun
    }

    init(hour: Double, day: Date) { self.init(SkyLight(hour: hour, day: day)) }
}

/// The small sun/moon arc on a Mac city card: where the light sits over that city,
/// as a dot on a 34×18 arc, plus the words the card and VoiceOver show for it.
struct CardSky: Equatable {
    let isDay: Bool
    let x, y: Double
    let label: String

    init(hour h: Double, moonRise: Double) {
        let hour = normalizedHour(h), t = (hour - 6) / 12
        if t >= 0 && t <= 1 {
            let a = Double.pi * (1 - t)
            isDay = true
            x = 17 + 14 * cos(a)
            y = 16 - 14 * sin(a)
            label = t < 0.12 ? "Sunrise" : t > 0.88 ? "Sunset" : "Sun up"
        } else {
            let tm = normalizedHour(hour - moonRise) / 12, b = Double.pi * (1 - min(tm, 1))
            isDay = false
            x = 17 + 14 * cos(b)
            y = tm <= 1 ? 16 - 14 * sin(b) : 16
            label = tm <= 1 ? "Moon up" : "Night"
        }
    }
}
