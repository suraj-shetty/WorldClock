package org.surajshetty.worldclockapp

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

class MainActivity : ComponentActivity() {
    private val viewModel: ClockViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme(colorScheme = darkColorScheme()) {
                WorldClockScreen(viewModel)
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WorldClockScreen(viewModel: ClockViewModel) {
    val entries by viewModel.entries.collectAsState()
    var showAddDialog by remember { mutableStateOf(false) }
    var now by remember { mutableStateOf(Instant.now()) }

    // A plain per-second tick, not a Flow from the ViewModel — nothing about "the
    // current instant" is state worth surviving a config change or a process death,
    // so it lives here rather than adding a second clock source to reconcile with
    // the saved entries.
    LaunchedEffect(Unit) {
        while (isActive) {
            now = Instant.now()
            delay(1000)
        }
    }

    Scaffold(
        topBar = { TopAppBar(title = { Text("World Clock") }) },
        floatingActionButton = {
            FloatingActionButton(onClick = { showAddDialog = true }) {
                Icon(Icons.Default.Add, contentDescription = "Add city")
            }
        }
    ) { padding ->
        if (entries.isEmpty()) {
            Box(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentAlignment = Alignment.Center
            ) {
                Text("Tap + to add a city", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(entries, key = { it.id }) { entry ->
                    ClockRow(entry = entry, now = now, onDelete = { viewModel.deleteCity(entry.id) })
                }
            }
        }
    }

    if (showAddDialog) {
        AddCityDialog(
            onDismiss = { showAddDialog = false },
            onSelect = { zoneId, label ->
                viewModel.addCity(zoneId, label)
                showAddDialog = false
            }
        )
    }
}

@Composable
fun ClockRow(entry: ClockEntry, now: Instant, onDelete: () -> Unit) {
    val zone = remember(entry.timeZoneId) { ZoneId.of(entry.timeZoneId) }
    val timeText = remember(now, zone) {
        DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT).withZone(zone).format(now)
    }

    Card(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(entry.label, style = MaterialTheme.typography.titleMedium)
                Text(
                    entry.timeZoneId,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(timeText, style = MaterialTheme.typography.headlineSmall)
                IconButton(onClick = onDelete) {
                    Icon(Icons.Default.Delete, contentDescription = "Delete ${entry.label}")
                }
            }
        }
    }
}

@Composable
fun AddCityDialog(onDismiss: () -> Unit, onSelect: (zoneId: String, label: String) -> Unit) {
    var query by remember { mutableStateOf("") }
    // IANA ids only (contain a "/") — drops the legacy 3-letter aliases (EST, PST, ...)
    // that duplicate a real zone under a less useful name.
    val allZones = remember {
        ZoneId.getAvailableZoneIds().filter { it.contains('/') }.sorted()
    }
    val filtered = remember(query) {
        if (query.isBlank()) allZones else allZones.filter { it.contains(query, ignoreCase = true) }
    }

    Dialog(onDismissRequest = onDismiss) {
        Surface(shape = MaterialTheme.shapes.large, tonalElevation = 4.dp) {
            Column(Modifier.fillMaxWidth().heightIn(max = 500.dp).padding(16.dp)) {
                Text("Add a city", style = MaterialTheme.typography.titleLarge)
                Spacer(Modifier.height(12.dp))
                OutlinedTextField(
                    value = query,
                    onValueChange = { query = it },
                    label = { Text("City or timezone") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(Modifier.height(12.dp))
                LazyColumn(modifier = Modifier.heightIn(max = 350.dp)) {
                    items(filtered, key = { it }) { zoneId ->
                        val label = zoneId.substringAfterLast('/').replace('_', ' ')
                        ListItem(
                            headlineContent = { Text(label) },
                            supportingContent = { Text(zoneId) },
                            modifier = Modifier.clickable { onSelect(zoneId, label) }
                        )
                    }
                }
            }
        }
    }
}
