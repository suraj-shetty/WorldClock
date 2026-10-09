import AppIntents
import SwiftUI
import WidgetKit

// Home-screen widget: one city's time over the "Nocturne" sky for that city's hour.
// Long-press → Edit Widget picks the city; until then it shows the device's own zone.
//
// Keeping it fresh: WidgetKit never runs a widget's views live — it renders each
// timeline entry once, at that entry's date, and shows the snapshot. So instead of
// a timer, the provider hands over one entry per minute, and every entry is a
// fresh render, so the time label and the sky (sun/moon position, gradient)
// advance minute by minute. Entries don't count against the daily reload budget;
// reloads do. We ask for a reload every hour (24/day, well under the ~40-70 the
// system allows) but hand over 3 hours of entries, so if iOS delays or skips a
// reload (exhausted budget, Low Power Mode), the clock keeps ticking off the
// buffer instead of freezing on the last entry.

// MARK: - City picker

/// One of the cities saved in the app (see SharedCities) — the picker offers nothing else.
struct CityEntity: AppEntity {
    let id: String
    let label: String
    let identifier: String

    init(_ city: SharedCities.City) {
        id = city.id
        label = city.label
        identifier = city.identifier
    }

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "City"
    static let defaultQuery = CityQuery()

    var displayRepresentation: DisplayRepresentation {
        let country = ClockEntry.lookupCountry(for: identifier)
        return DisplayRepresentation(
            title: "\(country.map { "\($0.flag) " } ?? "")\(label)",
            subtitle: country.map { "\($0.name)" }
        )
    }
}

struct CityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [CityEntity] {
        SharedCities.load().filter { identifiers.contains($0.id) }.map(CityEntity.init)
    }

    func suggestedEntities() async throws -> [CityEntity] {
        SharedCities.load().map(CityEntity.init)
    }
}

struct SelectCityIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "City"
    static let description = IntentDescription("Pick the city this widget shows.")

    @Parameter(title: "City")
    var city: CityEntity?
}

// MARK: - Timeline

struct SkyEntry: TimelineEntry {
    let date: Date
    let label: String
    let zone: TimeZone
}

struct SkyProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SkyEntry { entry(at: .now, for: nil) }

    func snapshot(for configuration: SelectCityIntent, in context: Context) async -> SkyEntry {
        entry(at: .now, for: configuration.city)
    }

    func timeline(for configuration: SelectCityIntent, in context: Context) async -> Timeline<SkyEntry> {
        let start = Calendar.current.dateInterval(of: .minute, for: .now)!.start
        let entries = (0..<180).map { entry(at: start.addingTimeInterval(Double($0) * 60), for: configuration.city) }
        return Timeline(entries: entries, policy: .after(entries[60].date))
    }

    /// Re-reads the saved list so a city renamed in the app shows its new name. No city
    /// picked yet, or the picked one was deleted from the app → the device's own zone.
    private func entry(at date: Date, for city: CityEntity?) -> SkyEntry {
        let saved = city.flatMap { picked in SharedCities.load().first { $0.id == picked.id } }
        let identifier = saved?.identifier ?? TimeZone.current.identifier
        return SkyEntry(date: date,
                        label: saved?.label ?? ClockFormatting.displayLabel(for: identifier),
                        zone: TimeZone(identifier: identifier) ?? .current)
    }
}

// MARK: - View

struct SkyWidgetView: View {
    let entry: SkyEntry
    @Environment(\.widgetFamily) private var family

    // The app's 24h toggle lives in its own defaults, which the widget can't read
    // without an App Group, so follow the device's 12/24h setting instead.
    private var uses24Hour: Bool {
        !(DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? "").contains("a")
    }

    private var dateLine: String {
        var style = Date.FormatStyle.dateTime.weekday(.wide).day().month(.abbreviated)
        style.timeZone = entry.zone
        return entry.date.formatted(style)
    }

    var body: some View {
        let time = ClockFormatting.timeComponents(at: entry.date, in: entry.zone, use24Hour: uses24Hour)
        let small = family == .systemSmall

        VStack(alignment: .leading, spacing: small ? 2 : 4) {
            HStack(spacing: 6) {
                if let flag = ClockEntry.lookupCountry(for: entry.zone.identifier)?.flag {
                    Text(flag)
                }
                Text(entry.label).lineLimit(1)
            }
            .font(.system(size: small ? 13 : 15, weight: .semibold))

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(time.main).font(.system(size: small ? 36 : 44, weight: .bold))
                if !time.period.isEmpty {
                    Text(time.period).font(.system(size: small ? 14 : 17, weight: .bold))
                }
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)

            Text(dateLine)
                .font(.system(size: small ? 12 : 14))
                .opacity(0.75)
                .lineLimit(1)
        }
        .foregroundStyle(Theme.textBright)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            BackgroundView(hour: ClockFormatting.hourOfDay(in: entry.zone, at: entry.date))
        }
    }
}

@main
struct WorldClockWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "WorldClockSky", intent: SelectCityIntent.self, provider: SkyProvider()) {
            SkyWidgetView(entry: $0)
        }
        .configurationDisplayName("City Sky")
        .description("One of your cities, over its local sky. Edit the widget to pick which.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
