import Foundation
import WidgetKit

/// The saved city list and home city, mirrored into the App Group so the widgets and
/// the Mac's menu bar label can show them. The SwiftData store stays where it is
/// (moving it into the group would need a migration); this is just a small copy the
/// app rewrites whenever either changes. Compiled into both the app and the widget.
enum SharedCities {
    struct City: Codable, Hashable {
        let id: String // ClockEntry.id, so renaming a city keeps widgets pointed at it
        let label: String
        let identifier: String
    }

    /// What the widgets measure offsets from, and the board widget's first row.
    struct Home: Codable, Hashable {
        let identifier: String
        let label: String
    }

    struct Snapshot: Codable, Hashable {
        var cities: [City]
        var home: Home
    }

    private static let key = "savedCities"
    private static let homeKey = "homeCity"

    private static var defaults: UserDefaults? {
        #if os(macOS)
        // macOS app groups are team-prefixed, which needs no provisioning profile (macOS 14
        // included), so the build stamps the prefixed ID into Info.plist. A fresh clone with
        // no team gets no shared group: the widget then just shows the Mac's own zone.
        (Bundle.main.object(forInfoDictionaryKey: "AppGroup") as? String).flatMap(UserDefaults.init(suiteName:))
        #else
        UserDefaults(suiteName: "group.org.surajshetty.worldclockapp")
        #endif
    }

    static func load() -> [City] {
        guard let data = defaults?.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([City].self, from: data)) ?? []
    }

    /// Before the app has saved one, the device's own zone.
    static func loadHome() -> Home {
        if let data = defaults?.data(forKey: homeKey), let home = try? JSONDecoder().decode(Home.self, from: data) {
            return home
        }
        let zone = TimeZone.current.identifier
        return Home(identifier: zone, label: ClockFormatting.displayLabel(for: zone))
    }

    /// Reloads widgets only on an actual change — this runs on every launch.
    static func save(_ snapshot: Snapshot) {
        guard let defaults, snapshot.cities != load() || snapshot.home != loadHome(),
              let cities = try? JSONEncoder().encode(snapshot.cities),
              let home = try? JSONEncoder().encode(snapshot.home) else { return }
        defaults.set(cities, forKey: key)
        defaults.set(home, forKey: homeKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension SharedCities.City {
    init(_ entry: ClockEntry) {
        self.init(id: entry.id.uuidString, label: entry.label, identifier: entry.timeZoneIdentifier)
    }
}

extension SharedCities.Snapshot {
    init(_ entries: [ClockEntry], homeIdentifier: String, homeLabel: String) {
        let zone = ClockFormatting.homeZone(homeIdentifier)
        self.init(cities: entries.map(SharedCities.City.init),
                  home: .init(identifier: zone.identifier, label: ClockFormatting.homeLabel(identifier: homeIdentifier, label: homeLabel)))
    }
}
