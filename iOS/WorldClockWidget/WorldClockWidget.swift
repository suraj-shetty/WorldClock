import AppIntents
import SwiftUI
import WidgetKit

// Widgets, built to the canvas's Widgets board: Small and Medium show one city over its
// sky (Edit Widget picks the city; until then, the device's own zone), and the board
// widget lists home and every saved city.
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
    let home: SharedCities.Home
}

/// One entry per minute for 3 hours, reloading hourly: see the note at the top.
private func minuteDates() -> [Date] {
    let start = Calendar.current.dateInterval(of: .minute, for: .now)!.start
    return (0..<180).map { start.addingTimeInterval(Double($0) * 60) }
}

struct SkyProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SkyEntry { entry(at: .now, for: nil) }

    func snapshot(for configuration: SelectCityIntent, in context: Context) async -> SkyEntry {
        entry(at: .now, for: configuration.city)
    }

    func timeline(for configuration: SelectCityIntent, in context: Context) async -> Timeline<SkyEntry> {
        let entries = minuteDates().map { entry(at: $0, for: configuration.city) }
        return Timeline(entries: entries, policy: .after(entries[60].date))
    }

    /// Re-reads the saved list so a city renamed in the app shows its new name. No city
    /// picked yet, or the picked one was deleted from the app → the device's own zone.
    private func entry(at date: Date, for city: CityEntity?) -> SkyEntry {
        let saved = city.flatMap { picked in SharedCities.load().first { $0.id == picked.id } }
        let identifier = saved?.identifier ?? TimeZone.current.identifier
        return SkyEntry(date: date,
                        label: saved?.label ?? ClockFormatting.displayLabel(for: identifier),
                        zone: TimeZone(identifier: identifier) ?? .current,
                        home: SharedCities.loadHome())
    }
}

struct BoardEntry: TimelineEntry {
    let date: Date
    let home: SharedCities.Home
    let cities: [SharedCities.City]
}

