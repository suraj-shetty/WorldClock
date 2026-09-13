import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - "Nocturne" sky illustration
// Ported from the Claude Design handoff (`Sky.dc.html`): a parametric sky driven by
// hour-of-day (0..24, fractional) — gradient, star field, sun/moon arc, clouds, haze,
// and a mountain/lake terrain layer. Values (colors, curves, geometry) are transcribed
// directly from the design's keyframe table and formulas so this renders pixel-close
// to the reference, not just "similar."

private struct SkyKeyframe {
    let hour: Double
    let top, up, mid, hz: Color
    let star: Double
    let cloudTint: Color
    let cloudAlpha: Double
    let haze: Color
}

private let skyKeyframes: [SkyKeyframe] = [
    .init(hour: 0,    top: Color(hex: 0x0b0d1c), up: Color(hex: 0x101228), mid: Color(hex: 0x141830), hz: Color(hex: 0x1d2140), star: 1,    cloudTint: Color(hex: 0x3a3f63), cloudAlpha: 0.42, haze: Color(hex: 0x141731)),
    .init(hour: 4.5,  top: Color(hex: 0x101227), up: Color(hex: 0x181b38), mid: Color(hex: 0x22254a), hz: Color(hex: 0x3c3358), star: 0.5,  cloudTint: Color(hex: 0x413f68), cloudAlpha: 0.5,  haze: Color(hex: 0x241f3d)),
    .init(hour: 6.5,  top: Color(hex: 0x2b2c52), up: Color(hex: 0x4a4470), mid: Color(hex: 0x6e5f85), hz: Color(hex: 0xc49a8d), star: 0.04, cloudTint: Color(hex: 0xb48d94), cloudAlpha: 0.58, haze: Color(hex: 0x8d6f78)),
    .init(hour: 9,    top: Color(hex: 0x3a4570), up: Color(hex: 0x606b95), mid: Color(hex: 0x7f8aae), hz: Color(hex: 0xbcc2d2), star: 0,    cloudTint: Color(hex: 0xd2d8e6), cloudAlpha: 0.52, haze: Color(hex: 0x9aa3bb)),
    .init(hour: 12,   top: Color(hex: 0x47528a), up: Color(hex: 0x6b77a6), mid: Color(hex: 0x8b98bd), hz: Color(hex: 0xc6cddb), star: 0,    cloudTint: Color(hex: 0xe2e7f0), cloudAlpha: 0.58, haze: Color(hex: 0xa5aec6)),
    .init(hour: 15,   top: Color(hex: 0x414877), up: Color(hex: 0x6a6c99), mid: Color(hex: 0x8a86ab), hz: Color(hex: 0xcbb3ae), star: 0,    cloudTint: Color(hex: 0xd6c9d0), cloudAlpha: 0.54, haze: Color(hex: 0xa08e9e)),
    .init(hour: 18,   top: Color(hex: 0x1e2144), up: Color(hex: 0x413d67), mid: Color(hex: 0x6d5b88), hz: Color(hex: 0xc08e7f), star: 0.16, cloudTint: Color(hex: 0x8e7489), cloudAlpha: 0.6,  haze: Color(hex: 0x7d5c69)),
    .init(hour: 20.5, top: Color(hex: 0x131628), up: Color(hex: 0x1f2140), mid: Color(hex: 0x33305a), hz: Color(hex: 0x5c4a6e), star: 0.58, cloudTint: Color(hex: 0x4c4666), cloudAlpha: 0.5,  haze: Color(hex: 0x33294a)),
    .init(hour: 24,   top: Color(hex: 0x0b0d1c), up: Color(hex: 0x101228), mid: Color(hex: 0x141830), hz: Color(hex: 0x1d2140), star: 1,    cloudTint: Color(hex: 0x3a3f63), cloudAlpha: 0.42, haze: Color(hex: 0x141731)),
]

private let skyInk = Color(hex: 0x090b18)
private let skyAccent = Color(hex: 0x9184d9) // Nocturne accent — used only for the moon's glow here

extension Color {
    /// RGB components for interpolation. `#if os()` picks the right platform color type
    /// since this app builds for both iOS and macOS from one source tree.
    var components: (r: Double, g: Double, b: Double) {
        #if os(macOS)
        let native = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor(self)
        #else
        let native = UIColor(self)
        #endif
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        native.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }
}

