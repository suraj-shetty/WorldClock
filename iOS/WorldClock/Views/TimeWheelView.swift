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
    @AppStorage("snapMinutes") private var snapMinutesSetting = 15
    @AppStorage("homeTimeZoneLabel") private var homeTimeZoneLabel = ""
    private var snapMinutes: TimeInterval { TimeInterval(snapMinutesSetting) }
    private let limit: TimeInterval = 48 * 3600

    @State private var dragStartOffset: TimeInterval?

    private var metrics: WheelMetrics { style == .bottom ? .bottom : .inline }
    private var canvasHeight: CGFloat { style == .bottom ? 56 : 52 }

    var body: some View {
        VStack(spacing: 8) {
            labelRow

            WheelCanvas(offset: offset, anchorNow: anchorNow, anchorTimeZone: anchorTimeZone,
                        use24Hour: use24Hour, metrics: metrics, pixelsPerMinute: pixelsPerMinute)
            .frame(height: canvasHeight)
            .contentShape(Rectangle())
            // `.gesture` alone loses to the row's own tap recognizer when this view is
            // mounted inline inside a row — `.simultaneousGesture` lets both fire.
            .simultaneousGesture(dragGesture)
            .mask(edgeFadeMask)
            .background {
                // Only the bottom-bar mount has its own glass chrome; inline sits in its row.
                if style == .bottom {
                    RoundedRectangle(cornerRadius: Theme.Radius.bottomWheel, style: .continuous)
                        .fill(Theme.glass.opacity(0.52))
                        .stroke(Theme.text.opacity(0.12), lineWidth: 1)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Time scrub wheel")
            .accessibilityValue(shiftedLabel)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: glide(to: min(offset + snapMinutes * 60, limit))
                case .decrement: glide(to: max(offset - snapMinutes * 60, -limit))
                @unknown default: break
                }
            }
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
            glide(to: 0)
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

    // Only shown for the bottom (home) wheel, where anchorTimeZone is always the home zone.
    private var homeLabel: String {
        ClockFormatting.homeLabel(identifier: anchorTimeZone.identifier, label: homeTimeZoneLabel)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStartOffset == nil {
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
                glide(to: min(max(snapped, -limit), limit))
            }
    }

    /// The ticks glide via WheelCanvas's `animatableData`; the labels and rows bound
    /// to `offset` update to the target straight away.
    private func glide(to target: TimeInterval) {
        withAnimation(.easeOut(duration: 0.5)) { offset = target }
    }

    private var shiftedLabel: String { TimeWheelView.shiftedLabel(forOffset: offset) }

    static func shiftedLabel(forOffset offset: TimeInterval) -> String {
        let totalMinutes = Int((offset / 60).rounded())
        if abs(totalMinutes) < 1 { return "Now" }
        let hours = totalMinutes / 60
        let minutes = abs(totalMinutes % 60)
        let sign = totalMinutes >= 0 ? "+" : ClockFormatting.minusSign
        let magnitude = abs(hours)
        return minutes == 0 ? "Shifted by \(sign)\(magnitude)h" : "Shifted by \(sign)\(magnitude)h \(minutes)m"
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

/// The tick tape. `Animatable` so `withAnimation { offset = ... }` eases the ticks
/// frame by frame — a Canvas has no interpolatable state of its own (same trick as
/// BackgroundView's layers).
private struct WheelCanvas: View, Animatable {
    var offset: TimeInterval
    let anchorNow: Date
    let anchorTimeZone: TimeZone
    let use24Hour: Bool
    let metrics: WheelMetrics
    let pixelsPerMinute: CGFloat

    var animatableData: TimeInterval {
        get { offset }
        set { offset = newValue }
    }

    var body: some View {
        Canvas { context, size in drawWheel(context: &context, size: size) }
    }

    private func drawWheel(context: inout GraphicsContext, size: CGSize) {
        let width = size.width, height = size.height
        let half = width / 2
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = anchorTimeZone
        let display = anchorNow.addingTimeInterval(offset)

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
}
