import Foundation
import SwiftData
import Observation

/// Drives the board's single shared time offset and which "anchor" (device or one
/// selected row) that offset is measured against. Pure/testable: every method that
/// needs "now" takes it as a parameter instead of reading `Date.now` internally.
@Observable
final class ClockBoardViewModel {
    var selectedEntryID: PersistentIdentifier?
    var offset: TimeInterval = 0

    /// Tap a row: selecting it swaps the wheel's anchor to that row and hides the
    /// global wheel; tapping the already-selected row deselects and resets to "Now".
    func select(_ entry: ClockEntry) {
        if selectedEntryID == entry.id {
            deselect()
        } else {
            selectedEntryID = entry.id
            offset = 0
        }
    }

    func deselect() {
        selectedEntryID = nil
        offset = 0
    }

    func add(identifier: String, label: String, after entries: [ClockEntry], in context: ModelContext) {
        let sortOrder = (entries.map(\.sortOrder).max() ?? -1) + 1
        context.insert(ClockEntry(timeZoneIdentifier: identifier, label: label, sortOrder: sortOrder))
    }

    /// Deleting the *selected* entry used to leave `selectedEntryID` pointing at nothing,
    /// and the board keys "show the bottom wheel / grid" off "is something selected",
    /// not "does it still exist", so it got stuck. Deselect first.
    func delete(_ entry: ClockEntry, from context: ModelContext) {
        if selectedEntryID == entry.id { deselect() }
        context.delete(entry)
    }

    func displayDate(now: Date) -> Date {
        now.addingTimeInterval(offset)
    }

    /// The timezone the active wheel's tick labels are drawn in: the selected row's
    /// zone, or the device's own zone when nothing is selected.
    func anchorTimeZone(entries: [ClockEntry], deviceTimeZone: TimeZone = .current) -> TimeZone {
        guard let id = selectedEntryID, let entry = entries.first(where: { $0.id == id }) else {
            return deviceTimeZone
        }
        return entry.timeZone
    }

    /// Fractional hour-of-day (0..<24) in the active anchor's timezone, at `now + offset`.
    /// Feeds BackgroundView, which keys the sky/sun/stars off this single value.
    func activeAnchorHour(entries: [ClockEntry], now: Date, homeTimeZone: TimeZone = .current) -> Double {
        ClockFormatting.hourOfDay(in: anchorTimeZone(entries: entries, deviceTimeZone: homeTimeZone), at: displayDate(now: now))
    }
}
