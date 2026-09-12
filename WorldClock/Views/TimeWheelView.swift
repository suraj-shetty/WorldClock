import SwiftUI

/// A tactile horizontal ruler: dragging slides the tape under a fixed center needle
/// (matches the Stitch reference's drag-translated tape, not a `ScrollView` picker,
/// since the needle must stay centered while ticks move past it). Reports the
/// scrubbed offset back via `offset`; the same view is mounted either as the global
/// bottom bar or inline inside a selected row — see ClockBoardView.
struct TimeWheelView: View {
    var anchorNow: Date
    var anchorTimeZone: TimeZone
    var use24Hour: Bool
    @Binding var offset: TimeInterval

    private let pixelsPerHour: CGFloat = 64

    @State private var dragStartOffset: TimeInterval?

    var body: some View {
        VStack(spacing: 6) {
            Text(shiftedLabel)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Theme.onSurfaceVariant)

            Canvas { context, size in
                drawTicks(context: &context, size: size)
            }
            .frame(height: 56)
            .overlay(needle)
            .contentShape(Rectangle())
            // `.gesture` alone loses to List's own pan/scroll recognizer when this view is
            // mounted inline inside a row (the global bottom-bar instance doesn't need this,
            // but sharing one modifier setup keeps the control identical in both places).
            .simultaneousGesture(dragGesture)
        }
    }

    private var needle: some View {
        VStack(spacing: 2) {
            Capsule().fill(Theme.primary).frame(width: 4, height: 6)
            Capsule().fill(Theme.primary).frame(width: 2, height: 36)
                .shadow(color: Theme.primary.opacity(0.8), radius: 6)
            Capsule().fill(Theme.primary).frame(width: 4, height: 6)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStartOffset == nil { dragStartOffset = offset }
                offset = (dragStartOffset ?? 0) - Double(value.translation.width / pixelsPerHour) * 3600
            }
            .onEnded { _ in dragStartOffset = nil }
    }

    private var displayedDate: Date { anchorNow.addingTimeInterval(offset) }

    private var shiftedLabel: String {
        let totalMinutes = Int((offset / 60).rounded())
        if abs(totalMinutes) < 1 { return "Now" }
        let hours = totalMinutes / 60
        let minutes = abs(totalMinutes % 60)
        let sign = hours >= 0 ? "+" : ""
        return minutes == 0 ? "Shifted by \(sign)\(hours)h" : "Shifted by \(sign)\(hours)h \(minutes)m"
    }

    private func drawTicks(context: inout GraphicsContext, size: CGSize) {
        let center = size.width / 2
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = anchorTimeZone
        let halfTickCount = Int(center / (pixelsPerHour / 2)) + 1

        for k in -halfTickCount...halfTickCount {
            let tickDate = displayedDate.addingTimeInterval(Double(k) * 1800)
            let x = center + CGFloat(k) * (pixelsPerHour / 2)
            let minute = calendar.component(.minute, from: tickDate)
            let isHour = minute == 0

            let tickRect = CGRect(x: x - (isHour ? 1 : 0.5), y: isHour ? 12 : 18, width: isHour ? 2 : 1, height: isHour ? 24 : 14)
            context.fill(Path(tickRect), with: .color(Theme.onSurfaceVariant.opacity(isHour ? 0.5 : 0.25)))

            if isHour {
                let hour = calendar.component(.hour, from: tickDate)
                context.draw(
                    Text(hourLabel(hour: hour))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Theme.onSurfaceVariant.opacity(0.7)),
                    at: CGPoint(x: x, y: 4)
                )
            }
        }
    }

    private func hourLabel(hour: Int) -> String {
        if use24Hour { return String(format: "%02d", hour) }
        let displayHour = hour % 12 == 0 ? 12 : hour % 12
        return "\(displayHour)\(hour < 12 ? "A" : "P")"
    }
}
