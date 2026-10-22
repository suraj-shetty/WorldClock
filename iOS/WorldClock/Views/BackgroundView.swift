import SwiftUI

// MARK: - The sky
// A port of the canvas's Sky board (`Sky.dc.html`), layer for layer: gradient and Milky
// Way, stars, sun rays, bloom, moon, sun, lit clouds, haze, four lit mountain ranges with
// snow and mist, the shoreline pines, and a rippled lake reflection with glints.
// SkyLight holds the maths; this file only draws. Noise surfaces use Sky.metal.

/// Full-bleed sky for `hour` (0..<24 in the active anchor's zone).
///
/// Like the canvas's main window, the scene is rendered once per 15-minute step and
/// faded to the next, so scrubbing never redraws the shader layers per frame (PLAN
/// performance rule 1). The new step fades in over the old one, which stays opaque until
/// it's removed: a symmetric crossfade left both half transparent and the window showed
/// through mid-fade, a visible flicker on every step. The two slots keep a fixed order:
/// swapping their zIndex reordered the layers and redrew the shown frame, flashing the sky
/// through its unfinished front. So a new step in the upper slot fades in, and one in the
/// lower slot waits underneath while the old one fades out. Either way it gets a moment to
/// draw before it shows. Newer steps that arrive mid-fade
/// wait for it to finish, then the latest one is shown.
struct BackgroundView: View {
    var hour: Double
    /// Off for the widget: WidgetKit snapshots a still frame, so twinkle and sway would be wasted.
    var animated = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Two frames' steps, slot 1 above slot 0: `top` is the one shown, the other is only
    /// there during a fade.
    @State private var slots: [Double?] = [nil, nil]
    @State private var opacities = [1.0, 1.0]
    @State private var top = 0
    @State private var latest: Double?
    @State private var fading = false

    private var step: Double { normalizedHour((normalizedHour(hour) * 4).rounded() / 4) }

    var body: some View {
        // The phase is sampled per day (PLAN performance rule 3), so this is stable across renders.
        let day = Date(timeIntervalSince1970: (Date.now.timeIntervalSince1970 / 86400).rounded(.down) * 86400 + 43200)
        let shown = slots[top] == nil ? [step, nil] : slots
        ZStack {
            ForEach(0..<2, id: \.self) { i in
                if let h = shown[i] {
                    SkyFrame(step: h, hour: hour, day: day, animated: animated && !reduceMotion)
                        .id(h)
                        // Fade the frame as one picture. Per layer, the sky showed through
                        // the half-faded mountains (up to 25% at mid-fade).
                        .compositingGroup()
                        .opacity(opacities[i])
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { if slots[top] == nil { slots[top] = step } }
        .onChange(of: step) { _, new in
            latest = new
            advance()
        }
    }

    private func advance() {
        guard !fading, let target = latest, target != slots[top] else { return }
        fading = true
        let fade = animated && !reduceMotion ? 0.46 : 0
        let old = top, new = 1 - top
        var instant = Transaction()
        instant.disablesAnimations = true
        // 0.001, not 0: a fully transparent layer isn't drawn, so it wouldn't get ahead.
        withTransaction(instant) {
            slots[new] = target
            opacities[new] = new == 1 && fade > 0 ? 0.001 : 1
        }
        Task { @MainActor in
            if fade > 0 {
                try? await Task.sleep(for: .seconds(0.1))
                withAnimation(.easeInOut(duration: fade)) {
                    if new == 1 { opacities[1] = 1 } else { opacities[1] = 0 }
                }
                try? await Task.sleep(for: .seconds(fade + 0.04))
            }
            withTransaction(instant) {
                top = new
                slots[old] = nil
                opacities[old] = 1
            }
            fading = false
            advance()
        }
    }
}

/// One rendered step: the static back (sky, Milky Way, bloom), the animated stars and
/// rays, the sun and moon, the static front (clouds down to the lake), then the animated glints.
private struct SkyFrame: View {
    let step, hour: Double
    let day: Date
    let animated: Bool

    var body: some View {
        let light = SkyLight(hour: step, day: day)
        ZStack {
            StaticSky(light: light, part: .back).equatable()
            if animated {
                SkyMotion(light: light, part: .below)
            } else {
                StaticSky(light: light, part: .stillBelow).equatable()
            }
            SkyBodies(drawn: light, live: SkyLight(hour: hour, day: day))
            StaticSky(light: light, part: .front).equatable()
            if animated {
                SkyMotion(light: light, part: .glints)
            } else {
                StaticSky(light: light, part: .stillGlints).equatable()
            }
        }
    }
}

/// The sun and moon, drawn at the frame's step but placed at the live hour. Baked into the
/// stepped frame they jumped 15 minutes at a time (about 25 pt) while scrubbing; an offset
/// glides them for the cost of a transform.
private struct SkyBodies: View {
    let drawn, live: SkyLight

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                StaticSky(light: drawn, part: .moon).equatable()
                    .offset(x: w * (live.moon.x - drawn.moon.x), y: h * (live.moon.y - drawn.moon.y))
                StaticSky(light: drawn, part: .sun).equatable()
                    .offset(x: w * (live.sun.x - drawn.sun.x), y: h * (live.sun.y - drawn.sun.y))
            }
        }
        // A step changes inside the fade's animation; the offset must not ride it.
        .transaction { $0.animation = nil }
        .allowsHitTesting(false)
    }
}

/// The expensive layers. Equatable on the light alone, so the board's 1-second ticks
/// never redraw it; only a new 15-minute step (a new SkyFrame) or a resize does.
private struct StaticSky: View, Equatable {
    enum Part { case back, moon, sun, front, stillBelow, stillGlints }
    let light: SkyLight
    let part: Part