private func lerp(_ a: Color, _ b: Color, _ t: Double) -> Color {
    let ac = a.components, bc = b.components
    return Color(red: ac.r + (bc.r - ac.r) * t,
                 green: ac.g + (bc.g - ac.g) * t,
                 blue: ac.b + (bc.b - ac.b) * t)
}

private func clamp01(_ v: Double) -> Double { min(max(v, 0), 1) }
private func ramp(_ v: Double, _ a: Double, _ b: Double) -> Double { clamp01((v - a) / (b - a)) }

/// Internal (not private) so `BackgroundMathTests` can exercise the palette math directly.
struct SkyPalette {
    let top, up, mid, hz: Color
    let star: Double
    let cloudTint: Color
    let cloudAlpha: Double
    let haze: Color
}

func skyPalette(forHour hour: Double) -> SkyPalette {
    let h = hour.truncatingRemainder(dividingBy: 24)
    let hh = h < 0 ? h + 24 : h
    var i = 0
    while i < skyKeyframes.count - 2 && hh >= skyKeyframes[i + 1].hour { i += 1 }
    let a = skyKeyframes[i], b = skyKeyframes[i + 1]
    let t = a.hour == b.hour ? 0 : clamp01((hh - a.hour) / (b.hour - a.hour))
    return SkyPalette(
        top: lerp(a.top, b.top, t), up: lerp(a.up, b.up, t), mid: lerp(a.mid, b.mid, t), hz: lerp(a.hz, b.hz, t),
        star: a.star + (b.star - a.star) * t,
        cloudTint: lerp(a.cloudTint, b.cloudTint, t), cloudAlpha: a.cloudAlpha + (b.cloudAlpha - a.cloudAlpha) * t,
        haze: lerp(a.haze, b.haze, t)
    )
}

// MARK: - Star field
// Same deterministic PRNG (seed + LCG) as the design so the star layout matches exactly.

private struct SkyStar { let x, y, d, baseBrightness, dur, delay: Double }

private let skyStars: [SkyStar] = {
    var seed: UInt64 = 20260910
    func rnd() -> Double {
        seed = (seed &* 1664525 &+ 1013904223) % 4294967296
        return Double(seed) / 4294967296
    }
    var out: [SkyStar] = []
    for _ in 0..<90 {
        let y = pow(rnd(), 1.7) * 58
        out.append(SkyStar(x: rnd() * 100, y: y, d: 0.9 + rnd() * 1.7, baseBrightness: 0.35 + rnd() * 0.65, dur: 2.6 + rnd() * 4.4, delay: rnd() * 5))
    }
    return out
}()

// MARK: - Clouds (fixed layout, per-frame color/opacity)

private struct SkyCloudBase { let x, y, w, h, blur, o: Double }
private let skyCloudBases: [SkyCloudBase] = [
    .init(x: 22, y: 16, w: 54, h: 9, blur: 13, o: 0.9),
    .init(x: 74, y: 27, w: 44, h: 7, blur: 11, o: 0.7),
    .init(x: 40, y: 44, w: 68, h: 8, blur: 15, o: 0.55),
    .init(x: 86, y: 57, w: 38, h: 6, blur: 10, o: 0.45),
    .init(x: 12, y: 66, w: 50, h: 6, blur: 12, o: 0.38),
]

// MARK: - Terrain (mountain ridges + lake), fixed geometry per the design's clip-paths

private struct RidgeShape {
    let bottomPercent, heightPercent, blur, ink: Double
    let points: [(x: Double, y: Double)]
}

private let ridgeShapes: [RidgeShape] = [
    .init(bottomPercent: 18, heightPercent: 27, blur: 2.4, ink: 0.42, points: [
        (0, 100), (0, 66), (8, 44), (16, 58), (26, 28), (34, 47), (43, 20), (52, 43),
        (61, 25), (70, 50), (79, 32), (88, 54), (96, 38), (100, 52), (100, 100),
    ]),
    .init(bottomPercent: 17, heightPercent: 21, blur: 1.2, ink: 0.66, points: [
        (0, 100), (0, 78), (9, 54), (16, 70), (25, 40), (34, 63), (42, 32), (51, 58),
        (59, 36), (69, 64), (77, 46), (86, 66), (94, 50), (100, 68), (100, 100),
    ]),
    .init(bottomPercent: 16, heightPercent: 16, blur: 0, ink: 0.84, points: [
        (0, 100), (0, 62), (11, 32), (21, 56), (30, 26), (38, 52), (45, 78), (50, 92),
        (55, 78), (62, 50), (71, 24), (81, 54), (91, 38), (100, 64), (100, 100),
    ]),
]

