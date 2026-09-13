import SwiftUI
import SwiftData

/// Shared by both the row's inline wheel and the global bottom bar so their
/// show/hide always animates in lockstep — one constant, not two modifiers that
/// happen to currently agree.
private let wheelTransitionAnimation: Animation = .easeInOut(duration: 0.3)

/// The main board: animated background, timezone list, and the time wheel — mounted
/// either as a bottom bar (nothing selected) or inline inside the selected row.
struct ClockListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClockEntry.sortOrder) private var entries: [ClockEntry]
    @State private var viewModel = ClockBoardViewModel()
    @State private var showingAddSheet = false
    @State private var showingSettings = false
    @AppStorage("use24Hour") private var use24Hour = false
    @AppStorage("showCountryName") private var showCountryName = true
    @AppStorage("animateSky") private var animateSky = true
    @AppStorage("flagNextDayCities") private var flagNextDayCities = false
    @AppStorage("homeTimeZoneIdentifier") private var homeTimeZoneIdentifier = ""

    private var homeTimeZone: TimeZone {
        homeTimeZoneIdentifier.isEmpty ? .current : (TimeZone(identifier: homeTimeZoneIdentifier) ?? .current)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let now = timeline.date
            // "Animate the sky" off means the illustration always reflects the real
            // current moment at home, ignoring the wheel's scrub offset/selection —
            // everything else (rows, wheel) still scrubs normally.
            let skyHour = animateSky
                ? viewModel.activeAnchorHour(entries: entries, now: now, homeTimeZone: homeTimeZone)
                : ClockBoardViewModel.hourOfDay(in: homeTimeZone, at: now)

            ZStack(alignment: .bottom) {
                BackgroundView(hour: skyHour)

                // Top scrim so the header text stays legible over a bright sky.
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: 0x0e101b).opacity(0.82), location: 0),
                        .init(color: Color(hex: 0x0e101b).opacity(0.55), location: 0.45),
                        .init(color: Color(hex: 0x0e101b).opacity(0.18), location: 0.78),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 230)
                .frame(maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    header

                    // A plain ScrollView + LazyVStack, not List: List is backed by
                    // UITableView, which recomputes self-sizing row heights in its own
                    // layout pass outside SwiftUI's animation transaction — no combination
                    // of .transition/.animation on the row's content can make THAT smooth,
                    // which is why the row kept visibly jumping no matter how the wheel's
                    // own appearance was animated. Plain SwiftUI layout has no such
                    // disconnect. LazyVStack keeps List's other benefit — off-screen rows
                    // aren't instantiated — without its row-resize behavior.
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(entries) { entry in
                                ClockRow(
                                    entry: entry, now: now, use24Hour: use24Hour,
                                    showCountryName: showCountryName, flagNextDayCities: flagNextDayCities,
                                    homeTimeZone: homeTimeZone,
                                    onDelete: { modelContext.delete(entry) },
                                    viewModel: viewModel
                                )
                                    // A swipe-to-delete action would install a horizontal drag
                                    // recognizer on the row that fights the wheel's own horizontal
                                    // drag when this row is expanded — long-press works from a
                                    // collapsed row; the visible "Delete City" button covers the
                                    // expanded state where the wheel is already using that drag.
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            modelContext.delete(entry)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.base)
                        .padding(.vertical, 6)
                    }
                    // The scroll view's own pan recognizer competes with the inline wheel's
                    // horizontal drag even with `.simultaneousGesture` — disabling scroll
                    // while a row is selected removes that conflict. Only one row's wheel is
                    // ever interactive at a time, so this doesn't block anything else.
                    .scrollDisabled(viewModel.selectedEntryID != nil)

                    // Selecting a row wraps the mutation in `withAnimation` (see the
                    // Button action in ClockRow below) using this same animation, so
                    // this bar's fade-out and the row's inline wheel fading in happen
                    // as one synchronized transaction, not two independently-timed ones.
                    if viewModel.selectedEntryID == nil {
                        TimeWheelView(
                            anchorNow: now,
                            anchorTimeZone: homeTimeZone,
                            use24Hour: use24Hour,
                            style: .bottom,
                            offset: $viewModel.offset
                        )
                        .padding(.horizontal, Theme.Spacing.base)
                        .padding(.top, 22)
                        .padding(.bottom, Theme.Spacing.base)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddTimeZoneView { identifier, label in
                addEntry(identifier: identifier, label: label)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    private var homeKicker: String {
        let name = homeTimeZone.identifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? homeTimeZone.identifier
        return "\(name.uppercased()) · YOUR TIME"
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(homeKicker)
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.5)
                    .foregroundStyle(Theme.text.opacity(0.62))
                Text("World Clock")
                    .font(.system(size: 29, weight: .medium))
                    .tracking(-0.5)
                    .foregroundStyle(Theme.text)
            }
            Spacer()
            HStack(spacing: 10) {
                headerButton(systemImage: "gearshape") { showingSettings = true }
                headerButton(systemImage: "plus") { showingAddSheet = true }
            }
        }
        .padding(.horizontal, Theme.Spacing.base)
        .padding(.top, 62)
        .padding(.bottom, 20)
    }

    private func headerButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.accentText)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Theme.glass.opacity(0.5)))
                .overlay(Circle().stroke(Theme.accent, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func addEntry(identifier: String, label: String) {
        let sortOrder = (entries.map(\.sortOrder).max() ?? -1) + 1
        modelContext.insert(ClockEntry(timeZoneIdentifier: identifier, label: label, sortOrder: sortOrder))
    }
}

private struct ClockRow: View {
    var entry: ClockEntry
    var now: Date
    var use24Hour: Bool
    var showCountryName: Bool
    var flagNextDayCities: Bool
    var homeTimeZone: TimeZone
    var onDelete: () -> Void
    @Bindable var viewModel: ClockBoardViewModel

    private var isSelected: Bool { viewModel.selectedEntryID == entry.id }
    private var displayedDate: Date { now.addingTimeInterval(viewModel.offset) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(wheelTransitionAnimation) {
                    viewModel.select(entry)
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: isSelected ? 4 : 3) {
                        HStack(spacing: 7) {
                            if isSelected {
                                Circle()
                                    .fill(Theme.accent)
                                    .frame(width: 5, height: 5)
                                    .shadow(color: Theme.accent.opacity(0.7), radius: 4)
                            }
                            Text(entry.label)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .tracking(-0.19)
                                .foregroundStyle(isSelected ? Theme.textBright : Theme.text)
                                .lineLimit(1)
                        }
                        Text(subtitle)
                            .font(.system(size: 14, weight: .medium))
                            .tracking(0.23)
                            .foregroundStyle(Theme.text.opacity(isSelected ? 0.62 : 0.6))
                            .monospacedDigit()
                    }
                    Spacer(minLength: 8)
                    (
                        Text(timeComponents.main)
                            .font(.system(size: isSelected ? 41 : 33, weight: .medium))
                        + Text(timeComponents.period.isEmpty ? "" : " " + timeComponents.period)
                            .font(.system(size: isSelected ? 13 : 12, weight: .medium))
                    )
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? Theme.textBrightest : Theme.textBright)
                    // Digits roll like an odometer instead of cross-fading/snapping —
                    // reads far more naturally for a clock face, especially while
                    // scrubbing the wheel where the value changes continuously.
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.35), value: timeComponents.main)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isSelected {
                Rectangle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: Theme.accent.opacity(0.55), location: 0.18),
                                .init(color: Theme.accent.opacity(0.55), location: 0.82),
                                .init(color: .clear, location: 1),
                            ],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .padding(.top, 13)
                    .padding(.bottom, 9)

                TimeWheelView(
                    anchorNow: now,
                    anchorTimeZone: entry.timeZone,
                    use24Hour: use24Hour,
                    style: .inline,
                    offset: $viewModel.offset
                )
                // Fades in/out in place rather than sliding or scaling — combined with
                // top-aligning the row below, the button/time text never shifts; only
                // the space beneath it grows or shrinks.
                .transition(.opacity)

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete City", systemImage: "trash")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(hex: 0xff8a80))
                .padding(.top, 14)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.horizontal, 15)
        .padding(.top, isSelected ? 15 : 14)
        .padding(.bottom, isSelected ? 11 : 14)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                .fill(isSelected ? Theme.glassExpanded.opacity(0.74) : Theme.glass.opacity(0.48))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                .stroke(isSelected ? Theme.accent : Theme.text.opacity(0.13), lineWidth: 1)
        )
        .shadow(color: isSelected ? Theme.accent.opacity(0.18) : .clear, radius: 24)
        // Keeps the expanding/collapsing wheel confined to the card's rounded bounds
        // instead of momentarily poking past its corners mid-transition.
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
        .animation(wheelTransitionAnimation, value: isSelected)
    }

    /// Split so the "AM"/"PM" suffix can render smaller than the digits (empty in 24h mode).
    private var timeComponents: (main: String, period: String) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = entry.timeZone
        let comps = calendar.dateComponents([.hour, .minute], from: displayedDate)
        let hour = comps.hour ?? 0, minute = comps.minute ?? 0
        if use24Hour { return (String(format: "%02d:%02d", hour, minute), "") }
        let displayHour = hour % 12 == 0 ? 12 : hour % 12
        return (String(format: "%d:%02d", displayHour, minute), hour < 12 ? "AM" : "PM")
    }

    private var deltaLabel: String {
        let homeOffset = homeTimeZone.secondsFromGMT(for: displayedDate)
        let entryOffset = entry.timeZone.secondsFromGMT(for: displayedDate)
        let diffMinutes = (entryOffset - homeOffset) / 60
        if diffMinutes == 0 { return "Home" }
        let sign = diffMinutes > 0 ? "+" : "\u{2212}"
        let magnitude = abs(diffMinutes)
        let hours = magnitude / 60, minutes = magnitude % 60
        return minutes == 0 ? "\(sign)\(hours)h" : "\(sign)\(hours).\(minutes * 10 / 60)h"
    }

    /// True when the entry's local calendar date (at the displayed moment) is a day
    /// ahead of home's — e.g. it's still today at home but already tomorrow there.
    private var isNextDay: Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = homeTimeZone
        let homeDay = calendar.startOfDay(for: displayedDate)
        calendar.timeZone = entry.timeZone
        let entryDay = calendar.startOfDay(for: displayedDate)
        return entryDay > homeDay
    }

    private var subtitle: String {
        var parts: [String] = []
        if showCountryName, let country = entry.country {
            parts.append("\(country.flag) \(country.name)")
        }
        parts.append(deltaLabel)
        if flagNextDayCities && isNextDay {
            parts.append("Next day")
        }
        return parts.joined(separator: " · ")
    }
}