    var body: some View {
        Canvas { context, size in
            let sky = SkyRenderer(light, size: size)
            switch part {
            case .back:
                sky.drawBack(&context)
                sky.drawBloom(&context)
            case .moon: sky.drawMoon(&context)
            case .sun: sky.drawSun(&context)
            case .front:
                sky.drawFront(&context, bodies: false)
                sky.drawLake(&context)
                sky.drawGhosts(&context)
            case .stillBelow: sky.drawStillBelow(&context)
            case .stillGlints: sky.drawStillGlints(&context)
            }
        }
    }
}

// MARK: - Noise tables

/// feTurbulence's seeded lattice and gradients, from the SVG spec's reference `init`.
enum SkyNoise {
    static func table(seed: Int) -> [Float] {
        let m = 2147483647, a = 16807, q = 127773, r = 2836
        var s = seed <= 0 ? -(seed % (m - 1)) + 1 : min(seed, m - 1)
        func random() -> Int {
            var x = a * (s % q) - r * (s / q)
            if x <= 0 { x += m }
            s = x
            return x
        }
        var lattice = [Int](repeating: 0, count: 514)
        var gradients = [[Double]](repeating: [Double](repeating: 0, count: 514 * 2), count: 4)
        for k in 0..<4 {
            for i in 0..<256 {
                lattice[i] = i
                for j in 0..<2 { gradients[k][i * 2 + j] = Double(random() % 512 - 256) / 256 }
                let length = max(hypot(gradients[k][i * 2], gradients[k][i * 2 + 1]), 1e-9)
                gradients[k][i * 2] /= length
                gradients[k][i * 2 + 1] /= length
            }
        }
        var i = 255
        while i > 0 {
            let k = lattice[i], j = random() % 256
            lattice[i] = lattice[j]
            lattice[j] = k
            i -= 1
        }
        for i in 0..<258 {
            lattice[256 + i] = lattice[i]
            for k in 0..<4 {
                gradients[k][(256 + i) * 2] = gradients[k][i * 2]
                gradients[k][(256 + i) * 2 + 1] = gradients[k][i * 2 + 1]
            }
        }
        return lattice.map(Float.init) + gradients.flatMap { $0.map(Float.init) }
    }

    /// Every seed the canvas uses: ripple 5, clouds 8, regolith 11, Milky Way 21, snow 31, rock 40–43.
    static let tables: [Int: [Float]] = Dictionary(uniqueKeysWithValues: [5, 8, 11, 21, 31, 40, 41, 42, 43].map { ($0, table(seed: $0)) })
}

// MARK: - Renderer

private let ink = RGB(0x090b18)

private extension GraphicsContext {
    mutating func fill(_ rect: CGRect, _ shading: Shading) { fill(Path(rect), with: shading) }

    /// An SVG `<g opacity mix-blend-mode>`: draws into a layer, then composites the
    /// whole layer once. (Opacity set inside a layer applies to each draw instead.)
    func group(opacity: Double = 1, blend: BlendMode = .normal, _ content: (inout GraphicsContext) -> Void) {
        var outer = self
        outer.opacity = opacity
        outer.blendMode = blend
        outer.drawLayer { content(&$0) }
    }
}

private func point(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }

private func gradient(_ stops: [(RGB, Double, Double)]) -> Gradient {
    Gradient(stops: stops.map { .init(color: $0.0.color($0.1), location: $0.2) })
}

/// One twinkling shape, as SMIL `values="o;o·lo;o"`: down and back up once per
/// `duration`, starting `begin` seconds in.
struct Twinkle {
    let path: Path
    let color: RGB
    let opacity, low, duration, begin: Double

    func value(at time: Double) -> Double {
        let phase = ((time - begin).truncatingRemainder(dividingBy: duration) + duration).truncatingRemainder(dividingBy: duration) / duration
        let dip = opacity * low
        return phase < 0.5 ? opacity + (dip - opacity) * phase * 2 : dip + (opacity - dip) * (phase - 0.5) * 2
    }
}

struct RayFan {
    let center: CGPoint
    let radius: Double
    let core, glow: RGB
    let rays: [Twinkle]
    let opacity, blur: Double

    /// The rays' radial fade, from a white-hot core out to nothing.
    var stops: [(RGB, Double, Double)] { [(core, 0.95, 0), (glow, 0.6, 0.12), (glow, 0.22, 0.38), (glow, 0.06, 0.7), (glow, 0, 1)] }
}

private func oneDecimal(_ v: Double) -> Double { (v * 10).rounded() / 10 }

/// Draws one SkyLight at one size. Every number below is the canvas's.
struct SkyRenderer {
    let L: SkyLight
    let p: SkyPalette
    let W, H, m, sc, hor, lakeY: Double
    let sun, moon, light: CGPoint
    let rs, rm, low: Double
    let glowC, lightC: RGB
    let ls, lAlt: Double

    init(_ sky: SkyLight, size: CGSize) {
        L = sky
        p = sky.palette
        W = max(size.width, 1)
        H = max(size.height, 1)
        m = min(W, H)
        sc = 880 / W
        hor = H * 0.71
        lakeY = H * 0.78
        sun = point(W * sky.sun.x, H * sky.sun.y)
        moon = point(W * sky.moon.x, H * sky.moon.y)
        light = sky.usesSun ? sun : moon
        low = 1 - sky.sunUp
        rs = max(6, m * 0.032) * (1 + 0.12 * low)
        rm = max(7, m * 0.05)
        glowC = sky.glowColor
        lightC = sky.lightColor
        ls = sky.strength
        lAlt = sky.lightAltitude
    }

    private var full: CGRect { CGRect(x: 0, y: 0, width: W, height: H) }

    // The shader layers' light. The canvas lights them from a 15-minute step; a SkyFrame already is one.
    private var lightQ: (azimuth: Double, elevation: Double, strength: Double, color: RGB) {
        let azimuth = (atan2(light.y - H * 0.55, light.x - W / 2) * 180 / .pi).rounded()
        let elevation = (5 + 52 * lAlt).rounded()
        let strength = L.usesSun ? L.glow : 0.5 * clamp01((L.moon.alt + 0.04) / 0.12)
        return (azimuth, elevation, strength, lightC)
    }

