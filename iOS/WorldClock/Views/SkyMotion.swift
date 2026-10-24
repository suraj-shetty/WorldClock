import SwiftUI
import QuartzCore

/// The sky's moving parts (twinkling stars, swaying rays, shimmering glints) as Core
/// Animation layers, built once per sky step and then animated by the render server.
/// Driving them from a SwiftUI timeline re-rendered the whole window ten times a
/// second: 24% CPU at rest on a Mac, against 0.3% when nothing ticked.
struct SkyMotion: View {
    enum Part { case below, glints }
    let light: SkyLight
    let part: Part

    var body: some View {
        MotionLayers(light: light, part: part)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

#if os(macOS)
private typealias PlatformView = NSView
private typealias Representable = NSViewRepresentable
#else
private typealias PlatformView = UIView
private typealias Representable = UIViewRepresentable
#endif

private struct MotionLayers: Representable {
    let light: SkyLight
    let part: SkyMotion.Part

    #if os(macOS)
    func makeNSView(context: Context) -> MotionView { MotionView(light: light, part: part) }
    func updateNSView(_ view: MotionView, context: Context) {}
    #else
    func makeUIView(context: Context) -> MotionView { MotionView(light: light, part: part) }
    func updateUIView(_ view: MotionView, context: Context) {}
    #endif
}

private final class MotionView: PlatformView {
    private let light: SkyLight
    private let part: SkyMotion.Part
    private let root = CALayer()
    private var builtSize: CGSize = .zero

    init(light: SkyLight, part: SkyMotion.Part) {
        self.light = light
        self.part = part
        super.init(frame: .zero)
        #if os(macOS)
        wantsLayer = true
        layer?.addSublayer(root)
        // Top-left origin, like the SwiftUI drawing the geometry comes from.
        root.isGeometryFlipped = true
        #else
        isUserInteractionEnabled = false
        layer.addSublayer(root)
        #endif
    }

    required init?(coder: NSCoder) { nil }

    #if os(macOS)
    override func layout() {
        super.layout()
        rebuildIfResized()
    }
    #else
    override func layoutSubviews() {
        super.layoutSubviews()
        rebuildIfResized()
    }
    #endif

    private func rebuildIfResized() {
        let size = bounds.size
        guard size != builtSize, size.width > 0, size.height > 0 else { return }
        builtSize = size
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        root.frame = CGRect(origin: .zero, size: size)
        root.sublayers = nil
        let sky = SkyRenderer(light, size: size)
        switch part {
        case .below:
            let stars = group(sky.stars.map(shape))
            stars.opacity = Float(sky.starOpacity)
            root.addSublayer(stars)
            if let fan = sky.rayFan { root.addSublayer(rays(fan, in: size)) }
        case .glints:
            let glints = group(sky.glints.map(shape))
            glints.compositingFilter = "screenBlendMode"
            root.addSublayer(glints)
        }
        CATransaction.commit()
    }

    private func group(_ layers: [CALayer]) -> CALayer {
        let g = CALayer()
        g.frame = root.bounds
        layers.forEach(g.addSublayer)
        return g
    }

    private func shape(_ twinkle: Twinkle) -> CALayer {
        let layer = CAShapeLayer()
        layer.path = twinkle.path.cgPath
        layer.fillColor = twinkle.color.cgColor
        animate(layer, twinkle)
        return layer
    }

    /// The canvas's `values="o;o·lo;o"`: down and back once per duration, phased by `begin`.
    private func animate(_ layer: CALayer, _ twinkle: Twinkle) {
        layer.opacity = Float(twinkle.opacity)
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = twinkle.opacity
        fade.toValue = twinkle.opacity * twinkle.low
        fade.duration = twinkle.duration / 2
        fade.autoreverses = true
        fade.repeatCount = .infinity
        fade.timingFunction = CAMediaTimingFunction(name: .linear)
        fade.timeOffset = ((-twinkle.begin).truncatingRemainder(dividingBy: twinkle.duration) + twinkle.duration)
            .truncatingRemainder(dividingBy: twinkle.duration)
        fade.isRemovedOnCompletion = false
        layer.add(fade, forKey: "twinkle")
    }

    /// One radial gradient, masked by every ray. Each ray in the mask twinkles on its own,
    /// and a shadow on each softens its edges where the canvas blurs them.
    private func rays(_ fan: RayFan, in size: CGSize) -> CALayer {
        let sway = CALayer()
        sway.position = fan.center
        sway.bounds = .zero
        sway.opacity = Float(fan.opacity)
        sway.compositingFilter = "screenBlendMode"

        let r = fan.radius
        let gradient = CAGradientLayer()
        gradient.type = .radial
        gradient.frame = CGRect(x: -r, y: -r, width: r * 2, height: r * 2)
        gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.colors = fan.stops.map { $0.0.cgColor(alpha: $0.1) }
        gradient.locations = fan.stops.map { NSNumber(value: $0.2) }

        let mask = CALayer()
        mask.frame = gradient.bounds
        for ray in fan.rays {
            let shape = CAShapeLayer()
            shape.path = ray.path.cgPath
            shape.position = CGPoint(x: r, y: r)
            shape.fillColor = CGColor(gray: 0, alpha: 1)
            shape.shadowColor = CGColor(gray: 0, alpha: 1)
            shape.shadowOpacity = 1
            shape.shadowOffset = .zero
            shape.shadowRadius = fan.blur
            animate(shape, ray)
            mask.addSublayer(shape)
        }
        gradient.mask = mask
        sway.addSublayer(gradient)

        let swing = CABasicAnimation(keyPath: "transform.rotation.z")
        swing.fromValue = -1.5 * Double.pi / 180
        swing.toValue = 1.5 * Double.pi / 180
        swing.duration = 23.5
        swing.autoreverses = true
        swing.repeatCount = .infinity
        swing.timingFunction = CAMediaTimingFunction(name: .linear)
        swing.isRemovedOnCompletion = false
        sway.add(swing, forKey: "sway")
        return sway
    }
}

private extension RGB {
    var cgColor: CGColor { cgColor(alpha: 1) }
    func cgColor(alpha: Double) -> CGColor {
        CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: alpha)
    }
}
