import Foundation
import SwiftData

@Model
final class ClockEntry {
    var id: UUID
    var timeZoneIdentifier: String
    var label: String
    var sortOrder: Int

    init(timeZoneIdentifier: String, label: String, sortOrder: Int) {
        self.id = UUID()
        self.timeZoneIdentifier = timeZoneIdentifier
        self.label = label
        self.sortOrder = sortOrder
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }
}