    private var lightVector: SIMD3<Float> {
        let a = lightQ.azimuth * .pi / 180, e = lightQ.elevation * .pi / 180
        return SIMD3(Float(cos(a) * cos(e)), Float(sin(a) * cos(e)), Float(sin(e)))
    }

    // MARK: Back: gradient and Milky Way

    func drawBack(_ ctx: inout GraphicsContext) {
        ctx.fill(full, .linearGradient(
            Gradient(stops: [.init(color: p.top.color, location: 0), .init(color: p.up.color, location: 0.3),
                             .init(color: p.mid.color, location: 0.55), .init(color: p.hz.color, location: 0.72),
                             .init(color: p.hz.color, location: 1)]),
            startPoint: .zero, endPoint: point(0, H)))
        drawMilkyWay(&ctx)
    }

    private func drawMilkyWay(_ ctx: inout GraphicsContext) {
        let alpha = 0.26 * clamp01((p.star - 0.45) / 0.55)
        guard alpha > 0.005 else { return }
        let angle = -16 * Double.pi / 180, pivot = point(W / 2, H * 0.23)
        let rect = CGRect(x: -W * 0.2, y: H * 0.12, width: W * 1.4, height: H * 0.22)
        let turn = CGAffineTransform(translationX: pivot.x, y: pivot.y).rotated(by: angle).translatedBy(x: -pivot.x, y: -pivot.y)
        let band = Path(rect).applying(turn)
        let c = RGB(0xdcd8f4)
        ctx.group(opacity: alpha) { layer in
            layer.fill(band, with: .shader(ShaderLibrary.skyNoise(
                .floatArray(SkyNoise.tables[21]!), .float2(0.006 * sc, 0.02 * sc), .float(4), .float(0),
                .float3(c.r / 255, c.g / 255, c.b / 255), .float2(2.6, -1), .float3(angle, pivot.x, pivot.y))))
            // The band fades out toward its long edges (mask in the rect's own box).
            layer.blendMode = .destinationIn
            layer.fill(Path(full), with: .linearGradient(
                Gradient(stops: [.init(color: .clear, location: 0), .init(color: .white, location: 0.5), .init(color: .clear, location: 1)]),
                startPoint: point(rect.midX, rect.minY).applying(turn), endPoint: point(rect.midX, rect.maxY).applying(turn)))
        }
    }

    // MARK: Animated layers: stars and rays (below the front), glints (above it)
    // Their geometry, shared by the Core Animation layers (SkyMotion) and the still frame.

    var starOpacity: Double { clamp01(p.star * 1.1) }

    var stars: [Twinkle] {
        guard p.star > 0.02 else { return [] }
        let rnd = seededRandom(9301)
        let tints: [UInt32] = [0xf3f5fe, 0xd4ddff, 0xfff0d8, 0xffdcc8, 0xe9ecff]
        return (0..<110).map { _ in
            let o = 0.3 + rnd() * 0.7, big = rnd()
            let x = rnd() * W, y = rnd() * hor * 0.85
            let r = (0.35 + big * big * big * 1.5) * (m / 540 + 0.4)
            let fill = RGB(tints[Int(rnd() * 5)])
            let lo = 0.2 + rnd() * 0.3, dur = oneDecimal(2.5 + rnd() * 5), begin = oneDecimal(-rnd() * 8)
            return Twinkle(path: Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                           color: fill, opacity: o, low: lo, duration: dur, begin: begin)
        }
    }

    /// The sun's rays: a fan around the sun (paths relative to it), swaying ±1.5° over 47 s.
    var rayFan: RayFan? {
        guard L.glow > 0.02 else { return nil }
        let rr = seededRandom(4242), rayR = max(W, H) * 1.25
        let upF = clamp01((0.45 - L.sunUp) / 0.45)
        let rays = (0..<34).map { _ in
            let u = rr(), fan = -Double.pi * (0.06 + 0.88 * u), all = u * .pi * 2
            let angle = fan * upF + all * (1 - upF)
            let width = 0.006 + pow(rr(), 2.2) * 0.05, length = rayR * (0.45 + rr() * 0.55), o = 0.25 + rr() * 0.75
            let lo = 0.45 + rr() * 0.3, dur = oneDecimal(7 + rr() * 9), begin = oneDecimal(-rr() * 12)
            var ray = Path()
            ray.move(to: .zero)
            ray.addLine(to: point(cos(angle - width) * length, sin(angle - width) * length))
            ray.addLine(to: point(cos(angle + width) * length, sin(angle + width) * length))
            ray.closeSubpath()
            return Twinkle(path: ray, color: glowC, opacity: o, low: lo, duration: dur, begin: begin)
        }
        return RayFan(center: sun, radius: rayR, core: glowC.mix(RGB(0xffffff), 0.5), glow: glowC, rays: rays,
                      opacity: L.glow * (0.14 + 0.5 * upF * upF), blur: max(0.6, m * 0.009))
    }

    var glints: [Twinkle] {
        guard L.light.alt > -0.03 && ls > 0.05 else { return [] }
        let gr = seededRandom(55), lr = L.usesSun ? rs : rm, depth = H - lakeY
        return (0..<9).map { _ in
            let gy = lakeY + 4 + pow(gr(), 1.4) * (depth - 6)
            let spread = 1 + (gy - lakeY) / depth
            let gw = lr * (0.3 + gr() * 0.9) * spread, go = ls * (0.35 + gr() * 0.5)
            let x = light.x - gw / 2 + (gr() - 0.5) * lr * 2 * spread
            let h = 0.8 + gr(), dur = oneDecimal(0.9 + gr() * 1.6), begin = oneDecimal(-gr() * 3)
            return Twinkle(path: Path(roundedRect: CGRect(x: x, y: gy, width: gw, height: h), cornerRadius: 0.6),
                           color: RGB(0xfffaf0), opacity: go, low: 0.1, duration: dur, begin: begin)
        }
    }

