package org.surajshetty.worldclockapp

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class ClockViewModel(application: Application) : AndroidViewModel(application) {
    private val repository = ClockRepository(application)

    private val _entries = MutableStateFlow(repository.load())
    val entries: StateFlow<List<ClockEntry>> = _entries.asStateFlow()

    fun addCity(timeZoneId: String, label: String) {
        if (_entries.value.any { it.timeZoneId == timeZoneId }) return
        _entries.value = _entries.value + ClockEntry(timeZoneId = timeZoneId, label = label)
        persist()
    }

    fun deleteCity(id: String) {
        _entries.value = _entries.value.filterNot { it.id == id }
        persist()
    }

    private fun persist() {
        val snapshot = _entries.value
        viewModelScope.launch { repository.save(snapshot) }
    }
}
