import SwiftUI

/// A tactile horizontal ruler: dragging slides the tape under a fixed center caret
/// (matches the Nocturne reference's drag-translated tape, not a `ScrollView` picker,
/// since the caret must stay centered while ticks move past it). Reports the scrubbed
/// offset back via `offset`; the same view is mounted either as the global bottom bar
/// or inline inside a selected row — see ClockListView.
struct TimeWheelView: View {
    enum Style { case bottom, inline }

    var anchorNow: Date
    var anchorTimeZone: TimeZone
    var use24Hour: Bool
    var style: Style = .bottom
    @Binding var offset: TimeInterval

    private let pixelsPerMinute: CGFloat = 1.5
    private let snapMinutes: TimeInterval = 15
    private let limit: TimeInterval = 48 * 3600

    @State private var dragStartOffset: TimeInterval?
    // Drives the post-release deceleration by hand: the ticks are drawn directly
    // from `offset` inside a Canvas, which doesn't participate in SwiftUI's
    // `withAnimation` interpolation the way a Shape or `.offset()` modifier would
    // — a plain `withAnimation { offset = target }` would just jump. Stepping the
    // value ourselves guarantees every intermediate frame actually redraws.
    @State private var decelerationTask: Task<Void, Never>?

    private var metrics: WheelMetrics { style == .bottom ? .bottom : .inline }
    private var canvasHeight: CGFloat { style == .bottom ? 56 : 52 }

    var body: some View {
        VStack(spacing: 8) {
            labelRow

            Canvas { context, size in
                drawWheel(context: &context, size: size)
            }
            .frame(height: canvasHeight)
            .contentShape(Rectangle())
            // `.gesture` alone loses to the row's own tap recognizer when this view is
            // mounted inline inside a row — `.simultaneousGesture` lets both fire.
            .simultaneousGesture(dragGesture)
            .mask(edgeFadeMask)
            .modifier(WheelChrome(style: style))
        }
    }

    private var labelRow: some View {
        HStack(spacing: 8) {
            Text(shiftedLabel)
                .font(.system(size: 10.5, weight: .medium))
                .tracking(1.1)
                .foregroundStyle(Theme.accentText)
            Spacer(minLength: 8)
            if offset != 0 {
                nowButton
            } else if style == .bottom {
                Text("Ticks in \(homeLabel) time")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.text.opacity(0.5))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: offset == 0)
    }