private let waterHeightPercent: Double = 15
private let shorelinePoints: [(x: Double, y: Double)] = [
    (0, 5), (13, 2), (27, 6), (40, 2.5), (53, 6.5), (67, 3), (80, 7), (92, 3.5), (100, 6), (100, 100), (0, 100),
]

private func ridgePath(_ points: [(x: Double, y: Double)], in rect: CGRect) -> Path {
    var path = Path()
    guard let first = points.first else { return path }
    path.move(to: CGPoint(x: rect.minX + first.x / 100 * rect.width, y: rect.minY + first.y / 100 * rect.height))
    for p in points.dropFirst() {
        path.addLine(to: CGPoint(x: rect.minX + p.x / 100 * rect.width, y: rect.minY + p.y / 100 * rect.height))
    }
    path.closeSubpath()
    return path
}

// MARK: - Animated background

/// Full-bleed sky background keyed to `hour` (0..<24, fractional, in whichever
/// timezone is the active anchor). Feed it `ClockBoardViewModel.activeAnchorHour(...)`.
///
/// Split into three layers instead of one Canvas because only the star field's
/// twinkle needs continuous ticking. Everything else — the gradient, sun/moon glow,
/// clouds, and terrain with several expensive blur passes — is a pure function of
/// `hour`, which changes at most once a second (or continuously while the wheel is
/// actively being dragged, when redrawing is exactly what's wanted). Driving all of
/// that off the same fast timer as the stars meant redrawing the whole expensive
/// scene many times a second for no visual benefit.
struct BackgroundView: View {
    var hour: Double

    var body: some View {
        ZStack {
            SkyGradientLayer(hour: hour)
            SkyStarLayer(hour: hour)
            SkyForegroundLayer(hour: hour)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.3), value: hour)
    }
}

/// Layer 1: the base 4-stop gradient. Cheap even redrawn often, but only actually
/// redraws when `hour` changes — no timer.
private struct SkyGradientLayer: View, Animatable {
    var hour: Double

    // A plain Canvas has no state for SwiftUI to interpolate — without this, changing
    // `hour` (tapping a city, deselecting) snaps straight to the new sky instead of
    // easing through it. Animatable's `animatableData` makes SwiftUI drive `hour`
    // through the intermediate values itself, redrawing the Canvas each frame.
    var animatableData: Double {
        get { hour }
        set { hour = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let p = skyPalette(forHour: normalizedHour(hour))
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: p.top, location: 0),
                        .init(color: p.up, location: 0.30),
                        .init(color: p.mid, location: 0.62),
                        .init(color: p.hz, location: 1.0),
                    ]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)
                )
            )
        }
    }
}

/// Layer 2: just the twinkling stars — the only part of the sky that needs
/// continuous motion. Small, blur-free draws, so ticking this fast is cheap.
private struct SkyStarLayer: View {
    var hour: Double

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { timeline in
            Canvas { context, size in
                let p = skyPalette(forHour: normalizedHour(hour))
                guard p.star > 0.01 else { return }
                let scale = min(size.width, size.height) / 390
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                for star in skyStars {
                    let twinkle = (sin(elapsed * (2 * .pi / star.dur) + star.delay) + 1) / 2
                    context.opacity = star.baseBrightness * p.star * (0.35 + 0.65 * twinkle)
                    let point = CGPoint(x: star.x / 100 * size.width, y: star.y / 100 * size.height)
                    let d = star.d * scale
                    context.fill(Path(ellipseIn: CGRect(x: point.x - d / 2, y: point.y - d / 2, width: d, height: d)), with: .color(Color(hex: 0xf3f5fe)))
                }
                context.opacity = 1
            }
        }
    }
}

/// Layer 3: sun/moon glow, clouds, haze, and terrain — everything with the
/// expensive blur passes. No timer: redraws only when `hour` changes.
private struct SkyForegroundLayer: View, Animatable {
    var hour: Double

    // See SkyGradientLayer.animatableData — same reasoning, and this is the layer
    // where the sun/moon position and terrain lighting actually live, so it's the
    // one that most needs to ease rather than snap.
    var animatableData: Double {
        get { hour }
        set { hour = newValue }
    }

