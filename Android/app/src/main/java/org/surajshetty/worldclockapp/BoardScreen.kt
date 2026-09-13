package org.surajshetty.worldclockapp

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.staggeredgrid.LazyVerticalStaggeredGrid
import androidx.compose.foundation.lazy.staggeredgrid.StaggeredGridCells
import androidx.compose.foundation.lazy.staggeredgrid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.time.Instant

/**
 * The main board — ported from the iOS app's `ClockListView`: animated sky
 * background, header, a masonry grid of city cards (one column on a phone,
 * several on a tablet — `StaggeredGridCells.Adaptive` gives this for free, unlike
 * the hand-rolled masonry the iOS/SwiftUI version needed), and the global scrub
 * wheel — or, when a row is selected, that row's own inline wheel instead.
 */
@Composable
fun BoardScreen(
    viewModel: ClockViewModel,
    now: Instant,
    onAddCity: () -> Unit,
    onSettings: () -> Unit
) {
    val settings = viewModel.settings
    val skyHour = if (settings.animateSky) {
        viewModel.activeAnchorHour(now)
    } else {
        ClockViewModel.hourOfDay(viewModel.homeTimeZone, now)
    }

    Box(modifier = Modifier.fillMaxSize()) {
        SkyBackground(hour = skyHour, modifier = Modifier.fillMaxSize())

        // Top scrim so the header text stays legible over a bright sky.
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(230.dp)
                .background(
                    Brush.verticalGradient(
                        0f to Color(0xD90E101B), 0.45f to Color(0x8C0E101B), 0.78f to Color(0x2E0E101B), 1f to Color.Transparent
                    )
                )
        )

        Column(modifier = Modifier.fillMaxSize()) {
            Header(
                homeZoneLabel = TimeZoneCatalog.displayLabel(viewModel.homeTimeZone.id),
                onSettings = onSettings, onAddCity = onAddCity,
                modifier = Modifier.widthIn(max = 700.dp)
            )

            if (viewModel.entries.isEmpty()) {
                Box(modifier = Modifier.fillMaxWidth().padding(32.dp), contentAlignment = Alignment.Center) {
                    BasicText("Tap + to add a city", style = TextStyle(color = Theme.text.copy(alpha = 0.6f), fontSize = 15.sp))
                }
            } else {
                LazyVerticalStaggeredGrid(
                    columns = StaggeredGridCells.Adaptive(minSize = 320.dp),
                    modifier = Modifier.weight(1f).fillMaxWidth(),
                    contentPadding = PaddingValues(horizontal = Theme.Spacing.base, vertical = 6.dp),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    verticalItemSpacing = 10.dp
                ) {
                    items(viewModel.entries, key = { it.id }) { entry ->
                        ClockRow(
                            entry = entry, now = now, offset = viewModel.offset,
                            isSelected = viewModel.selectedEntryId == entry.id,
                            use24Hour = settings.use24Hour, showCountryName = settings.showCountryName,
                            flagNextDayCities = settings.flagNextDayCities, homeZone = viewModel.homeTimeZone,
                            snapMinutes = settings.snapMinutes,
                            onSelect = { viewModel.select(entry) },
                            onOffsetChange = { viewModel.updateOffset(it) },
                            onDelete = { viewModel.deleteCity(entry.id) }
                        )
                    }
                }
            }

            if (viewModel.selectedEntryId == null) {
                TimeWheel(
                    anchorNow = now, anchorZone = viewModel.homeTimeZone, use24Hour = settings.use24Hour,
                    style = WheelStyle.Bottom, offset = viewModel.offset, snapMinutes = settings.snapMinutes,
                    onOffsetChange = { viewModel.updateOffset(it) },
                    modifier = Modifier
                        .widthIn(max = 700.dp)
                        .fillMaxWidth()
                        .padding(horizontal = Theme.Spacing.base)
                        .padding(top = 22.dp, bottom = Theme.Spacing.base)
                )
            }
        }
    }
}

@Composable
private fun Header(homeZoneLabel: String, onSettings: () -> Unit, onAddCity: () -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = Theme.Spacing.base)
            .padding(top = 48.dp, bottom = 20.dp),
        verticalAlignment = Alignment.Bottom,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Column {
            BasicText(
                text = "${homeZoneLabel.uppercase()} · YOUR TIME",
                style = TextStyle(color = Theme.text.copy(alpha = 0.62f), fontSize = 10.sp, fontWeight = FontWeight.Medium, letterSpacing = 1.5.sp)
            )
            Spacer(Modifier.height(4.dp))
            BasicText(
                text = "World Clock",
                style = TextStyle(color = Theme.text, fontSize = 29.sp, fontWeight = FontWeight.Medium, letterSpacing = (-0.5).sp)
            )
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            HeaderButton(icon = Icons.Default.Settings, contentDescription = "Settings", onClick = onSettings)
            HeaderButton(icon = Icons.Default.Add, contentDescription = "Add city", onClick = onAddCity)
        }
    }
}

@Composable
private fun HeaderButton(icon: androidx.compose.ui.graphics.vector.ImageVector, contentDescription: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .size(40.dp)
            .clip(CircleShape)
            .background(Theme.glass.copy(alpha = 0.5f))
            .border(1.dp, Theme.accent, CircleShape)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Icon(icon, contentDescription = contentDescription, tint = Theme.accentText, modifier = Modifier.size(18.dp))
    }
}
