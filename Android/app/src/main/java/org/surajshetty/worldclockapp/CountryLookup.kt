package org.surajshetty.worldclockapp

import java.util.Locale

data class Country(val name: String, val flag: String)

/**
 * IANA timezone identifier -> ISO 3166-1 alpha-2 country code, ported from the iOS
 * app's `countryCodesByTimeZone`. Covers the identifiers people actually add (major
 * cities/countries), not the full ~400 entries `ZoneId.getAvailableZoneIds()`
 * returns — many of the rest are uninhabited research stations or historical aliases.
 */
object CountryLookup {
    private val countryCodesByTimeZone: Map<String, String> = mapOf(
        // Africa
        "Africa/Cairo" to "EG", "Africa/Lagos" to "NG", "Africa/Johannesburg" to "ZA",
        "Africa/Nairobi" to "KE", "Africa/Casablanca" to "MA", "Africa/Accra" to "GH",
        "Africa/Addis_Ababa" to "ET", "Africa/Algiers" to "DZ", "Africa/Tunis" to "TN",
        "Africa/Tripoli" to "LY", "Africa/Khartoum" to "SD", "Africa/Kinshasa" to "CD",
        "Africa/Abidjan" to "CI", "Africa/Dakar" to "SN", "Africa/Kampala" to "UG",
        "Africa/Dar_es_Salaam" to "TZ", "Africa/Harare" to "ZW", "Africa/Lusaka" to "ZM",
        "Africa/Maputo" to "MZ", "Africa/Windhoek" to "NA", "Africa/Bangui" to "CF",
        "Africa/Banjul" to "GM",
        // Americas
        "America/New_York" to "US", "America/Chicago" to "US", "America/Denver" to "US",
        "America/Los_Angeles" to "US", "America/Anchorage" to "US", "America/Phoenix" to "US",
        "America/Detroit" to "US", "America/Indianapolis" to "US", "Pacific/Honolulu" to "US",
        "America/Toronto" to "CA", "America/Vancouver" to "CA", "America/Winnipeg" to "CA",
        "America/Edmonton" to "CA", "America/Halifax" to "CA",
        "America/Mexico_City" to "MX", "America/Bogota" to "CO", "America/Lima" to "PE",
        "America/Santiago" to "CL", "America/Argentina/Buenos_Aires" to "AR",
        "America/Sao_Paulo" to "BR", "America/Caracas" to "VE", "America/Montevideo" to "UY",
        "America/Asuncion" to "PY", "America/La_Paz" to "BO", "America/Guatemala" to "GT",
        "America/Havana" to "CU", "America/Panama" to "PA", "America/El_Salvador" to "SV",
        "America/Tegucigalpa" to "HN", "America/Managua" to "NI", "America/Costa_Rica" to "CR",
        "America/Santo_Domingo" to "DO", "America/Port-au-Prince" to "HT",
        "America/Jamaica" to "JM", "America/Nassau" to "BS", "America/Barbados" to "BB",
        "America/Guyana" to "GY", "America/Paramaribo" to "SR",
        // Asia
        "Asia/Kolkata" to "IN", "Asia/Calcutta" to "IN", "Asia/Dubai" to "AE",
        "Asia/Tokyo" to "JP", "Asia/Shanghai" to "CN", "Asia/Hong_Kong" to "HK",
        "Asia/Singapore" to "SG", "Asia/Seoul" to "KR", "Asia/Bangkok" to "TH",
        "Asia/Jakarta" to "ID", "Asia/Manila" to "PH", "Asia/Kuala_Lumpur" to "MY",
        "Asia/Karachi" to "PK", "Asia/Dhaka" to "BD", "Asia/Colombo" to "LK",
        "Asia/Kathmandu" to "NP", "Asia/Yangon" to "MM", "Asia/Riyadh" to "SA",
        "Asia/Tehran" to "IR", "Asia/Baghdad" to "IQ", "Asia/Jerusalem" to "IL",
        "Asia/Amman" to "JO", "Asia/Beirut" to "LB", "Asia/Damascus" to "SY",
        "Asia/Kuwait" to "KW", "Asia/Qatar" to "QA", "Asia/Muscat" to "OM",
        "Asia/Tashkent" to "UZ", "Asia/Almaty" to "KZ", "Asia/Baku" to "AZ",
        "Asia/Yerevan" to "AM", "Asia/Tbilisi" to "GE", "Asia/Ulaanbaatar" to "MN",
        "Asia/Taipei" to "TW", "Asia/Ho_Chi_Minh" to "VN", "Asia/Phnom_Penh" to "KH",
        "Asia/Vientiane" to "LA", "Asia/Brunei" to "BN",
        // Atlantic
        "Atlantic/Reykjavik" to "IS", "Atlantic/Azores" to "PT", "Atlantic/Bermuda" to "BM",
        "Atlantic/Canary" to "ES", "Atlantic/Cape_Verde" to "CV",
        // Australia
        "Australia/Sydney" to "AU", "Australia/Melbourne" to "AU", "Australia/Brisbane" to "AU",
        "Australia/Perth" to "AU", "Australia/Adelaide" to "AU", "Australia/Darwin" to "AU",
        "Australia/Hobart" to "AU",
        // Europe
        "Europe/London" to "GB", "Europe/Paris" to "FR", "Europe/Berlin" to "DE",
        "Europe/Madrid" to "ES", "Europe/Rome" to "IT", "Europe/Amsterdam" to "NL",
        "Europe/Brussels" to "BE", "Europe/Vienna" to "AT", "Europe/Zurich" to "CH",
        "Europe/Dublin" to "IE", "Europe/Lisbon" to "PT", "Europe/Warsaw" to "PL",
        "Europe/Prague" to "CZ", "Europe/Budapest" to "HU", "Europe/Bucharest" to "RO",
        "Europe/Sofia" to "BG", "Europe/Athens" to "GR", "Europe/Helsinki" to "FI",
        "Europe/Stockholm" to "SE", "Europe/Oslo" to "NO", "Europe/Copenhagen" to "DK",
        "Europe/Moscow" to "RU", "Europe/Kyiv" to "UA", "Europe/Kiev" to "UA",
        "Europe/Istanbul" to "TR", "Europe/Belgrade" to "RS", "Europe/Zagreb" to "HR",
        "Europe/Ljubljana" to "SI", "Europe/Bratislava" to "SK", "Europe/Vilnius" to "LT",
        "Europe/Riga" to "LV", "Europe/Tallinn" to "EE", "Europe/Luxembourg" to "LU",
        "Europe/Malta" to "MT", "Europe/Minsk" to "BY", "Europe/Chisinau" to "MD",
        "Europe/Sarajevo" to "BA", "Europe/Skopje" to "MK", "Europe/Podgorica" to "ME",
        "Europe/Andorra" to "AD", "Europe/Monaco" to "MC", "Europe/San_Marino" to "SM",
        "Europe/Vatican" to "VA", "Europe/Gibraltar" to "GI",
        // Indian Ocean
        "Indian/Mauritius" to "MU", "Indian/Maldives" to "MV", "Indian/Reunion" to "RE",
        "Indian/Christmas" to "CX", "Indian/Cocos" to "CC",
        // Pacific
        "Pacific/Auckland" to "NZ", "Pacific/Fiji" to "FJ", "Pacific/Guam" to "GU",
        "Pacific/Tahiti" to "PF", "Pacific/Noumea" to "NC", "Pacific/Port_Moresby" to "PG",
        "Pacific/Apia" to "WS", "Pacific/Tongatapu" to "TO", "Pacific/Majuro" to "MH",
        "Pacific/Palau" to "PW",
    )

    private val cache = HashMap<String, Country?>()

    fun lookup(timeZoneId: String): Country? {
        cache[timeZoneId]?.let { return it }
        if (cache.containsKey(timeZoneId)) return null // cached "no country" miss
        val code = countryCodesByTimeZone[timeZoneId] ?: run { cache[timeZoneId] = null; return null }
        val name = Locale("", code).displayCountry
        val result = Country(name, flagEmoji(code))
        cache[timeZoneId] = result
        return result
    }

    private fun flagEmoji(countryCode: String): String {
        val base = 0x1F1E6 - 'A'.code // regional-indicator 'A' minus ASCII 'A'
        return countryCode.uppercase().map { letter -> String(Character.toChars(base + letter.code)) }
            .joinToString("")
    }
}
