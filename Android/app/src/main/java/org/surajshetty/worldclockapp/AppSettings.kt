package org.surajshetty.worldclockapp

/** Mirrors the iOS app's `@AppStorage`-backed settings. */
data class AppSettings(
    val use24Hour: Boolean = false,
    val showCountryName: Boolean = true,
    val animateSky: Boolean = true,
    val flagNextDayCities: Boolean = false,
    val snapMinutes: Int = 15,
    val homeTimeZoneId: String? = null // null = device default
)
