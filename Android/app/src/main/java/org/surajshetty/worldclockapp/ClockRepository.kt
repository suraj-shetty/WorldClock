package org.surajshetty.worldclockapp

import android.content.Context
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

/**
 * Persists the saved city list and settings in SharedPreferences — a handful of
 * rows and a handful of flags doesn't need a database; swap for Room/DataStore if
 * this ever needs querying or sync.
 */
class ClockRepository(context: Context) {
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun loadEntries(): List<ClockEntry> {
        val raw = prefs.getString(KEY_ENTRIES, null) ?: return emptyList()
        return parseEntries(raw)
    }

    fun saveEntries(entries: List<ClockEntry>) {
        prefs.edit().putString(KEY_ENTRIES, serializeEntries(entries)).apply()
    }

    fun loadSettings(): AppSettings = AppSettings(
        use24Hour = prefs.getBoolean(KEY_USE_24_HOUR, false),
        showCountryName = prefs.getBoolean(KEY_SHOW_COUNTRY, true),
        animateSky = prefs.getBoolean(KEY_ANIMATE_SKY, true),
        flagNextDayCities = prefs.getBoolean(KEY_FLAG_NEXT_DAY, false),
        snapMinutes = prefs.getInt(KEY_SNAP_MINUTES, 15),
        homeTimeZoneId = prefs.getString(KEY_HOME_ZONE, null),
        homeTimeZoneLabel = prefs.getString(KEY_HOME_ZONE_LABEL, null)
    )

    fun saveSettings(settings: AppSettings) {
        prefs.edit()
            .putBoolean(KEY_USE_24_HOUR, settings.use24Hour)
            .putBoolean(KEY_SHOW_COUNTRY, settings.showCountryName)
            .putBoolean(KEY_ANIMATE_SKY, settings.animateSky)
            .putBoolean(KEY_FLAG_NEXT_DAY, settings.flagNextDayCities)
            .putInt(KEY_SNAP_MINUTES, settings.snapMinutes)
            .putString(KEY_HOME_ZONE, settings.homeTimeZoneId)
            .putString(KEY_HOME_ZONE_LABEL, settings.homeTimeZoneLabel)
            .apply()
    }

    private companion object {
        const val PREFS_NAME = "world_clock"
        const val KEY_ENTRIES = "entries"
        const val KEY_USE_24_HOUR = "use24Hour"
        const val KEY_SHOW_COUNTRY = "showCountryName"
        const val KEY_ANIMATE_SKY = "animateSky"
        const val KEY_FLAG_NEXT_DAY = "flagNextDayCities"
        const val KEY_SNAP_MINUTES = "snapMinutes"
        const val KEY_HOME_ZONE = "homeTimeZoneId"
        const val KEY_HOME_ZONE_LABEL = "homeTimeZoneLabel"
    }
}

/** Pulled out of [ClockRepository] so the JSON round-trip (including malformed
 * input) can be unit-tested without a [Context]/SharedPreferences. */
internal fun parseEntries(raw: String): List<ClockEntry> = try {
    val array = JSONArray(raw)
    (0 until array.length()).map { i ->
        val obj = array.getJSONObject(i)
        ClockEntry(
            id = obj.getString("id"),
            timeZoneId = obj.getString("timeZoneId"),
            label = obj.getString("label"),
            sortOrder = obj.getInt("sortOrder")
        )
    }
} catch (e: JSONException) {
    emptyList()
}

internal fun serializeEntries(entries: List<ClockEntry>): String {
    val array = JSONArray()
    entries.forEach { entry ->
        array.put(
            JSONObject()
                .put("id", entry.id)
                .put("timeZoneId", entry.timeZoneId)
                .put("label", entry.label)
                .put("sortOrder", entry.sortOrder)
        )
    }
    return array.toString()
}