struct BoardProvider: TimelineProvider {
    func placeholder(in context: Context) -> BoardEntry { entry(at: .now) }
    func getSnapshot(in context: Context, completion: @escaping (BoardEntry) -> Void) { completion(entry(at: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<BoardEntry>) -> Void) {
        let entries = minuteDates().map(entry(at:))
        completion(Timeline(entries: entries, policy: .after(entries[60].date)))
    }

    private func entry(at date: Date) -> BoardEntry {
        BoardEntry(date: date, home: SharedCities.loadHome(), cities: SharedCities.load())
    }
}

// MARK: - Views

// The app's 24h toggle lives in its own defaults, which the widget can't read, so
// follow the device's 12/24h setting instead.
private var uses24Hour: Bool {
    !(DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? "").contains("a")
}

private extension View {
    /// The canvas's text shadow over the sky.
    func overSky(_ opacity: Double = 0.7, radius: CGFloat = 4) -> some View {
        shadow(color: Color(hex: 0x090b18).opacity(opacity), radius: radius, y: 1)
    }
}

/// A time with its smaller AM/PM, in the canvas's sizes.
private struct TimeText: View {
    let date: Date
    let zone: TimeZone
    let size: CGFloat
    let periodSize: CGFloat
    var body: some View {
        let time = ClockFormatting.timeComponents(at: date, in: zone, use24Hour: uses24Hour)
        HStack(alignment: .firstTextBaseline, spacing: size > 30 ? 4 : 3) {
            Text(time.main).font(.system(size: size, weight: .medium))
            if !time.period.isEmpty {
                Text(time.period).font(.system(size: periodSize)).opacity(0.8)
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

struct SkyWidgetView: View {
    let entry: SkyEntry
    @Environment(\.widgetFamily) private var family

    private var offset: String {
        let home = TimeZone(identifier: entry.home.identifier) ?? .current
        return ClockFormatting.offsetLabel(homeOffsetSeconds: home.secondsFromGMT(for: entry.date),
                                           zoneOffsetSeconds: entry.zone.secondsFromGMT(for: entry.date))
    }

    var body: some View {
        Group {
            if family == .systemSmall { small } else { medium }
        }
        .foregroundStyle(Theme.textBrightest)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            BackgroundView(hour: ClockFormatting.hourOfDay(in: entry.zone, at: entry.date), animated: false)
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(entry.label).font(.system(size: 13, weight: .semibold)).lineLimit(1)
            TimeText(date: entry.date, zone: entry.zone, size: 30, periodSize: 12)
            Text(offset).font(.system(size: 11)).monospacedDigit().foregroundStyle(Theme.textBright.opacity(0.8))
        }
        .overSky()
        .padding(.leading, 14)
        .padding(.top, 12)
    }

    private var medium: some View {
        let country = ClockEntry.lookupCountry(for: entry.zone.identifier)?.name
        var weekday = Date.FormatStyle().weekday(.wide)
        weekday.timeZone = entry.zone
        let away = offset == "Home" ? "Home" : "\(offset) from \(entry.home.label)"
        return VStack(alignment: .leading, spacing: 0) {
            Text([entry.label, country].compactMap { $0 }.joined(separator: " · "))
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.88)
                .textCase(.uppercase)
                .foregroundStyle(Theme.textBright)
                .lineLimit(1)
                .overSky(0.6)
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 4) {
                TimeText(date: entry.date, zone: entry.zone, size: 40, periodSize: 14)
                Text("\(entry.date.formatted(weekday)) · \(away)")
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textBright.opacity(0.85))
                    .lineLimit(1)
            }
            .overSky(0.65, radius: 5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

/// The board at a glance (canvas "Tall"): home, then every city, each with a sun or moon
/// dot for whether it's day there. WidgetKit has no tall-and-narrow size, so this is the
/// large size, about twice the canvas's width, so it goes to two columns past four rows.
struct BoardWidgetView: View {
    let entry: BoardEntry

    var body: some View {
        let rows = [(entry.home.label, entry.home.identifier)] + entry.cities.map { ($0.label, $0.identifier) }
        let columns = rows.count > 4 ? 2 : 1
        VStack(alignment: .leading, spacing: 0) {
            Text("World Clock")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.88)
                .textCase(.uppercase)
                .foregroundStyle(Theme.accentLight)
                .padding(.bottom, 8)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16, alignment: .top), count: columns), spacing: 0) {
                ForEach(Array(rows.prefix(columns * 6).enumerated()), id: \.offset) { _, row in
                    let zone = TimeZone(identifier: row.1) ?? .current
                    let day = (6.0...18.0).contains(ClockFormatting.hourOfDay(in: zone, at: entry.date))
                    VStack(alignment: .leading, spacing: 0) {
                        Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
                        HStack(spacing: 6) {
                            Circle().fill(day ? Color(hex: 0xf6d9b4) : Theme.accent).frame(width: 8, height: 8)
                            Text(row.0).font(.system(size: 12)).foregroundStyle(Theme.text).lineLimit(1)
                        }
                        .padding(.top, 7)
                        TimeText(date: entry.date, zone: zone, size: 20, periodSize: 10)
                            .foregroundStyle(Theme.textBrightest)
                            .padding(.bottom, 7)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { Theme.glass }
    }
}

struct CitySkyWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "WorldClockSky", intent: SelectCityIntent.self, provider: SkyProvider()) {
            SkyWidgetView(entry: $0)
        }
        .configurationDisplayName("City Sky")
        .description("One of your cities, over its local sky. Edit the widget to pick which.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct BoardWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WorldClockBoard", provider: BoardProvider()) {
            BoardWidgetView(entry: $0)
        }
        .configurationDisplayName("World Clock")
        .description("Home and every city on your board, at a glance.")
        .supportedFamilies([.systemLarge])
    }
}

@main
struct WorldClockWidgets: WidgetBundle {
    var body: some Widget {
        CitySkyWidget()
        BoardWidget()
    }
}
