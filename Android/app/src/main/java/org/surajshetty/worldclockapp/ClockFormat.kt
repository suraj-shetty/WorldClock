package org.surajshetty.worldclockapp

import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.Locale
import kotlin.math.abs

/** Unicode minus (U+2212), used instead of ASCII '-' for negative offsets throughout. */
const val MINUS_SIGN = "−"

/** "3:45" + "PM" (or "15:45" + "" in 24h mode) — shared by the board rows and the
 * add-city picker's option list. */
fun formatClockTime(zdt: ZonedDateTime, use24Hour: Boolean): Pair<String, String> {
    if (use24Hour) return String.format(Locale.US, "%02d:%02d", zdt.hour, zdt.minute) to ""
    val displayHour = if (zdt.hour % 12 == 0) 12 else zdt.hour % 12
    return String.format(Locale.US, "%d:%02d", displayHour, zdt.minute) to (if (zdt.hour < 12) "AM" else "PM")
}

/** "Home", "+3h", or "−1.5h" — how far `zone` sits from `homeZone` at `at`, shared
 * by a board row's delta label and the add-city picker's subtitle. */
fun formatOffsetLabel(homeZone: ZoneId, zone: ZoneId, at: Instant): String {
    val homeOffsetSeconds = homeZone.rules.getOffset(at).totalSeconds
    val zoneOffsetSeconds = zone.rules.getOffset(at).totalSeconds
    val diffMinutes = (zoneOffsetSeconds - homeOffsetSeconds) / 60
    if (diffMinutes == 0) return "Home"
    val sign = if (diffMinutes > 0) "+" else MINUS_SIGN
    val magnitude = abs(diffMinutes)
    val hours = magnitude / 60
    val minutes = magnitude % 60
    val tenths = Math.round(minutes / 6.0)
    return if (minutes == 0) "$sign${hours}h" else "$sign$hours.${tenths}h"
}
