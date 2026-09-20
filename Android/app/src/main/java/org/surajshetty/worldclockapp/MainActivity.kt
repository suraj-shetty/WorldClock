package org.surajshetty.worldclockapp

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import java.time.Instant

private enum class Screen { Board, AddCity, HomePicker, Settings }

class MainActivity : ComponentActivity() {
    private val viewModel: ClockViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme(colorScheme = darkColorScheme()) {
                WorldClockApp(viewModel)
            }
        }
    }
}

@Composable
private fun WorldClockApp(viewModel: ClockViewModel) {
    var screen by remember { mutableStateOf(Screen.Board) }
    var now by remember { mutableStateOf(Instant.now()) }

    BackHandler(enabled = screen != Screen.Board) {
        screen = if (screen == Screen.HomePicker) Screen.Settings else Screen.Board
    }

    androidx.compose.runtime.LaunchedEffect(Unit) {
        while (isActive) {
            now = Instant.now()
            delay(1000)
        }
    }

    when (screen) {
        Screen.Board -> BoardScreen(
            viewModel = viewModel, now = now,
            onAddCity = { screen = Screen.AddCity },
            onSettings = { screen = Screen.Settings }
        )
        Screen.AddCity -> AddCityScreen(
            kicker = "${viewModel.entries.size} CITIES ON YOUR CLOCK",
            title = "Add a city",
            isMultiSelect = true,
            existingTimeZoneIds = viewModel.entries.map { it.timeZoneId }.toSet(),
            homeZone = viewModel.homeTimeZone, use24Hour = viewModel.settings.use24Hour, now = now,
            onSelect = { id, label -> viewModel.addCity(id, label) },
            onDismiss = { screen = Screen.Board }
        )
        Screen.HomePicker -> AddCityScreen(
            kicker = "HOME TIMEZONE",
            title = "Choose home city",
            isMultiSelect = false,
            existingTimeZoneIds = emptySet(),
            homeZone = viewModel.homeTimeZone, use24Hour = viewModel.settings.use24Hour, now = now,
            onSelect = { id, label -> viewModel.setHomeTimeZone(id, label) },
            onDismiss = { screen = Screen.Settings }
        )
        Screen.Settings -> SettingsScreen(
            viewModel = viewModel,
            onOpenHomePicker = { screen = Screen.HomePicker },
            onDismiss = { screen = Screen.Board }
        )
    }
}
