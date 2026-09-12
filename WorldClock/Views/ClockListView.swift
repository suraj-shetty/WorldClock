import SwiftUI
import SwiftData

/// The main board: animated background, timezone list, and the time wheel — mounted
/// either as a bottom bar (nothing selected) or inline inside the selected row.
struct ClockListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClockEntry.sortOrder) private var entries: [ClockEntry]
    @State private var viewModel = ClockBoardViewModel()
    @State private var showingAddSheet = false
    @State private var showingSettings = false
    @AppStorage("use24Hour") private var use24Hour = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let now = timeline.date

            ZStack(alignment: .bottom) {
                BackgroundView(hour: viewModel.activeAnchorHour(entries: entries, now: now))

                VStack(spacing: 0) {
                    header

                    List {
                        ForEach(entries) { entry in
                            ClockRow(entry: entry, now: now, use24Hour: use24Hour, viewModel: viewModel)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                // A swipe-to-delete action would install a horizontal drag
                                // recognizer on the row that fights the wheel's own horizontal
                                // drag when this row is expanded — long-press avoids the conflict.
                                .contextMenu {
                                    Button(role: .destructive) {
                                        modelContext.delete(entry)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)
                    // List's own UIScrollView pan recognizer competes with the inline
                    // wheel's horizontal drag even with `.simultaneousGesture` — disabling
                    // scroll while a row is selected removes that conflict. Only one row's
                    // wheel is ever interactive at a time, so this doesn't block anything
                    // the user would otherwise be doing.
                    .scrollDisabled(viewModel.selectedEntryID != nil)

                    // Always present (never structurally inserted/removed) so its
                    // appearance/disappearance is a genuine animatable height change
                    // instead of a List-adjacent layout snap — see ClockRow's identical
                    // treatment below for why the `if` version visibly jumped.
                    TimeWheelView(
                        anchorNow: now,
                        anchorTimeZone: .current,
                        use24Hour: use24Hour,
                        offset: $viewModel.offset
                    )
                    .padding(.horizontal, Theme.Spacing.base)
                    .padding(.bottom, Theme.Spacing.base)
                    .frame(height: viewModel.selectedEntryID == nil ? 94 : 0, alignment: .top)
                    .opacity(viewModel.selectedEntryID == nil ? 1 : 0)
                    .clipped()
                    .allowsHitTesting(viewModel.selectedEntryID == nil)
                    .animation(.easeInOut(duration: 0.25), value: viewModel.selectedEntryID)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddTimeZoneView { identifier, label in
                addEntry(identifier: identifier, label: label)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(use24Hour: $use24Hour)
        }
    }

    private var header: some View {
        HStack {
            Text("World Clock")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.onSurface)
            Spacer()
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape")
            }
            Button { showingAddSheet = true } label: {
                Image(systemName: "plus")
            }
        }
        .tint(Theme.primary)
        .padding(.horizontal, Theme.Spacing.base)
        .padding(.top, Theme.Spacing.base)
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
    @Bindable var viewModel: ClockBoardViewModel

    private var isSelected: Bool { viewModel.selectedEntryID == entry.id }
    private var displayedDate: Date { now.addingTimeInterval(viewModel.offset) }

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Button {
                viewModel.select(entry)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.label)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Theme.onSurface)
                        Text(deltaLabel)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Theme.onSurfaceVariant)
                    }
                    Spacer()
                    Text(timeString)
                        .font(.system(size: 32, weight: .light))
                        .monospacedDigit()
                        .foregroundStyle(Theme.onSurface)
                        // Digits roll like an odometer instead of cross-fading/snapping —
                        // reads far more naturally for a clock face, especially while
                        // scrubbing the wheel where the value changes continuously.
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.35), value: timeString)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Always present (never structurally inserted/removed) — SwiftUI can only
            // animate this smoothly as a continuous height/opacity change; toggling it
            // in and out of the view tree with `if` made every row below snap into its
            // new position instead of sliding.
            TimeWheelView(
                anchorNow: now,
                anchorTimeZone: entry.timeZone,
                use24Hour: use24Hour,
                offset: $viewModel.offset
            )
            .frame(height: isSelected ? 78 : 0, alignment: .top)
            .opacity(isSelected ? 1 : 0)
            .clipped()
            .allowsHitTesting(isSelected)
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.surfaceContainer.opacity(isSelected ? 0.85 : 0.6))
        )
        .animation(.easeInOut(duration: 0.25), value: isSelected)
    }

    private var timeString: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = entry.timeZone
        let comps = calendar.dateComponents([.hour, .minute], from: displayedDate)
        let hour = comps.hour ?? 0, minute = comps.minute ?? 0
        if use24Hour { return String(format: "%02d:%02d", hour, minute) }
        let displayHour = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d %@", displayHour, minute, hour < 12 ? "AM" : "PM")
    }

    private var deltaLabel: String {
        let deviceOffset = TimeZone.current.secondsFromGMT(for: displayedDate)
        let entryOffset = entry.timeZone.secondsFromGMT(for: displayedDate)
        let diffHours = (entryOffset - deviceOffset) / 3600
        if diffHours == 0 { return "Same time" }
        return diffHours > 0 ? "+\(diffHours)h" : "\(diffHours)h"
    }
}
