import Foundation
import WidgetKit

/// The saved city list, mirrored into the App Group so the widget's city picker can
/// offer exactly the cities added in the app. The SwiftData store stays where it is
/// (moving it into the group would need a migration); this is just a small copy the
/// app rewrites whenever the list changes. Compiled into both the app and the widget.
enum SharedCities {
    struct City: Codable, Hashable {
        let id: String // ClockEntry.id, so renaming a city keeps widgets pointed at it
        let label: String
        let identifier: String
    }

    private static let key = "savedCities"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: "group.org.surajshetty.worldclockapp") }

    static func load() -> [City] {
        guard let data = defaults?.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([City].self, from: data)) ?? []
    }

    /// Reloads widgets only on an actual change — this runs on every launch.
    static func save(_ cities: [City]) {
        guard cities != load(), let data = try? JSONEncoder().encode(cities) else { return }
        defaults?.set(data, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension SharedCities.City {
    init(_ entry: ClockEntry) {
        self.init(id: entry.id.uuidString, label: entry.label, identifier: entry.timeZoneIdentifier)
    }
}
