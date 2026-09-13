package org.surajshetty.worldclockapp

import java.util.UUID

/** A saved city: an IANA timezone identifier (e.g. "Europe/London") plus the
 * display label shown in its row. `sortOrder` is board position — a plain
 * incrementing counter, same role as the iOS model's `sortOrder`. */
data class ClockEntry(
    val id: String = UUID.randomUUID().toString(),
    val timeZoneId: String,
    val label: String,
    val sortOrder: Int
)