    private var nowButton: some View {
        Button {
            // Reuses the same manual step-based easing as the drag-release
            // deceleration, not `withAnimation` — the Canvas ticks don't
            // interpolate through SwiftUI's animation system either way.
            decelerate(to: 0)
        } label: {
            Text("Now")
                .font(.system(size: 10, weight: .medium))
                .tracking(1)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.accentText)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule().stroke(Theme.accent, lineWidth: 1)
        )
        .transition(.opacity)
    }

    private var homeLabel: String {
        anchorTimeZone.identifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? anchorTimeZone.identifier
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStartOffset == nil {
                    decelerationTask?.cancel()
                    dragStartOffset = offset
                }
                let raw = (dragStartOffset ?? 0) - Double(value.translation.width / pixelsPerMinute) * 60
                offset = min(max(raw, -limit), limit)
            }
            .onEnded { value in
                let startOffset = dragStartOffset ?? offset
                let releaseOffset = offset
                dragStartOffset = nil
                // `predictedEndTranslation` is UIKit's own projection of where a natural
                // deceleration would coast to given the gesture's exit velocity — exactly
                // the "let go and it glides to a stop" target we want, with no manual
                // velocity tracking needed. It's calibrated for large-scale content
                // scrolling though, not this wheel's scale, so a fast flick can project
                // a wildly large distance — clamp how far it's allowed to coast *beyond*
                // where the finger actually let go.
                let rawTarget = startOffset - Double(value.predictedEndTranslation.width / pixelsPerMinute) * 60
                let maxGlide: TimeInterval = 6 * 3600
                let clampedGlide = min(max(rawTarget - releaseOffset, -maxGlide), maxGlide)
                let target = min(max(releaseOffset + clampedGlide, -limit), limit)
                let snapped = (target / snapMinutes / 60).rounded() * snapMinutes * 60
                decelerate(to: snapped)
            }
    }

    /// Eases `offset` from its current value to `target` over a fixed duration by
    /// manually stepping it several times a second (see the comment on
    /// `decelerationTask` for why this can't just be a `withAnimation`).
    private func decelerate(to target: TimeInterval) {
        decelerationTask?.cancel()
        let start = offset
        guard start != target else { return }
        let duration = 0.5
        let steps = 30
        decelerationTask = Task { @MainActor in
            for i in 1...steps {
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: UInt64(duration / Double(steps) * 1_000_000_000))
                if Task.isCancelled { return }
                let t = Double(i) / Double(steps)
                let eased = 1 - pow(1 - t, 3) // ease-out cubic: fast start, gentle stop
                offset = start + (target - start) * eased
            }
        }
    }

    private var displayedDate: Date { anchorNow.addingTimeInterval(offset) }

    private var shiftedLabel: String {
        let totalMinutes = Int((offset / 60).rounded())
        if abs(totalMinutes) < 1 { return "Now" }
        let hours = totalMinutes / 60
        let minutes = abs(totalMinutes % 60)
        let sign = hours >= 0 ? "+" : "\u{2212}"
        let magnitude = abs(hours)
        return minutes == 0 ? "Shifted by \(sign)\(magnitude)h" : "Shifted by \(sign)\(magnitude)h \(minutes)m"
    }

    private func drawWheel(context: inout GraphicsContext, size: CGSize) {
        let width = size.width, height = size.height
        let half = width / 2
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = anchorTimeZone
        let display = displayedDate

        let halfRangeMinutes = Double(half / pixelsPerMinute) + 25
        let halfRangeSeconds = halfRangeMinutes * 60
        let rangeStart = display.addingTimeInterval(-halfRangeSeconds)
        let rangeEnd = display.addingTimeInterval(halfRangeSeconds)
        // Snap the tick grid to real 5-minute clock boundaries (not `display + k*300`,
        // which would tie every tick's alignment to the live current second).
        let startEpoch = (rangeStart.timeIntervalSinceReferenceDate / 300).rounded(.down) * 300

        var tickDate = Date(timeIntervalSinceReferenceDate: startEpoch)
        while tickDate <= rangeEnd {
            let minutesFromCenter = tickDate.timeIntervalSince(display) / 60
            let x = half + CGFloat(minutesFromCenter) * pixelsPerMinute
            let d = abs(x - half)
            let near = max(0, 1 - d / 44)
            let minute = calendar.component(.minute, from: tickDate)
            let isHour = minute == 0
            let isHalf = isHour || minute == 30

            let tickHeight: CGFloat = isHour ? 26 : isHalf ? 16 : 9
            let baseOpacity = isHour ? 0.82 : isHalf ? 0.56 : 0.32
            let opacity = baseOpacity * (0.4 + 0.6 * max(0, 1 - d / half))
            let color = near > 0.4 ? Theme.accentLight : Theme.text
            let tickRect = CGRect(x: x - 0.75, y: height - metrics.ticksBottomInset - tickHeight, width: 1.5, height: tickHeight)
            context.fill(Path(roundedRect: tickRect, cornerRadius: 1), with: .color(color.opacity(opacity)))

            if isHalf {
                let hour = calendar.component(.hour, from: tickDate)
                context.draw(
                    Text(tickLabel(hour: hour, isHour: isHour))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.text.opacity(0.42 + 0.58 * near)),
                    at: CGPoint(x: x, y: height - metrics.labelsBottomInset - 6)
                )
            }

            tickDate = tickDate.addingTimeInterval(300)
        }

        let shiftMinutes = offset / 60
        let nowX = half - CGFloat(shiftMinutes) * pixelsPerMinute
        if offset != 0, nowX > 10, nowX < width - 10 {
            let nowRect = CGRect(x: nowX - 0.5, y: height - metrics.ticksBottomInset - 30, width: 1, height: 30)
            context.fill(Path(nowRect), with: .color(Theme.text.opacity(0.85 * 0.5)))
        }

        // Center caret: a glowing accent line plus a small downward-pointing triangle at its top.
        let caretRect = CGRect(x: half - 1, y: metrics.caretTopInset, width: 2, height: height - metrics.caretTopInset - metrics.caretBottomInset)
        context.drawLayer { ctx in
            ctx.addFilter(.shadow(color: Theme.accent.opacity(0.6), radius: 7))
            ctx.fill(Path(roundedRect: caretRect, cornerRadius: 1), with: .color(Theme.accent))
        }
        var triangle = Path()
        triangle.move(to: CGPoint(x: half - 4, y: metrics.triangleTopInset))
        triangle.addLine(to: CGPoint(x: half + 4, y: metrics.triangleTopInset))
        triangle.addLine(to: CGPoint(x: half, y: metrics.triangleTopInset + 5))
        triangle.closeSubpath()
        context.fill(triangle, with: .color(Theme.accent))
    }

    private func tickLabel(hour: Int, isHour: Bool) -> String {
        if use24Hour { return String(format: "%02d:%02d", hour, isHour ? 0 : 30) }
        let hour12 = ((hour + 11) % 12) + 1
        return isHour ? "\(hour12) \(hour < 12 ? "AM" : "PM")" : "\(hour12):30"
    }

    private var edgeFadeMask: some View {
        let inset = style == .bottom ? 0.10 : 0.11
        return LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: inset),
                .init(color: .black, location: 1 - inset),
                .init(color: .clear, location: 1),
            ],
            startPoint: .leading, endPoint: .trailing
        )
    }
}

private struct WheelMetrics {
    let ticksBottomInset: CGFloat
    let labelsBottomInset: CGFloat
    let caretTopInset: CGFloat
    let caretBottomInset: CGFloat
    let triangleTopInset: CGFloat

    static let bottom = WheelMetrics(ticksBottomInset: 21, labelsBottomInset: 2, caretTopInset: 5, caretBottomInset: 19, triangleTopInset: 1)
    static let inline = WheelMetrics(ticksBottomInset: 19, labelsBottomInset: 0, caretTopInset: 3, caretBottomInset: 17, triangleTopInset: 0)
}

/// Only the bottom-bar mount has its own chrome (rounded glass bar); the inline
/// mount sits directly in its row with no extra background/border.
private struct WheelChrome: ViewModifier {
    let style: TimeWheelView.Style

    func body(content: Content) -> some View {
        if style == .bottom {
            content
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.bottomWheel, style: .continuous)
                        .fill(Theme.glass.opacity(0.52))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.bottomWheel, style: .continuous)
                        .stroke(Theme.text.opacity(0.12), lineWidth: 1)
                )
        } else {
            content
        }
    }
}
