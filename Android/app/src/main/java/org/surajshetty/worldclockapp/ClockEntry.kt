package org.surajshetty.worldclockapp

import java.util.UUID

/** A saved city: an IANA timezone identifier (e.g. "Europe/London") plus the
 * display label shown in its row. */
data class ClockEntry(
    val id: String = UUID.randomUUID().toString(),
    val timeZoneId: String,
    val label: String
)
