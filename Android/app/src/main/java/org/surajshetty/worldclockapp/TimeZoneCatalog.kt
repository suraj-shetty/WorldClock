package org.surajshetty.worldclockapp

import java.time.ZoneId

data class TimeZoneOption(val label: String, val timeZoneId: String) {
    val country: Country? get() = CountryLookup.lookup(timeZoneId)
}

/**
 * The full searchable city list for "Add a city" / "Choose home city", ported from
 * the iOS app's `AddTimeZoneView` extension.
 */
object TimeZoneCatalog {
    /**
     * IANA identifiers name one representative city per zone, so a country with a
     * single nationwide zone but several huge cities — India's `Asia/Kolkata`, say —
     * otherwise has no way to search for "Bengaluru" or "Delhi" even though both
     * keep that exact time. These aliases add searchable rows for major cities that
     * share an existing zone, without inventing new timezones: picking one still
     * stores the real IANA identifier, just under the city name people actually type.
     */
    private val cityAliases: List<Pair<String, String>> = listOf(
        // India — Asia/Kolkata
        "Bengaluru" to "Asia/Kolkata", "Bangalore" to "Asia/Kolkata", "Delhi" to "Asia/Kolkata",
        "New Delhi" to "Asia/Kolkata", "Mumbai" to "Asia/Kolkata", "Chennai" to "Asia/Kolkata",
        "Hyderabad" to "Asia/Kolkata", "Pune" to "Asia/Kolkata", "Ahmedabad" to "Asia/Kolkata",
        "Jaipur" to "Asia/Kolkata", "Surat" to "Asia/Kolkata", "Lucknow" to "Asia/Kolkata",
        "Kanpur" to "Asia/Kolkata", "Nagpur" to "Asia/Kolkata", "Indore" to "Asia/Kolkata",
        "Bhopal" to "Asia/Kolkata", "Visakhapatnam" to "Asia/Kolkata", "Patna" to "Asia/Kolkata",
        "Vadodara" to "Asia/Kolkata", "Coimbatore" to "Asia/Kolkata",
        // China — Asia/Shanghai
        "Beijing" to "Asia/Shanghai", "Guangzhou" to "Asia/Shanghai", "Shenzhen" to "Asia/Shanghai",
        "Chengdu" to "Asia/Shanghai", "Chongqing" to "Asia/Shanghai", "Tianjin" to "Asia/Shanghai",
        "Wuhan" to "Asia/Shanghai", "Xi'an" to "Asia/Shanghai", "Hangzhou" to "Asia/Shanghai",
        "Nanjing" to "Asia/Shanghai",
    )

    fun displayLabel(timeZoneId: String): String =
        timeZoneId.substringAfterLast('/').replace('_', ' ')

    val allOptions: List<TimeZoneOption> by lazy {
        val canonical = ZoneId.getAvailableZoneIds()
            .filter { it.contains('/') } // drop legacy 3-letter aliases (EST, PST, ...)
            .map { TimeZoneOption(displayLabel(it), it) }
        val aliases = cityAliases.map { (label, id) -> TimeZoneOption(label, id) }
        (canonical + aliases).sortedBy { it.label.lowercase() }
    }
}