    var body: some View {
        Canvas { context, size in
            drawForeground(context: &context, size: size, hour: normalizedHour(hour))
        }
    }
}

private func normalizedHour(_ hour: Double) -> Double {
    let raw = hour.truncatingRemainder(dividingBy: 24)
    return raw < 0 ? raw + 24 : raw
}

private func drawForeground(context: inout GraphicsContext, size: CGSize, hour h: Double) {
    let p = skyPalette(forHour: h)
    let w = size.width, ht = size.height
    let scale = min(w, ht) / 390

    // Sun rides 5:40→19:00 (opacity ramps 4.9-6.0 in, 18.1-19.4 out); moon 18:20→6:20,
    // continuous across midnight via `hh`.
    let sunT = clamp01((h - 6) / 12)
    let sunUp = sin(sunT * .pi)
    let sunO = min(ramp(h, 4.9, 6.0), 1 - ramp(h, 18.1, 19.4))
    let hh = h < 12 ? h + 24 : h
    let moonT = clamp01((hh - 18) / 12)
    let moonUp = sin(moonT * .pi)
    let moonO = min(ramp(hh, 18.4, 20.2), 1 - ramp(hh, 27.4, 29.0))

    let sunHi = Color(hex: 0xfffaf0)
    let sunBody = lerp(Color(hex: 0xf6d9b4), Color(hex: 0xf9f2e0), sunUp)
    let sunEdge = lerp(Color(hex: 0xe5a274), Color(hex: 0xf2e2c0), sunUp)
    let sunX = 10 + sunT * 80, sunY = 80 - sunUp * 68
    let sunW = 7 + (1 - sunUp) * 6.5

    let moonHi = Color(hex: 0xf7f6ff)
    let moonBody = Color(hex: 0xdcd9f0)
    let moonEdge = Color(hex: 0xa9a3c9)
    let moonX = 10 + moonT * 80, moonY = 80 - moonUp * 66
    let moonW = 5.4 + (1 - moonUp) * 2.6

    // 3. Blooms — horizon bloom first, then the soft halos riding with each disc.
    drawBloom(&context, size: size, x: 50, y: 104, wPercent: 190, color: p.hz, colorOpacity: 0.7, opacity: 0.5)
    if sunO > 0.01 {
        drawBloom(&context, size: size, x: sunX, y: sunY + 3, wPercent: 130,
                  color: lerp(Color(hex: 0xe08f63), Color(hex: 0xf4e8cc), sunUp), colorOpacity: 0.55,
                  opacity: sunO * (0.34 + (1 - sunUp) * 0.3))
    }
    if moonO > 0.01 {
        drawBloom(&context, size: size, x: moonX, y: moonY, wPercent: 70, color: skyAccent, colorOpacity: 0.5, opacity: moonO * 0.28)
    }

    // 4. Sun / moon discs, each with its own tight glow.
    drawDisc(&context, size: size, x: sunX, y: sunY, wPercent: sunW, opacity: sunO,
             highlight: sunHi, body: sunBody, edge: sunEdge,
             glowColor: lerp(Color(hex: 0xe08f63), Color(hex: 0xf6e6c4), sunUp), glowOpacity: 0.30 + (1 - sunUp) * 0.22,
             glowBlur: (52 + (1 - sunUp) * 68) * scale, glowSpread: (8 + (1 - sunUp) * 16) * scale)
    drawDisc(&context, size: size, x: moonX, y: moonY, wPercent: moonW, opacity: moonO,
             highlight: moonHi, body: moonBody, edge: moonEdge,
             glowColor: skyAccent, glowOpacity: 0.34, glowBlur: 46 * scale, glowSpread: 6 * scale)

    // 5. Clouds, tinted warm toward the sun's highlight as it rises.
    let lightC = lerp(p.cloudTint, sunHi, sunO * 0.35 * sunUp)
    for cloud in skyCloudBases {
        drawCloud(&context, size: size, x: cloud.x, y: cloud.y, wPercent: cloud.w, hPercent: cloud.h,
                  blur: cloud.blur * scale, opacity: p.cloudAlpha * cloud.o, color: lightC)
    }

    // 6. Atmospheric haze — bottom 34%.
    let hazeRect = CGRect(x: 0, y: ht * 0.66, width: w, height: ht * 0.34)
    context.fill(Path(hazeRect), with: .linearGradient(
        Gradient(stops: [
            .init(color: p.haze.opacity(0), location: 0),
            .init(color: p.haze.opacity(0.3), location: 0.55),
            .init(color: p.haze.opacity(0.62), location: 1),
        ]),
        startPoint: CGPoint(x: 0, y: hazeRect.minY), endPoint: CGPoint(x: 0, y: hazeRect.maxY)
    ))

    // 7. Terrain — mountain ridges, ground, lake with reflection, mist.
    let lit = max(sunO * sunUp, moonO * moonUp * 0.45)
    let domX = sunO >= moonO ? sunX : moonX
    drawTerrain(&context, size: size, palette: p, lit: lit, sunColor: sunBody, moonColor: moonBody, sunO: sunO, moonO: moonO, domX: domX, scale: scale)
}

