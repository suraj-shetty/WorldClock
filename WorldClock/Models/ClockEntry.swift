import Foundation
import SwiftData

/// Shared by `ClockEntry.timeZone` and the timezone picker's rows (`AddTimeZoneView`).
/// `TimeZone(identifier:)` goes through Foundation's lookup path and the result never
/// changes for a given identifier, so it's cached rather than reconstructed on every
/// SwiftUI body evaluation — previously each of those two call sites kept its own
/// separate, uncached copy of this same construction.
///
/// Not synchronized: every reader/writer in this app is a SwiftUI view body, i.e. the
/// main thread, which is the only context `ClockEntry` and this cache are ever touched
/// from today. If a background import/export path or a strict-concurrency build ever
/// touches this off the main thread, it needs a lock or `@MainActor` isolation first.
enum TimeZoneResolver {
    private static var cache: [String: TimeZone] = [:]

    static func resolve(_ identifier: String) -> TimeZone {
        if let cached = cache[identifier] { return cached }
        let zone = TimeZone(identifier: identifier) ?? .current
        cache[identifier] = zone
        return zone
    }
}

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

    /// Memoized — see `TimeZoneResolver`. Read several times per row (time, offset,
    /// next-day check) on every clock tick.
    var timeZone: TimeZone {
        TimeZoneResolver.resolve(timeZoneIdentifier)
    }

    /// Localized country name + flag for the row subtitle. `nil` for identifiers not in
    /// the lookup table below (e.g. `Etc/UTC`, uninhabited Antarctica stations) — the
    /// row just falls back to showing the UTC-offset delta alone.
    var country: (name: String, flag: String)? {
        ClockEntry.lookupCountry(for: timeZoneIdentifier)
    }

    /// Same lookup as `country`, usable for a timezone identifier that isn't backed by
    /// a saved `ClockEntry` (the Settings screen's home-timezone picker).
    ///
    /// Memoized: this is read from every visible row's body on every clock tick (once
    /// a second for the main list), and the result never changes for a given
    /// identifier — recomputing the dictionary lookup, `Locale` call, and flag-emoji
    /// construction that often was pure waste.
    static func lookupCountry(for identifier: String) -> (name: String, flag: String)? {
        if let cached = countryCache[identifier] { return cached }
        guard let code = countryCodesByTimeZone[identifier],
              let name = Locale.current.localizedString(forRegionCode: code) else {
            countryCache[identifier] = .some(nil)
            return nil
        }
        let result = (name, flagEmoji(countryCode: code))
        countryCache[identifier] = result
        return result
    }

    // Not synchronized — same main-thread-only assumption as `TimeZoneResolver` above.
    private static var countryCache: [String: (name: String, flag: String)?] = [:]

    private static func flagEmoji(countryCode: String) -> String {
        let base: UInt32 = 127397 // 0x1F1E6 ('A' flag letter) - 65 ('A')
        var scalars = String.UnicodeScalarView()
        for scalar in countryCode.uppercased().unicodeScalars {
            if let flagScalar = Unicode.Scalar(base + scalar.value) {
                scalars.append(flagScalar)
            }
        }
        return String(scalars)
    }

    /// IANA timezone identifier -> ISO 3166-1 alpha-2 country code. Covers the
    /// identifiers people actually add (major cities/countries), not the full ~400
    /// entries in `TimeZone.knownTimeZoneIdentifiers` — many of the rest are
    /// uninhabited research stations or historical aliases anyway.
    private static let countryCodesByTimeZone: [String: String] = [
        // Africa
        "Africa/Cairo": "EG", "Africa/Lagos": "NG", "Africa/Johannesburg": "ZA",
        "Africa/Nairobi": "KE", "Africa/Casablanca": "MA", "Africa/Accra": "GH",
        "Africa/Addis_Ababa": "ET", "Africa/Algiers": "DZ", "Africa/Tunis": "TN",
        "Africa/Tripoli": "LY", "Africa/Khartoum": "SD", "Africa/Kinshasa": "CD",
        "Africa/Abidjan": "CI", "Africa/Dakar": "SN", "Africa/Kampala": "UG",
        "Africa/Dar_es_Salaam": "TZ", "Africa/Harare": "ZW", "Africa/Lusaka": "ZM",
        "Africa/Maputo": "MZ", "Africa/Windhoek": "NA", "Africa/Bangui": "CF",
        "Africa/Banjul": "GM",
        // Americas
        "America/New_York": "US", "America/Chicago": "US", "America/Denver": "US",
        "America/Los_Angeles": "US", "America/Anchorage": "US", "America/Phoenix": "US",
        "America/Detroit": "US", "America/Indianapolis": "US", "Pacific/Honolulu": "US",
        "America/Toronto": "CA", "America/Vancouver": "CA", "America/Winnipeg": "CA",
        "America/Edmonton": "CA", "America/Halifax": "CA",
        "America/Mexico_City": "MX", "America/Bogota": "CO", "America/Lima": "PE",
        "America/Santiago": "CL", "America/Argentina/Buenos_Aires": "AR",
        "America/Sao_Paulo": "BR", "America/Caracas": "VE", "America/Montevideo": "UY",
        "America/Asuncion": "PY", "America/La_Paz": "BO", "America/Guatemala": "GT",
        "America/Havana": "CU", "America/Panama": "PA", "America/El_Salvador": "SV",
        "America/Tegucigalpa": "HN", "America/Managua": "NI", "America/Costa_Rica": "CR",
        "America/Santo_Domingo": "DO", "America/Port-au-Prince": "HT",
        "America/Jamaica": "JM", "America/Nassau": "BS", "America/Barbados": "BB",
        "America/Guyana": "GY", "America/Paramaribo": "SR",
        // Asia
        "Asia/Kolkata": "IN", "Asia/Calcutta": "IN", "Asia/Dubai": "AE",
        "Asia/Tokyo": "JP", "Asia/Shanghai": "CN", "Asia/Hong_Kong": "HK",
        "Asia/Singapore": "SG", "Asia/Seoul": "KR", "Asia/Bangkok": "TH",
        "Asia/Jakarta": "ID", "Asia/Manila": "PH", "Asia/Kuala_Lumpur": "MY",
        "Asia/Karachi": "PK", "Asia/Dhaka": "BD", "Asia/Colombo": "LK",
        "Asia/Kathmandu": "NP", "Asia/Yangon": "MM", "Asia/Riyadh": "SA",
        "Asia/Tehran": "IR", "Asia/Baghdad": "IQ", "Asia/Jerusalem": "IL",
        "Asia/Amman": "JO", "Asia/Beirut": "LB", "Asia/Damascus": "SY",
        "Asia/Kuwait": "KW", "Asia/Qatar": "QA", "Asia/Muscat": "OM",
        "Asia/Tashkent": "UZ", "Asia/Almaty": "KZ", "Asia/Baku": "AZ",
        "Asia/Yerevan": "AM", "Asia/Tbilisi": "GE", "Asia/Ulaanbaatar": "MN",
        "Asia/Taipei": "TW", "Asia/Ho_Chi_Minh": "VN", "Asia/Phnom_Penh": "KH",
        "Asia/Vientiane": "LA", "Asia/Brunei": "BN",
        // Atlantic
        "Atlantic/Reykjavik": "IS", "Atlantic/Azores": "PT", "Atlantic/Bermuda": "BM",
        "Atlantic/Canary": "ES", "Atlantic/Cape_Verde": "CV",
        // Australia
        "Australia/Sydney": "AU", "Australia/Melbourne": "AU", "Australia/Brisbane": "AU",
        "Australia/Perth": "AU", "Australia/Adelaide": "AU", "Australia/Darwin": "AU",
        "Australia/Hobart": "AU",
        // Europe
        "Europe/London": "GB", "Europe/Paris": "FR", "Europe/Berlin": "DE",
        "Europe/Madrid": "ES", "Europe/Rome": "IT", "Europe/Amsterdam": "NL",
        "Europe/Brussels": "BE", "Europe/Vienna": "AT", "Europe/Zurich": "CH",
        "Europe/Dublin": "IE", "Europe/Lisbon": "PT", "Europe/Warsaw": "PL",
        "Europe/Prague": "CZ", "Europe/Budapest": "HU", "Europe/Bucharest": "RO",
        "Europe/Sofia": "BG", "Europe/Athens": "GR", "Europe/Helsinki": "FI",
        "Europe/Stockholm": "SE", "Europe/Oslo": "NO", "Europe/Copenhagen": "DK",
        "Europe/Moscow": "RU", "Europe/Kyiv": "UA", "Europe/Kiev": "UA",
        "Europe/Istanbul": "TR", "Europe/Belgrade": "RS", "Europe/Zagreb": "HR",
        "Europe/Ljubljana": "SI", "Europe/Bratislava": "SK", "Europe/Vilnius": "LT",
        "Europe/Riga": "LV", "Europe/Tallinn": "EE", "Europe/Luxembourg": "LU",
        "Europe/Malta": "MT", "Europe/Minsk": "BY", "Europe/Chisinau": "MD",
        "Europe/Sarajevo": "BA", "Europe/Skopje": "MK", "Europe/Podgorica": "ME",
        "Europe/Andorra": "AD", "Europe/Monaco": "MC", "Europe/San_Marino": "SM",
        "Europe/Vatican": "VA", "Europe/Gibraltar": "GI",
        // Indian Ocean
        "Indian/Mauritius": "MU", "Indian/Maldives": "MV", "Indian/Reunion": "RE",
        "Indian/Christmas": "CX", "Indian/Cocos": "CC",
        // Pacific
        "Pacific/Auckland": "NZ", "Pacific/Fiji": "FJ", "Pacific/Guam": "GU",
        "Pacific/Tahiti": "PF", "Pacific/Noumea": "NC", "Pacific/Port_Moresby": "PG",
        "Pacific/Apia": "WS", "Pacific/Tongatapu": "TO", "Pacific/Majuro": "MH",
        "Pacific/Palau": "PW",
    ]
}
