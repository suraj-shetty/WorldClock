import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Sky color keyframes
// Extracted from the Stitch "Atmospheric Horizon" exports (see design docs):
// - midnight / dawn / dusk stops come straight from the generated HTML's
//   `skyGradientBase` gradients (state1/state2/orbit-sunrise-dawn screens).
// - midday has no generated screen to sample, so it uses the "Solar Noon"
//   colors documented in the design-system spec instead.
// Validated in WorldClockBackground.playground before porting here.

private struct SkyKeyframe {
    let hour: Double
    let top: Color
    let mid: Color
    let bottom: Color
}

private let skyKeyframes: [SkyKeyframe] = [
    .init(hour: 0,  top: Color(hex: 0x050713), mid: Color(hex: 0x0d1226), bottom: Color(hex: 0x1c122e)), // midnight
    .init(hour: 6,  top: Color(hex: 0x0d1628), mid: Color(hex: 0x1a223a), bottom: Color(hex: 0x11131d)), // dawn
    .init(hour: 12, top: Color(hex: 0x0c4a6e), mid: Color(hex: 0x0284c7), bottom: Color(hex: 0x38bdf8)), // midday
    .init(hour: 18, top: Color(hex: 0x0a0f1d), mid: Color(hex: 0x151a30), bottom: Color(hex: 0x12131d)), // dusk / golden hour
    .init(hour: 24, top: Color(hex: 0x050713), mid: Color(hex: 0x0d1226), bottom: Color(hex: 0x1c122e))  // wraps to midnight
]

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

/// Continuous interpolation between the nearest two keyframes — no discrete jump between buckets.
func skyColors(forHour hour: Double) -> (top: Color, mid: Color, bottom: Color) {
    let raw = hour.truncatingRemainder(dividingBy: 24)
    let h = raw < 0 ? raw + 24 : raw
    let i = skyKeyframes.firstIndex { $0.hour > h } ?? 1
    let a = skyKeyframes[i - 1], b = skyKeyframes[i]
    let t = (h - a.hour) / (b.hour - a.hour)
    return (lerp(a.top, b.top, t), lerp(a.mid, b.mid, t), lerp(a.bottom, b.bottom, t))
}

// MARK: - Star field
// Fixed relative positions lifted from the Stitch night screen's starfield markup.

private struct Star { let x: Double; let y: Double; let size: Double; let phase: Double }

private let stars: [Star] = [
    .init(x: 0.10, y: 0.07, size: 2, phase: 0.0),
    .init(x: 0.25, y: 0.13, size: 3, phase: 0.7),
    .init(x: 0.58, y: 0.05, size: 2, phase: 1.4),
    .init(x: 0.84, y: 0.17, size: 2, phase: 2.0),
    .init(x: 0.44, y: 0.21, size: 3, phase: 0.3),
    .init(x: 0.14, y: 0.28, size: 2, phase: 1.8),
    .init(x: 0.72, y: 0.25, size: 1, phase: 0.9),
    .init(x: 0.46, y: 0.10, size: 2, phase: 2.5),
    .init(x: 0.88, y: 0.32, size: 2, phase: 1.1)
]

/// How "night-like" the sky is at this hour: 1 at midnight, 0 at midday.
func nightFactor(forHour hour: Double) -> Double {
    let h = hour.truncatingRemainder(dividingBy: 24)
    let distanceFromMidnight = min(h, 24 - h) // 0...12
    return 1 - min(distanceFromMidnight, 12) / 12
}

// MARK: - Animated background

/// Full-bleed sky background keyed to `hour` (0..<24, fractional, in whichever
/// timezone is the active anchor). Feed it `ClockBoardViewModel.activeAnchorHour(...)`.
struct BackgroundView: View {
    var hour: Double

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let sky = skyColors(forHour: hour)
                let gradient = Gradient(stops: [
                    .init(color: sky.top, location: 0),
                    .init(color: sky.mid, location: 0.5),
                    .init(color: sky.bottom, location: 1)
                ])
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(gradient, startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height))
                )

                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                drawStars(&context, size: size, elapsed: elapsed)
                drawCelestialBody(&context, size: size)
                drawClouds(&context, size: size, elapsed: elapsed)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.3), value: hour)
    }

    private func drawStars(_ context: inout GraphicsContext, size: CGSize, elapsed: TimeInterval) {
        let visibility = nightFactor(forHour: hour)
        guard visibility > 0.01 else { return }
        for star in stars {
            let twinkle = (sin(elapsed * 1.6 + star.phase) + 1) / 2 // 0...1
            context.opacity = visibility * (0.3 + 0.7 * twinkle)
            let point = CGPoint(x: star.x * size.width, y: star.y * size.height)
            let rect = CGRect(x: point.x - star.size / 2, y: point.y - star.size / 2, width: star.size, height: star.size)
            context.fill(Path(ellipseIn: rect), with: .color(.white))
        }
        context.opacity = 1
    }

    private func drawCelestialBody(_ context: inout GraphicsContext, size: CGSize) {
        let h = hour.truncatingRemainder(dividingBy: 24)
        let isDay = h >= 6 && h < 18
        let progress = isDay ? (h - 6) / 12 : (h < 6 ? (h + 6) / 12 : (h - 18) / 12)

        let x = progress * size.width
        let peakHeight = size.height * 0.18
        let baseline = size.height * 0.55
        let y = baseline - sin(progress * .pi) * (baseline - peakHeight)

        // Sized relative to the canvas (26pt tuned against a 390pt-wide iPhone) so the
        // sun/moon stay visually consistent on a much larger iPad or Mac window.
        let scale = min(size.width, size.height) / 390
        let radius: CGFloat = (isDay ? 26 : 20) * scale
        let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
        let color: Color = isDay ? Color(hex: 0xFFC07A) : Color(hex: 0xAAC7FF)

        context.drawLayer { ctx in
            ctx.addFilter(.blur(radius: radius * 0.6))
            ctx.opacity = 0.6
            ctx.fill(Path(ellipseIn: rect.insetBy(dx: -radius * 0.8, dy: -radius * 0.8)), with: .color(color))
        }
        context.fill(Path(ellipseIn: rect), with: .color(color))
    }

    private func drawClouds(_ context: inout GraphicsContext, size: CGSize, elapsed: TimeInterval) {
        let tint = nightFactor(forHour: hour) > 0.5 ? Color.white.opacity(0.08) : Color.white.opacity(0.18)
        let drift1 = (sin(elapsed * 0.05) + 1) / 2 * size.width
        let drift2 = (cos(elapsed * 0.04) + 1) / 2 * size.width
        let w1 = size.width * 0.56, h1 = size.height * 0.071
        let w2 = size.width * 0.67, h2 = size.height * 0.059

        context.drawLayer { ctx in
            ctx.addFilter(.blur(radius: 30 * min(size.width, size.height) / 390))
            ctx.fill(Path(ellipseIn: CGRect(x: drift1 - w1 / 2, y: size.height * 0.2, width: w1, height: h1)), with: .color(tint))
            ctx.fill(Path(ellipseIn: CGRect(x: drift2 - w2 / 2, y: size.height * 0.32, width: w2, height: h2)), with: .color(tint))
        }
    }
}
