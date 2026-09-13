package org.surajshetty.worldclockapp

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Persists the saved city list as a JSON array in SharedPreferences — a handful of
 * rows doesn't need a database; swap for Room if this ever needs querying or sync.
 */
class ClockRepository(context: Context) {
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun load(): List<ClockEntry> {
        val raw = prefs.getString(KEY_ENTRIES, null) ?: return emptyList()
        val array = JSONArray(raw)
        return (0 until array.length()).map { i ->
            val obj = array.getJSONObject(i)
            ClockEntry(
                id = obj.getString("id"),
                timeZoneId = obj.getString("timeZoneId"),
                label = obj.getString("label")
            )
        }
    }

    fun save(entries: List<ClockEntry>) {
        val array = JSONArray()
        entries.forEach { entry ->
            array.put(
                JSONObject()
                    .put("id", entry.id)
                    .put("timeZoneId", entry.timeZoneId)
                    .put("label", entry.label)
            )
        }
        prefs.edit().putString(KEY_ENTRIES, array.toString()).apply()
    }

    private companion object {
        const val PREFS_NAME = "world_clock"
        const val KEY_ENTRIES = "entries"
    }
}