private func drawBloom(_ context: inout GraphicsContext, size: CGSize, x: Double, y: Double, wPercent: Double, color: Color, colorOpacity: Double, opacity: Double) {
        guard opacity > 0.005 else { return }
        let d = wPercent / 100 * size.width
        let rect = CGRect(x: x / 100 * size.width - d / 2, y: y / 100 * size.height - d / 2, width: d, height: d)
        context.opacity = opacity
        context.fill(Path(ellipseIn: rect), with: .radialGradient(
            Gradient(stops: [.init(color: color.opacity(colorOpacity), location: 0), .init(color: color.opacity(0), location: 0.7)]),
            center: CGPoint(x: rect.midX, y: rect.midY), startRadius: 0, endRadius: d / 2
        ))
        context.opacity = 1
    }

    private func drawDisc(_ context: inout GraphicsContext, size: CGSize, x: Double, y: Double, wPercent: Double, opacity: Double,
                           highlight: Color, body: Color, edge: Color, glowColor: Color, glowOpacity: Double, glowBlur: Double, glowSpread: Double) {
        guard opacity > 0.005 else { return }
        let d = wPercent / 100 * size.width
        let rect = CGRect(x: x / 100 * size.width - d / 2, y: y / 100 * size.height - d / 2, width: d, height: d)
        context.opacity = opacity

        // A radial gradient standing in for a Gaussian blur — Canvas's `.blur()` filter
        // disperses a shape this small over a much wider area than the same numeric
        // radius reads as a CSS `box-shadow` blur. Reproducing the actual CSS math
        // (a disc of radius R blurred by a Gaussian of sigma = blur/2, per the CSS
        // Backgrounds spec) instead of an eyeballed falloff is what makes this match
        // the design exactly rather than approximately: the blurred edge of a disc is
        // an erfc profile centered on R with that same sigma.
        let edgeRadius = d / 2 + glowSpread
        let sigma = max(glowBlur / 2, 0.01)
        let maxRadius = edgeRadius + 4 * sigma // erfc(4) ≈ 1.5e-8, i.e. visually zero
        let stopCount = 16
        let stops: [Gradient.Stop] = (0...stopCount).map { i in
            let t = Double(i) / Double(stopCount)
            let r = t * maxRadius
            let alpha = 0.5 * erfc((r - edgeRadius) / (sigma * 1.4142135623730951))
            return .init(color: glowColor.opacity(glowOpacity * alpha), location: t)
        }
        context.fill(Path(ellipseIn: CGRect(x: rect.midX - maxRadius, y: rect.midY - maxRadius, width: maxRadius * 2, height: maxRadius * 2)), with: .radialGradient(
            Gradient(stops: stops),
            center: CGPoint(x: rect.midX, y: rect.midY), startRadius: 0, endRadius: maxRadius
        ))

        let gradientCenter = CGPoint(x: rect.minX + rect.width * 0.36, y: rect.minY + rect.height * 0.32)
        context.fill(Path(ellipseIn: rect), with: .radialGradient(
            Gradient(stops: [
                .init(color: highlight, location: 0),
                .init(color: body, location: 0.55),
                .init(color: edge, location: 1),
            ]),
            center: gradientCenter, startRadius: 0, endRadius: d * 0.72
        ))
        context.opacity = 1
    }

    private func drawCloud(_ context: inout GraphicsContext, size: CGSize, x: Double, y: Double, wPercent: Double, hPercent: Double, blur: Double, opacity: Double, color: Color) {
        guard opacity > 0.005 else { return }
        let w = wPercent / 100 * size.width, h = hPercent / 100 * size.height
        let centerX = x / 100 * size.width, centerY = y / 100 * size.height
        context.opacity = opacity
        context.drawLayer { ctx in
            ctx.addFilter(.blur(radius: blur))
            // CSS `radial-gradient(closest-side at 46% 58%, ...)`: an off-center ellipse
            // whose radius in each axis is the distance from that center to the *nearer*
            // edge on that axis — not a circle of radius max(w,h)/2, which stretched thin,
            // wide clouds (h far smaller than w) into flat bars instead of tapered ovals.
            // Built like the specular column: scale the space so a unit circle becomes
            // the right ellipse, centered at the gradient's actual (off-center) point.
            let offsetX = (0.46 - 0.5) * w, offsetY = (0.58 - 0.5) * h
            let radiusX = w / 2 - abs(offsetX), radiusY = h / 2 - abs(offsetY)
            ctx.translateBy(x: centerX + offsetX, y: centerY + offsetY)
            ctx.scaleBy(x: radiusX, y: radiusY)
            ctx.fill(Path(ellipseIn: CGRect(x: -1, y: -1, width: 2, height: 2)), with: .radialGradient(
                Gradient(stops: [
                    .init(color: color.opacity(0.9), location: 0),
                    .init(color: color.opacity(0.5), location: 0.48),
                    .init(color: color.opacity(0), location: 0.82),
                ]),
                center: .zero, startRadius: 0, endRadius: 1
            ))
        }
        context.opacity = 1
    }

    private func drawTerrain(_ context: inout GraphicsContext, size: CGSize, palette p: SkyPalette, lit: Double, sunColor: Color, moonColor: Color, sunO: Double, moonO: Double, domX: Double, scale: CGFloat) {
        let w = size.width, ht = size.height

        for ridge in ridgeShapes {
            let rect = CGRect(
                x: -0.02 * w,
                y: ht - ht * (ridge.bottomPercent + ridge.heightPercent) / 100,
                width: 1.04 * w,
                height: ht * ridge.heightPercent / 100
            )
            let cTop = lerp(lerp(p.hz, .white, 0.10 * (1 - ridge.ink) + lit * 0.12), skyInk, ridge.ink * 0.72)
            let cMid = lerp(p.hz, skyInk, ridge.ink)
            let cBot = lerp(p.mid, skyInk, min(1, ridge.ink + 0.12))
            let path = ridgePath(ridge.points, in: rect)
            if ridge.blur > 0.01 {
                context.drawLayer { ctx in
                    ctx.addFilter(.blur(radius: ridge.blur * scale))
                    ctx.fill(path, with: .linearGradient(
                        Gradient(stops: [.init(color: cTop, location: 0), .init(color: cMid, location: 0.38), .init(color: cBot, location: 1)]),
                        startPoint: CGPoint(x: 0, y: rect.minY), endPoint: CGPoint(x: 0, y: rect.maxY)
                    ))
                }
            } else {
                context.fill(path, with: .linearGradient(
                    Gradient(stops: [.init(color: cTop, location: 0), .init(color: cMid, location: 0.38), .init(color: cBot, location: 1)]),
                    startPoint: CGPoint(x: 0, y: rect.minY), endPoint: CGPoint(x: 0, y: rect.maxY)
                ))
            }
        }

        // Ground band.
        let groundRect = CGRect(x: 0, y: ht * 0.76, width: w, height: ht * 0.24)
        context.fill(Path(groundRect), with: .linearGradient(
            Gradient(stops: [
                .init(color: p.mid.opacity(0), location: 0),
                .init(color: lerp(p.mid, skyInk, 0.88), location: 0.28),
                .init(color: lerp(p.mid, skyInk, 0.95), location: 1),
            ]),
            startPoint: CGPoint(x: 0, y: groundRect.minY), endPoint: CGPoint(x: 0, y: groundRect.maxY)
        ))

        // Lake — clipped to a soft irregular shoreline on its top edge only.
        let waterRect = CGRect(x: 0, y: ht * (1 - waterHeightPercent / 100), width: w, height: ht * waterHeightPercent / 100)
        let surface = lerp(p.hz, p.mid, 0.35)
        let waterFar = lerp(surface, skyInk, 0.6)
        let waterNear = lerp(surface, skyInk, 0.5)
        let domColor = sunO >= moonO ? sunColor : moonColor

        context.drawLayer { ctx in
            ctx.clip(to: ridgePath(shorelinePoints, in: waterRect))
            ctx.fill(Path(waterRect), with: .linearGradient(
                Gradient(colors: [waterFar, waterNear]),
                startPoint: CGPoint(x: 0, y: waterRect.minY), endPoint: CGPoint(x: 0, y: waterRect.maxY)
            ))

            for (i, ridge) in ridgeShapes.enumerated() {
                let reflHeightPercent = ridge.heightPercent * 0.55 / waterHeightPercent * 100
                let reflRect = CGRect(x: -0.02 * w, y: waterRect.minY, width: 1.04 * w, height: waterRect.height * reflHeightPercent / 100)
                let mirrored = ridge.points.map { (x: $0.x, y: 100 - $0.y) }
                let color = lerp(waterFar, skyInk, 0.18 + Double(i) * 0.16)
                let opacity = 0.9 - Double(i) * 0.12
                let blur = 2.2 - Double(i) * 0.5
                if blur > 0.01 {
                    ctx.drawLayer { inner in
                        inner.addFilter(.blur(radius: blur * scale))
                        inner.fill(ridgePath(mirrored, in: reflRect), with: .color(color.opacity(opacity)))
                    }
                } else {
                    ctx.fill(ridgePath(mirrored, in: reflRect), with: .color(color.opacity(opacity)))
                }
            }

            // Specular column: `radial-gradient(36% 104% at 50% 0%, ...)` on a 24%-wide,
            // full-height box — an ellipse centered at the box's top-middle, wide 36% of
            // the box width and tall 104% of the box height, so only its lower half is
            // ever visible. Canvas's radial gradient is circular only, so the ellipse is
            // built by scaling the coordinate space non-uniformly before drawing a unit
            // circle, then letting the layer's transform stretch it back into shape —
            // a plain box gradient (the earlier version here) reads as a flat-edged
            // rectangle instead of a tapering reflection.
            let specColor = lerp(domColor, .white, 0.12)
            let specO = 0.3 + lit * 0.45
            let specX = max(6, min(94, domX))
            let specBox = CGRect(x: waterRect.minX + (specX / 100 - 0.12) * w, y: waterRect.minY, width: 0.24 * w, height: waterRect.height)
            let specRadiusX = 0.36 * specBox.width
            let specRadiusY = 1.04 * specBox.height
            ctx.drawLayer { inner in
                inner.translateBy(x: specBox.midX, y: specBox.minY)
                inner.scaleBy(x: specRadiusX, y: specRadiusY)
                inner.fill(Path(ellipseIn: CGRect(x: -1, y: -1, width: 2, height: 2)), with: .radialGradient(
                    Gradient(stops: [
                        .init(color: specColor.opacity(specO), location: 0),
                        .init(color: specColor.opacity(0), location: 0.76),
                    ]),
                    center: .zero, startRadius: 0, endRadius: 1
                ))
            }

            // Shoreline highlight.
            let shoreRect = CGRect(x: waterRect.minX, y: waterRect.minY, width: waterRect.width, height: waterRect.height * 0.16)
            let shoreColor = lerp(surface, .white, 0.3).opacity(0.16 + lit * 0.1)
            ctx.fill(Path(shoreRect), with: .linearGradient(
                Gradient(colors: [shoreColor, shoreColor.opacity(0)]),
                startPoint: CGPoint(x: 0, y: shoreRect.minY), endPoint: CGPoint(x: 0, y: shoreRect.maxY)
            ))
        }

        // Mist band, above the lake.
        let mistRect = CGRect(x: 0, y: ht * (1 - 0.29), width: w, height: ht * 0.14)
        let mistColor = p.haze.opacity(0.22 + lit * 0.08)
        context.fill(Path(mistRect), with: .linearGradient(
            Gradient(stops: [
                .init(color: mistColor.opacity(0), location: 0),
                .init(color: mistColor, location: 0.42),
                .init(color: mistColor.opacity(0), location: 1),
            ]),
            startPoint: CGPoint(x: 0, y: mistRect.maxY), endPoint: CGPoint(x: 0, y: mistRect.minY)
        ))
    }

