package org.surajshetty.worldclockapp

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.time.Duration
import java.time.Instant
import java.time.ZoneId

/**
 * Board state: saved cities, settings, and the single shared selection/offset that
 * both the bottom wheel and a selected row's inline wheel read and write — mirrors
 * the iOS app's split between `ClockEntry`/`@AppStorage` (persisted) and
 * `ClockBoardViewModel` (transient selection/offset), folded into one class since
 * Compose has no SwiftUI-`@AppStorage`-per-property equivalent worth reproducing.
 */
class ClockViewModel(application: Application) : AndroidViewModel(application) {
    private val repository = ClockRepository(application)

    var entries by mutableStateOf(repository.loadEntries().sortedBy { it.sortOrder })
        private set

    var settings by mutableStateOf(repository.loadSettings())
        private set

    /** Selecting a row swaps the wheel's anchor to that row and hides the global
     * wheel; tapping the already-selected row deselects and resets to "Now". */
    var selectedEntryId by mutableStateOf<String?>(null)
        private set

    /** Shared scrub offset, in seconds — same value read by whichever wheel (global
     * or a selected row's inline one) is currently mounted. */
    var offset by mutableStateOf(0.0)
        private set

    val homeTimeZone: ZoneId
        get() = settings.homeTimeZoneId
            ?.let { runCatching { ZoneId.of(it) }.getOrNull() }
            ?: ZoneId.systemDefault()

    fun addCity(timeZoneId: String, label: String) {
        if (entries.any { it.timeZoneId == timeZoneId }) return
        val nextOrder = (entries.maxOfOrNull { it.sortOrder } ?: -1) + 1
        entries = entries + ClockEntry(timeZoneId = timeZoneId, label = label, sortOrder = nextOrder)
        persistEntries()
    }

    /** Centralizing deletion here (rather than each call site) is what keeps the
     * board from getting stuck showing a selected-but-deleted row with no way back —
     * see the identical fix in the iOS app's `deleteEntry`. */
    fun deleteCity(id: String) {
        if (selectedEntryId == id) deselect()
        entries = entries.filterNot { it.id == id }
        persistEntries()
    }

    fun select(entry: ClockEntry) {
        if (selectedEntryId == entry.id) {
            deselect()
        } else {
            selectedEntryId = entry.id
            offset = 0.0
        }
    }

    fun deselect() {
        selectedEntryId = null
        offset = 0.0
    }

    fun updateOffset(seconds: Double) {
        offset = seconds
    }

    fun setHomeTimeZone(timeZoneId: String, label: String) {
        updateSettings { it.copy(homeTimeZoneId = timeZoneId, homeTimeZoneLabel = label) }
    }

    /** The home zone's display label — the alias the user picked it under (e.g. a
     * city name sharing a country's zone), falling back to the zone ID's own name
     * when unset. */
    val homeTimeZoneLabel: String
        get() = settings.homeTimeZoneLabel ?: TimeZoneCatalog.displayLabel(homeTimeZone.id)

    fun updateSettings(transform: (AppSettings) -> AppSettings) {
        settings = transform(settings)
        val snapshot = settings
        viewModelScope.launch(Dispatchers.IO) { repository.saveSettings(snapshot) }
    }

    /** The timezone the active wheel's tick labels are drawn in: the selected row's
     * zone, or home when nothing is selected. */
    fun anchorTimeZone(): ZoneId {
        val id = selectedEntryId ?: return homeTimeZone
        val entry = entries.firstOrNull { it.id == id } ?: return homeTimeZone
        return runCatching { ZoneId.of(entry.timeZoneId) }.getOrDefault(homeTimeZone)
    }

    fun displayInstant(now: Instant): Instant = now.plus(offsetDuration())

    private fun offsetDuration(): Duration = Duration.ofNanos((offset * 1_000_000_000).toLong())

    /** Fractional hour-of-day (0..<24) in the active anchor's timezone, at
     * `now + offset`. Feeds the sky background, which keys everything off this. */
    fun activeAnchorHour(now: Instant): Double = hourOfDay(anchorTimeZone(), displayInstant(now))

    private fun persistEntries() {
        val snapshot = entries
        viewModelScope.launch(Dispatchers.IO) { repository.saveEntries(snapshot) }
    }

    companion object {
        fun hourOfDay(zone: ZoneId, instant: Instant): Double {
            val zoned = instant.atZone(zone)
            return zoned.hour + zoned.minute / 60.0
        }
    }
}