    /// Stars and rays as one still frame, for the widget and Reduce Motion.
    func drawStillBelow(_ ctx: inout GraphicsContext) {
        ctx.group(opacity: starOpacity) { l in
            for star in stars { l.fill(star.path, with: .color(star.color.color(star.value(at: 0)))) }
        }
        guard let fan = rayFan else { return }
        let shading = GraphicsContext.Shading.radialGradient(
            gradient(fan.stops), center: .zero, startRadius: 0, endRadius: fan.radius)
        ctx.group(opacity: fan.opacity, blend: .screen) { l in
            l.addFilter(.blur(radius: fan.blur))
            l.translateBy(x: fan.center.x, y: fan.center.y)
            for ray in fan.rays {
                var single = l
                single.opacity = ray.value(at: 0)
                single.fill(ray.path, with: shading)
            }
        }
    }

    func drawStillGlints(_ ctx: inout GraphicsContext) {
        ctx.group(blend: .screen) { l in
            for glint in glints { l.fill(glint.path, with: .color(glint.color.color(glint.value(at: 0)))) }
        }
    }

    // MARK: Front: bloom, moon, sun, clouds, haze, ranges, trees

    /// `bodies: false` leaves the bloom, moon and sun to their own layers (SkyBodies); the
    /// lake reflection keeps them, stepped (PLAN rule 2).
    func drawFront(_ ctx: inout GraphicsContext, bodies: Bool = true) {
        let glow = L.glow
        if bodies {
            drawBloom(&ctx)
            drawMoon(&ctx)
            drawSun(&ctx)
        }
        drawClouds(&ctx)
        ctx.fill(CGRect(x: 0, y: hor - H * 0.2, width: W, height: H * 0.2 + 2), .linearGradient(
            gradient([(p.haze, 0, 0), (p.haze, 0.75, 1)]), startPoint: point(0, hor - H * 0.2), endPoint: point(0, hor + 2)))
        let warmA = L.usesSun ? 0.45 * glow * low : 0.12 * L.moonVisibility
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: lakeY), .radialGradient(
            gradient([(lightC, warmA, 0), (lightC, 0, 1)]), center: point(light.x, hor), startRadius: 0, endRadius: W * 0.6))
        drawRanges(&ctx)
        drawTrees(&ctx)
    }

    func drawBloom(_ ctx: inout GraphicsContext) {
        let sunUp = L.sunUp, glow = L.glow
        let aureole = RGB(0xffc48a).mix(RGB(0xffffff), sunUp)
        ctx.fill(full, .radialGradient(
            gradient([(aureole, 0.35 + 0.4 * sunUp * glow, 0), (glowC, 0.4 * glow, 0.12), (glowC, 0.16 * glow, 0.45), (glowC, 0, 1)]),
            center: sun, startRadius: 0, endRadius: max(W, H) * 0.6))
    }

    private var rim: GraphicsContext.Shading {
        .radialGradient(gradient([(lightC, 0.95 * ls, 0), (lightC, 0.35 * ls, 0.55), (lightC, 0, 1)]),
                        center: light, startRadius: 0, endRadius: W * 0.42)
    }

    func drawSun(_ ctx: inout GraphicsContext) {
        let sunUp = L.sunUp, vis = clamp01((L.sun.alt + 0.1) / 0.12)
        guard vis > 0.001 else { return }
        let squash = 0.84 + 0.16 * clamp01(L.sun.alt / 0.18), sry = rs * squash
        func disc(_ r: Double) -> CGRect { CGRect(x: sun.x - r, y: sun.y - r, width: r * 2, height: r * 2) }
        ctx.group(opacity: vis) { g in
            g.drawLayer { l in
                l.opacity = 0.35 + 0.35 * low
                l.addFilter(.blur(radius: rs * 1.3))
                l.fill(Path(ellipseIn: disc(rs * 2.4)), with: .color(glowC.color))
            }
            g.drawLayer { l in
                l.opacity = 0.5 + 0.45 * sunUp
                l.addFilter(.blur(radius: rs * 0.45))
                l.fill(Path(ellipseIn: disc(rs * 1.25)), with: .color(RGB(0xfffdf7).color))
            }
            // The disc: overexposed core, then reddening and flattening toward the horizon.
            let body = Path(ellipseIn: CGRect(x: sun.x - rs, y: sun.y - sry, width: rs * 2, height: sry * 2))
            let core = RGB(0xffd9a0).mix(RGB(0xfffaf0), sunUp), bodyC = RGB(0xf7954f).mix(RGB(0xfff4dc), sunUp)
            let edge = RGB(0xe0602c).mix(RGB(0xf8e3b8), sunUp), limb = RGB(0xb83a1e).mix(RGB(0xedcf98), sunUp)
            // The canvas softens the disc's edge by a fraction of a point.
            let edgeBlur = max(0.3, rs * 0.035)
            g.drawLayer { l in
                l.addFilter(.blur(radius: edgeBlur))
                l.translateBy(x: sun.x, y: sun.y)
                l.scaleBy(x: 1, y: squash)
                l.fill(Path(ellipseIn: CGRect(x: -rs, y: -rs, width: rs * 2, height: rs * 2)), with: .radialGradient(
                    Gradient(stops: [.init(color: .white, location: 0), .init(color: core.color, location: 0.25 + 0.4 * sunUp),
                                     .init(color: bodyC.color, location: 0.82), .init(color: edge.color, location: 0.96),
                                     .init(color: limb.color, location: 1)]),
                    center: .zero, startRadius: 0, endRadius: rs))
            }
            g.drawLayer { l in
                l.addFilter(.blur(radius: edgeBlur))
                l.opacity = 0.9 * pow(low, 3)
                l.fill(body, with: .linearGradient(
                    gradient([(RGB(0xffb36b), 0, 0), (RGB(0xe2582a), 0.35, 0.55), (RGB(0xa8261a), 0.85, 1)]),
                    startPoint: point(sun.x, sun.y - sry), endPoint: point(sun.x, sun.y + sry)))
            }
            if low > 0.82 {
                for (k, t) in [0.18, 0.42, 0.62, 0.78].enumerated() {
                    let half = rs * sqrt(max(0, 1 - t * t))
                    let o = (0.2 + Double(k) * 0.08) * clamp01((low - 0.82) / 0.18)
                    g.fill(Path(CGRect(x: sun.x - half, y: sun.y + sry * t, width: half * 2, height: rs * (0.035 + Double(k) * 0.015))),
                           with: .color(p.hz.color(o)))
                }
            }
            // Faint diffraction spikes when the sun is high.
            g.group(opacity: 0.35 * pow(sunUp, 1.5), blend: .screen) { l in
                let length = rs * 7.5
                for degrees in [0.0, 60, 120] {
                    var s = l
                    s.translateBy(x: sun.x, y: sun.y)
                    s.rotate(by: .degrees(degrees + 14))
                    s.fill(Path(CGRect(x: -length, y: -0.45, width: length * 2, height: 0.9)), with: .linearGradient(
                        Gradient(stops: [.init(color: .clear, location: 0), .init(color: .white, location: 0.5), .init(color: .clear, location: 1)]),
                        startPoint: point(-length, 0), endPoint: point(length, 0)))
                }
            }
        }
    }

    func drawMoon(_ ctx: inout GraphicsContext) {
        let vis = L.moonVisibility
        guard vis > 0.001 else { return }
        let phase = L.moonPhase, illum = phase.illumination
        let mx = moon.x, my = moon.y, dir: Double = phase.waxing ? 1 : -1
        let moonUp = clamp01(L.moon.alt), warm = pow(1 - moonUp, 2.5)
        let discRect = CGRect(x: mx - rm, y: my - rm, width: rm * 2, height: rm * 2)
        let disc = Path(ellipseIn: discRect)

        // The lit part: the right half-disc plus a half-ellipse terminator (left bulge when
        // gibbous, right when crescent), mirrored when waning.
        var lit = Path()
        let kx = rm * abs(cos(phase.phaseAngle)), bulge: Double = illum > 0.5 ? -1 : 1
        for k in 0...32 {
            let a = -Double.pi / 2 + Double.pi * Double(k) / 32
            let pt = point(mx + dir * rm * cos(a), my + rm * sin(a))
            if k == 0 { lit.move(to: pt) } else { lit.addLine(to: pt) }
        }
        for k in 0...32 {
            let a = Double.pi / 2 - Double.pi * Double(k) / 32
            lit.addLine(to: point(mx + dir * bulge * kx * cos(a), my + rm * sin(a)))
        }
        lit.closeSubpath()
        let termBlur = max(0.4, rm * 0.06)
        func masked(_ g: inout GraphicsContext, _ draw: (inout GraphicsContext) -> Void) {
            g.drawLayer { l in
                l.clipToLayer { mask in
                    mask.addFilter(.blur(radius: termBlur))
                    mask.fill(lit, with: .color(.white))
                }
                draw(&l)
            }
        }

        let maria: [(Double, Double, Double, Double, Double, Double)] = [
            (-0.3, -0.36, 0.34, 0.27, 0.85, -20), (0.2, -0.32, 0.2, 0.19, 0.9, 0), (0.32, -0.02, 0.25, 0.2, 0.85, 15),
            (0.66, -0.24, 0.12, 0.1, 0.95, 0), (-0.58, 0.06, 0.28, 0.5, 0.7, 10), (-0.16, 0.43, 0.21, 0.14, 0.7, -10),
            (0.5, 0.22, 0.13, 0.18, 0.75, 0), (0.08, 0.12, 0.12, 0.1, 0.55, 0), (-0.05, -0.7, 0.46, 0.07, 0.6, -6),
            (-0.5, 0.42, 0.11, 0.1, 0.65, 0), (0.38, 0.42, 0.09, 0.08, 0.6, 0)]
        func drawMaria(_ l: inout GraphicsContext, color: RGB, opacities: Bool) {
            l.addFilter(.blur(radius: max(0.3, rm * 0.04)))
            for k in maria {
                var e = l
                e.translateBy(x: mx + k.0 * rm, y: my + k.1 * rm)
                e.rotate(by: .degrees(k.5))
                e.fill(Path(ellipseIn: CGRect(x: -k.2 * rm, y: -k.3 * rm, width: k.2 * rm * 2, height: k.3 * rm * 2)),
                       with: .color(color.color(opacities ? min(1, k.4 * 1.05) : 1)))
            }
        }

        ctx.group(opacity: vis) { g in
            // Halo, warmer near the horizon.
            let glowC = RGB(0xe6e2ff).mix(RGB(0xf3d7a8), warm)
            g.drawLayer { l in
                l.opacity = (0.5 + 0.4 * illum) * (1 - 0.7 * L.glow)
                l.addFilter(.blur(radius: rm * 0.7))
                l.fill(Path(ellipseIn: discRect.insetBy(dx: -rm * 5, dy: -rm * 5)), with: .radialGradient(
                    gradient([(glowC, 0.55, 0), (glowC, 0.22, 0.18), (RGB(0x9aa2e0), 0.08, 0.5), (RGB(0x9184d9), 0, 1)]),
                    center: moon, startRadius: 0, endRadius: rm * 6))
            }
            g.drawLayer { clip in
                clip.clip(to: disc)
                // Earthshine on the dark side, strongest near new moon.
                clip.fill(disc, with: .color(RGB(0x2a2e4c).color(0.18 + 0.6 * pow(1 - illum, 2))))
                clip.group(opacity: 0.35) { l in drawMaria(&l, color: RGB(0x0c0e1c), opacities: false) }
                masked(&clip) { l in
                    let hiX = phase.waxing ? 0.62 : 0.38
                    l.fill(disc, with: .radialGradient(
                        Gradient(stops: [.init(color: RGB(0xfbfaf7).color, location: 0), .init(color: RGB(0xe6e4e2).color, location: 0.55),
                                         .init(color: RGB(0xc4c1c4).color, location: 0.9), .init(color: RGB(0xaeabb2).color, location: 1)]),
                        center: point(discRect.minX + hiX * rm * 2, discRect.minY + 0.4 * rm * 2), startRadius: 0, endRadius: 1.5 * rm))
                    // Regolith (linearRGB filter colours .34/.33/.42, shown in sRGB).
                    l.drawLayer { n in
                        n.opacity = 0.7
                        n.fill(disc, with: .shader(ShaderLibrary.skyNoise(
                            .floatArray(SkyNoise.tables[11]!), .float2(2.2 / rm, 2.2 / rm), .float(5), .float(0),
                            .float3(0.62, 0.61, 0.68), .float2(2.2, -0.95), .float3(0, 0, 0))))
                    }
                    l.drawLayer { s in drawMaria(&s, color: RGB(0x5d5a68), opacities: true) }
                    // Craters: the wall facing the sun in shadow, the far wall catching light, strongest near the terminator.
                    let cr = seededRandom(303)
                    for _ in 0..<22 {
                        let ca = cr() * .pi * 2, cd = sqrt(cr()) * 0.88, crr = rm * (0.03 + cr() * cr() * 0.08)
                        let cx = mx + cos(ca) * cd * rm, cy = my + sin(ca) * cd * rm
                        let graze = min(max(1 - abs((cx - mx) / rm - dir * 0.15), 0.25), 1)
                        let sx = cx + dir * crr * 0.35, hx = cx - dir * crr * 0.4, hr = crr * 0.7
                        l.fill(Path(ellipseIn: CGRect(x: sx - crr, y: cy - crr, width: crr * 2, height: crr * 2)), with: .color(RGB(0x23202f).color(0.32 * graze)))
                        l.fill(Path(ellipseIn: CGRect(x: hx - hr, y: cy - hr, width: hr * 2, height: hr * 2)), with: .color(.white.opacity(0.22 * graze)))
                    }
                    // Tycho's rays and the bright craters.
                    let tx = mx - 0.12 * rm, ty = my + 0.72 * rm
                    l.group(opacity: 0.08) { t in
                        for k in 0..<12 {
                            let a = Double(k) / 12 * .pi * 2 + 0.3, length = rm * (0.3 + Double(k % 3) * 0.18)
                            var ray = Path()
                            ray.move(to: point(tx, ty))
                            ray.addLine(to: point(tx + cos(a) * length, ty + sin(a) * length))
                            t.stroke(ray, with: .color(.white), style: StrokeStyle(lineWidth: max(0.4, rm * 0.018), lineCap: .round))
                        }
                    }
                    for b in [(tx, ty, max(0.4, rm * 0.032), 0.55), (mx - 0.3 * rm, my - 0.02 * rm, max(0.35, rm * 0.026), 0.4),
                              (mx - 0.62 * rm, my - 0.18 * rm, max(0.3, rm * 0.022), 0.35)] {
                        l.fill(Path(ellipseIn: CGRect(x: b.0 - b.2, y: b.1 - b.2, width: b.2 * 2, height: b.2 * 2)), with: .color(.white.opacity(b.3)))
                    }
                    // Lambert falloff toward the terminator, and a warm tint low in the sky.
                    l.fill(disc, with: .linearGradient(
                        gradient([(RGB(0), 0, 0), (RGB(0), 0.05, 0.45), (RGB(0), 0.5, 1)]),
                        startPoint: point(phase.waxing ? discRect.maxX : discRect.minX, my),
                        endPoint: point(phase.waxing ? discRect.minX : discRect.maxX, my)))
                    l.fill(disc, with: .color(RGB(0xe9a964).color(0.55 * warm)))
                }
            }
            masked(&g) { l in
                let r = rm - max(0.3, rm * 0.02)
                l.opacity = 0.35
                l.stroke(Path(ellipseIn: CGRect(x: mx - r, y: my - r, width: r * 2, height: r * 2)), with: .color(.white), lineWidth: max(0.5, rm * 0.04))
            }
        }
    }

    private func drawClouds(_ ctx: inout GraphicsContext) {
        let q = lightQ
        let cloudY = H * 0.14, cloudH = H * 0.48
        let cb = -(2.05 - ((p.cloudAlpha * 20).rounded() / 20) * 1.15)
        let lightColor = RGB(0).mix(p.cloud.mix(q.color, 0.55), 0.35 + 0.65 * max(q.strength, 0.25))
        let base = p.cloud.mix(p.top, 0.6)
        let rect = CGRect(x: -W * 0.1, y: cloudY, width: W * 1.2, height: cloudH)
        ctx.group(opacity: clamp01(0.55 + p.cloudAlpha * 0.6)) { l in
            l.fill(rect, .shader(ShaderLibrary.skyLitNoise(
                .floatArray(SkyNoise.tables[8]!), .float2(0.0036 * sc, 0.0105 * sc), .float(5), .float(0),
                .float2(3.4, cb), .float(oneDecimal(4 + 3 * (1 - lAlt))), .float(1.05), .float3(lightVector.x, lightVector.y, lightVector.z),
                .float3(lightColor.r / 255, lightColor.g / 255, lightColor.b / 255),
                .float3(base.r / 255, base.g / 255, base.b / 255), .float(0.85), .float(1))))
            // Masks cover the whole canvas: one the size of the shape left its anti-aliased
            // edge row unmasked, a hairline across the sky.
            l.blendMode = .destinationIn
            l.fill(full, .linearGradient(
                Gradient(stops: [.init(color: .clear, location: 0), .init(color: .white.opacity(0.9), location: 0.25),
                                 .init(color: .white, location: 0.7), .init(color: .clear, location: 1)]),
                startPoint: point(0, cloudY), endPoint: point(0, cloudY + cloudH)))
        }
    }

    // MARK: Mountains

    private struct Range {
        let path, ridge: Path
        let index: Int
        let base, hmax, minY: Double
    }

    /// Alpine silhouettes from overlapping peaks plus fractal ridge detail; farthest palest.
    private var ranges: [Range] {
        let spec: [(Double, Double, Int, Int)] = [(0.67, 0.15, 7, 1), (0.70, 0.095, 9, 2), (0.735, 0.055, 12, 3), (0.765, 0.024, 16, 4)]
        return spec.enumerated().map { ri, sp in
            let base = H * sp.0, hmax = H * sp.1, R = seededRandom(1000 + sp.3 * 97), n = 256
            var peaks: [(Double, Double, Double)] = []
            for _ in 0..<sp.2 {
                let px = (R() * 1.1 - 0.05) * W, ph = hmax * (0.4 + 0.6 * R()), pw = W * (0.05 + 0.09 * R()) * (1 - Double(ri) * 0.12)
                peaks.append((px, ph, pw))
                // Shoulders and sub-summits so peaks read as massifs, not cones.
                let s1x = px + (R() - 0.5) * pw * 1.1, s1h = ph * (0.55 + 0.3 * R()), s1w = pw * (0.35 + 0.3 * R())
                peaks.append((s1x, s1h, s1w))
                let s2x = px + (R() - 0.5) * pw * 1.6, s2h = ph * (0.35 + 0.25 * R()), s2w = pw * (0.5 + 0.4 * R())
                peaks.append((s2x, s2h, s2w))
            }
            var detail = [Double](repeating: 0, count: n + 1)
            var step = n, scale = 1.0
            while step > 1 {
                var k = step / 2
                while k < n {
                    detail[k] = (detail[k - step / 2] + detail[k + step / 2]) / 2 + (R() - 0.5) * scale
                    k += step
                }
                step /= 2
                scale *= 0.62
            }
            var ridge = Path(), minY = Double.infinity
            for k in 0...n {
                let x = Double(k) / Double(n) * W
                var h = 0.0
                for q in peaks {
                    let u = abs(x - q.0) / q.2
                    if u < 1 { h = max(h, q.1 * pow(1 - u, 1.35)) }
                }
                h += hmax * 0.1 + detail[k] * hmax * (0.22 + h / hmax * 0.45)
                let y = base - max(hmax * 0.03, h)
                minY = min(minY, y)
                if k == 0 { ridge.move(to: point(x, y)) } else { ridge.addLine(to: point(x, y)) }
            }
            var path = ridge
            path.addLine(to: point(W, lakeY + 1))
            path.addLine(to: point(0, lakeY + 1))
            path.closeSubpath()
            return Range(path: path, ridge: ridge, index: ri, base: base, hmax: hmax, minY: minY)
        }
    }

    private func drawRanges(_ ctx: inout GraphicsContext) {
        let farBase = p.haze.mix(p.hz, 0.45).mix(ink, 0.18), nearBase = ink.mix(p.top, 0.2)
        let lxn = min(max((light.x - W / 2) / (W * 0.45), -1), 1)
        let q = lightQ
        let reliefLight = RGB(0x7f7f7f).mix(q.color, 0.5 * q.strength)
        let all = ranges
        let snowTop = all[0].minY - 2, snowLine = all[0].minY + (all[0].base - all[0].minY) * 0.45
        let snow = RGB(0xeef1f8).mix(lightC, 0.4 * ls).mix(p.haze, 0.25 + 0.35 * (1 - ls))
        for rg in all {
            let ri = rg.index, t = Double(ri) / 3
            let fill = farBase.mix(nearBase, pow(t, 0.8)), shift = W * 0.05 * (1 - Double(ri) * 0.18)
            let top = rg.minY - 4, box = CGRect(x: 0, y: top, width: W, height: lakeY - rg.minY + 6)
            let litC = fill.mix(lightC, (0.3 - t * 0.14) * ls), foot = p.haze.mix(fill, 0.3 + t * 0.5)
            ctx.drawLayer { l in
                l.clip(to: rg.path)
                l.fill(box, .radialGradient(Gradient(colors: [litC.color, fill.color]),
                                            center: point(light.x, rg.base), startRadius: 0, endRadius: W * 0.55))
                // Rock relief lit from the light's direction, overlaid.
                var relief = l
                relief.opacity = [0.32, 0.42, 0.48, 0.42][ri] * (0.35 + 0.65 * ls)
                relief.blendMode = .overlay
                relief.fill(box, .shader(ShaderLibrary.skyLitNoise(
                    .floatArray(SkyNoise.tables[40 + ri]!), .float2((0.013 + Double(ri) * 0.009) * sc, (0.01 + Double(ri) * 0.007) * sc),
                    .float(5), .float(3), .float2(1, 0), .float(2.2 + Double(ri) * 1.1), .float(1.25), .float3(lightVector.x, lightVector.y, lightVector.z),
                    .float3(reliefLight.r / 255, reliefLight.g / 255, reliefLight.b / 255), .float3(0, 0, 0), .float(1), .float(0))))
                if ri == 0 {
                    l.group(opacity: 0.92) { s in
                        let snowRect = CGRect(x: 0, y: snowTop, width: W, height: max(1, snowLine - snowTop))
                        s.fill(snowRect, .shader(ShaderLibrary.skyNoise(
                            .floatArray(SkyNoise.tables[31]!), .float2(0.03 * sc, 0.012 * sc), .float(4), .float(0),
                            .float3(snow.r / 255, snow.g / 255, snow.b / 255), .float2(4.2, -1.7), .float3(0, 0, 0))))
                        s.blendMode = .destinationIn
                        s.fill(full, .linearGradient(
                            Gradient(stops: [.init(color: .white, location: 0), .init(color: .white.opacity(0.8), location: 0.7), .init(color: .clear, location: 1)]),
                            startPoint: point(0, snowTop), endPoint: point(0, snowLine)))
                    }
                }
                // Slopes turned from the light: the range minus itself nudged toward the light. Lit slopes: the reverse.
                let shade = fill.mix(p.top.mix(ink, 0.55), 0.7)
                let shadeA = (0.35 + 0.65 * abs(lxn)) * (0.3 + 0.7 * ls) * (0.75 + 0.25 * (1 - lAlt))
                band(&l, rg.path, color: shade, opacity: shadeA, dx: lxn * shift, dy: -shift * 0.12, soft: shift * 0.35, blend: .normal)
                band(&l, rg.path, color: lightC, opacity: 0.7 * ls * (0.3 + 0.7 * abs(lxn)), dx: -lxn * shift, dy: -shift * 0.12, soft: shift * 0.35, blend: .softLight)
                l.fill(box, .linearGradient(
                    gradient([(p.haze, 0, 0), (foot, 0.15 - t * 0.08, 0.55), (foot, 0.6 - t * 0.3, 1)]),
                    startPoint: point(0, top), endPoint: point(0, lakeY)))
            }
            var rimmed = ctx
            rimmed.opacity = [1, 0.85, 0.7, 0.55][ri]
            rimmed.stroke(rg.ridge, with: rim, style: StrokeStyle(lineWidth: max(0.8, m * (0.0034 - Double(ri) * 0.0005)), lineJoin: .round))
            if ri < 3 {
                ctx.drawLayer { mist in
                    mist.opacity = 0.3 - Double(ri) * 0.07
                    mist.addFilter(.blur(radius: max(1, m * 0.008)))
                    mist.fill(Path(CGRect(x: 0, y: rg.base - rg.hmax * 0.05, width: W, height: H * 0.03)), with: .color(p.haze.color))
                }
            }
        }
    }

    private func band(_ ctx: inout GraphicsContext, _ shape: Path, color: RGB, opacity: Double, dx: Double, dy: Double, soft: Double, blend: GraphicsContext.BlendMode) {
        var outer = ctx
        outer.blendMode = blend
        outer.opacity = opacity
        outer.drawLayer { l in
            l.fill(shape, with: .color(color.color))
            l.blendMode = .destinationOut
            l.drawLayer { cut in
                cut.addFilter(.blur(radius: soft))
                cut.translateBy(x: dx, y: dy)
                cut.fill(shape, with: .color(.black))
            }
        }
    }

    private func drawTrees(_ ctx: inout GraphicsContext) {
        let tr = seededRandom(77)
        var trees = Path(), tips = Path(), x = 0.0
        while x < W {
            let density = 0.5 + 0.5 * sin(x / W * 13.7) * sin(x / W * 5.3 + 1.2)
            let th = H * 0.03 * (0.45 + 0.8 * tr()) * density, tw = th * 0.26, y = lakeY + 0.5
            if density > 0.18 && th > 1.5 {
                trees.addLines([point(x - tw, y), point(x, y - th), point(x + tw, y)])
                trees.closeSubpath()
                trees.addLines([point(x - tw * 0.7, y - th * 0.4), point(x, y - th * 1.12), point(x + tw * 0.7, y - th * 0.4)])
                trees.closeSubpath()
                let side: Double = light.x > x ? 1 : -1
                tips.move(to: point(x, y - th * 1.12))
                tips.addLine(to: point(x + side * tw * 0.7, y - th * 0.4))
            }
            x += max(1.2, tw * (0.9 + tr() * 1.4))
        }
        ctx.fill(trees, with: .color(ink.mix(p.top, 0.12).color))
        var lit = ctx
        lit.opacity = 0.7
        lit.stroke(tips, with: rim, lineWidth: max(0.5, m * 0.0016))
    }

    // MARK: Lake

    func drawLake(_ ctx: inout GraphicsContext) {
        let lake = CGRect(x: 0, y: lakeY, width: W, height: H - lakeY)
        let lakeDeep = p.top.mix(ink, 0.72)
        ctx.fill(lake, .linearGradient(
            Gradient(stops: [.init(color: p.hz.mix(ink, 0.4).color, location: 0), .init(color: p.mid.mix(ink, 0.62).color, location: 0.45),
                             .init(color: lakeDeep.color, location: 1)]),
            startPoint: point(0, lakeY), endPoint: point(0, H)))
        // The reflection: the static scene mirrored at the shore, rippled. Nothing animated goes in it (PLAN rule 2).
        let scale = H * 0.014
        ctx.drawLayer { r in
            r.clip(to: Path(lake))
            r.opacity = 0.8
            r.addFilter(.distortionShader(ShaderLibrary.skyRipple(
                .floatArray(SkyNoise.tables[5]!), .float2(0.0016 * sc, 0.07 * sc), .float(scale), .float(2 * lakeY)),
                maxSampleOffset: CGSize(width: scale, height: scale)))
            r.drawLayer { mirrored in
                mirrored.translateBy(x: 0, y: 2 * lakeY)
                mirrored.scaleBy(x: 1, y: -1)
                drawBack(&mirrored)
                drawFront(&mirrored)
            }
        }
        ctx.fill(lake, .linearGradient(gradient([(lakeDeep, 0.12, 0), (lakeDeep, 0.45, 0.5), (lakeDeep, 0.78, 1)]),
                                       startPoint: point(0, lakeY), endPoint: point(0, H)))
        ctx.fill(CGRect(x: 0, y: lakeY, width: W, height: 1), .color(lightC.color(0.35 * ls)))
    }

    // MARK: Lens ghosts

    func drawGhosts(_ ctx: inout GraphicsContext) {
        let alpha = 0.12 * L.sunUp * L.glow
        guard alpha > 0.002 else { return }
        let gx = W / 2 - sun.x, gy = H / 2 - sun.y
        ctx.group(opacity: alpha, blend: .screen) { l in
            for g in [(0.55, 0.5, RGB(0xf6c38f), 0.5), (1.15, 1.3, RGB(0xb5abfc), 0.32), (1.45, 0.35, RGB(0x9fe0d4), 0.45), (1.8, 0.9, RGB(0xf6c38f), 0.25)] {
                let c = point(sun.x + gx * g.0, sun.y + gy * g.0), r = rs * g.1
                l.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(g.2.color(g.3)))
            }
        }
    }
}
