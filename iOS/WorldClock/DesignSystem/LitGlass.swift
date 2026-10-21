import SwiftUI

extension EnvironmentValues {
    /// Set once at the board's root, so every pane reads the same light (CLAUDE.md: one light source).
    @Entry var glassLight = GlassLight(hour: 18.5)
}

/// The canvas's `.wc-glass`: a blurred dark pane whose sheen, edge highlight and
/// long shadow all come from where the sun or moon is. Lower light throws longer,
/// softer shadows; daylight makes the pane a little more opaque so text keeps its contrast.
struct LitGlass<S: InsettableShape>: ViewModifier {
    @Environment(\.glassLight) private var light
    var shape: S

    func body(content: Content) -> some View {
        let s = light.strength, lc = Color(hex: light.hex)
        let lit = UnitPoint(x: 0.5 + 0.5 * light.dx, y: 0.5 + 0.5 * light.dy)
        let unlit = UnitPoint(x: 0.5 - 0.5 * light.dx, y: 0.5 - 0.5 * light.dy)
        let reach = (8 + 30 * (1 - light.altitude)) * (0.35 + 0.65 * s)
        let shade = Color(hex: 0x050610)
        content
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(Theme.glass.opacity(0.46 + 0.22 * light.sunUp))
                    shape.fill(LinearGradient(stops: [
                        .init(color: lc.opacity(0.03 + 0.11 * s), location: 0),
                        .init(color: .clear, location: 0.55),
                    ], startPoint: lit, endPoint: unlit))
                }
                .compositingGroup()
                .shadow(color: shade.opacity(0.35), radius: 1, y: 1)
                .shadow(color: shade.opacity(0.26 + 0.2 * s), radius: (22 + 26 * (1 - light.altitude)) / 2,
                        x: -light.dx * reach, y: max(4, -light.dy * reach))
            }
            .overlay {
                shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                shape.strokeBorder(LinearGradient(stops: [
                    .init(color: lc.opacity(0.3 + 0.55 * s), location: 0),
                    .init(color: .white.opacity(0.05), location: 0.38),
                    .init(color: .clear, location: 0.62),
                    .init(color: .white.opacity(0.07), location: 1),
                ], startPoint: lit, endPoint: unlit), lineWidth: 1)
            }
    }
}

extension View {
    func litGlass(_ shape: some InsettableShape) -> some View { modifier(LitGlass(shape: shape)) }

    /// The canvas's `.wc-lift`: text casts a faint shadow away from the light.
    func lifted() -> some View { modifier(Lift()) }
}

private struct Lift: ViewModifier {
    @Environment(\.glassLight) private var light
    func body(content: Content) -> some View {
        let s = light.strength
        content.shadow(color: Color(hex: 0x050610).opacity(0.45), radius: 5,
                       x: -light.dx * 2 * s, y: max(1, -light.dy * 2 * s + 1))
    }
}
