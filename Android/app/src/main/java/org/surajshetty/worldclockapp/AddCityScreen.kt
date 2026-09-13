package org.surajshetty.worldclockapp

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * "Add a city" (multi-select: tap a row's "+" repeatedly, then Done) and "Choose
 * home city" (single-select: tap a row to choose and go back) — ported from the
 * iOS app's `AddTimeZoneView`, which doubles for both the same way.
 */
@Composable
fun AddCityScreen(
    kicker: String,
    title: String,
    isMultiSelect: Boolean,
    existingTimeZoneIds: Set<String>,
    homeZone: ZoneId,
    use24Hour: Boolean,
    now: Instant,
    onSelect: (timeZoneId: String, label: String) -> Unit,
    onDismiss: () -> Unit
) {
    var query by remember { mutableStateOf("") }
    var addedIds by remember { mutableStateOf(setOf<String>()) }

    val filtered = remember(query) {
        if (query.isBlank()) TimeZoneCatalog.allOptions
        else TimeZoneCatalog.allOptions.filter {
            it.label.contains(query, ignoreCase = true) || (it.country?.name?.contains(query, ignoreCase = true) == true)
        }
    }

    Box(modifier = Modifier.fillMaxSize().background(Theme.ground)) {
        Column(modifier = Modifier.fillMaxSize()) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = Theme.Spacing.base).padding(top = 12.dp),
                verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .background(Theme.glass.copy(alpha = 0.5f))
                        .border(1.dp, Theme.accent, CircleShape)
                        .clickable(onClick = onDismiss),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = Theme.accentText, modifier = Modifier.size(16.dp))
                }
                Column {
                    BasicText(kicker, style = TextStyle(color = Theme.accentText, fontSize = 10.5.sp, fontWeight = FontWeight.Medium, letterSpacing = 1.5.sp))
                    Spacer(Modifier.height(4.dp))
                    BasicText(title, style = TextStyle(color = Theme.text, fontSize = 29.sp, fontWeight = FontWeight.Medium, letterSpacing = (-0.5).sp))
                }
            }

            Spacer(Modifier.height(16.dp))

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Theme.Spacing.base)
                    .clip(RoundedCornerShape(14.dp))
                    .background(Theme.glass.copy(alpha = 0.5f))
                    .border(1.dp, Theme.accent.copy(alpha = 0.5f), RoundedCornerShape(14.dp))
                    .padding(horizontal = 14.dp, vertical = 11.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(modifier = Modifier.weight(1f)) {
                    if (query.isEmpty()) {
                        BasicText("City or country", style = TextStyle(color = Theme.text.copy(alpha = 0.4f), fontSize = 16.sp))
                    }
                    BasicTextField(
                        value = query, onValueChange = { query = it },
                        textStyle = TextStyle(color = Theme.textBright, fontSize = 16.sp),
                        cursorBrush = androidx.compose.ui.graphics.SolidColor(Theme.accent),
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }

            Spacer(Modifier.height(16.dp))

            LazyColumn(
                modifier = Modifier.weight(1f).fillMaxWidth(),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = Theme.Spacing.base, vertical = 4.dp)
            ) {
                items(filtered, key = { it.timeZoneId + it.label }) { option ->
                    val isAdded = isMultiSelect && (existingTimeZoneIds.contains(option.timeZoneId) || addedIds.contains(option.timeZoneId))
                    OptionRow(
                        option = option, homeZone = homeZone, use24Hour = use24Hour, now = now,
                        isMultiSelect = isMultiSelect, isAdded = isAdded,
                        onClick = {
                            if (isMultiSelect) {
                                if (!isAdded) {
                                    onSelect(option.timeZoneId, option.label)
                                    addedIds = addedIds + option.timeZoneId
                                }
                            } else {
                                onSelect(option.timeZoneId, option.label)
                                onDismiss()
                            }
                        }
                    )
                    Spacer(Modifier.height(10.dp))
                }
            }

            if (isMultiSelect) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = Theme.Spacing.base, vertical = Theme.Spacing.base)
                        .clip(RoundedCornerShape(14.dp))
                        .border(1.dp, Theme.accent, RoundedCornerShape(14.dp))
                        .clickable(onClick = onDismiss)
                        .padding(vertical = 14.dp),
                    contentAlignment = Alignment.Center
                ) {
                    BasicText("Done", style = TextStyle(color = Theme.accentText, fontSize = 17.sp, fontWeight = FontWeight.Medium))
                }
            }
        }
    }
}

@Composable
private fun OptionRow(
    option: TimeZoneOption, homeZone: ZoneId, use24Hour: Boolean, now: Instant,
    isMultiSelect: Boolean, isAdded: Boolean, onClick: () -> Unit
) {
    val zone = remember(option.timeZoneId) { runCatching { ZoneId.of(option.timeZoneId) }.getOrDefault(ZoneId.systemDefault()) }
    val zdt = ZonedDateTime.ofInstant(now, zone)
    val time = formatOptionTime(zdt, use24Hour)
    val subtitle = remember(option.timeZoneId, homeZone) { optionSubtitle(option, zone, homeZone, now) }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Theme.glass.copy(alpha = 0.48f))
            .border(1.dp, Theme.text.copy(alpha = 0.13f), RoundedCornerShape(14.dp))
            .clickable(enabled = !isAdded || !isMultiSelect, onClick = onClick)
            .padding(horizontal = 15.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        option.country?.let {
            BasicText(it.flag, style = TextStyle(fontSize = 22.sp))
        }
        Column(modifier = Modifier.weight(1f)) {
            BasicText(option.label, style = TextStyle(color = Theme.textBright, fontSize = 17.sp, fontWeight = FontWeight.Medium))
            BasicText(subtitle, style = TextStyle(color = Theme.text.copy(alpha = 0.6f), fontSize = 13.sp))
        }
        BasicText(
            text = time,
            style = TextStyle(color = Theme.textBright, fontSize = 18.sp, fontWeight = FontWeight.Medium)
        )
        if (isMultiSelect) {
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .clip(CircleShape)
                    .background(Theme.glass.copy(alpha = 0.5f))
                    .border(1.dp, if (isAdded) Theme.accent.copy(alpha = 0.3f) else Theme.accent, CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    if (isAdded) Icons.Default.Check else Icons.Default.Add,
                    contentDescription = null,
                    tint = if (isAdded) Theme.accent.copy(alpha = 0.6f) else Theme.accentText,
                    modifier = Modifier.size(14.dp)
                )
            }
        }
    }
}

private fun formatOptionTime(zdt: ZonedDateTime, use24Hour: Boolean): String {
    if (use24Hour) return String.format("%02d:%02d", zdt.hour, zdt.minute)
    val displayHour = if (zdt.hour % 12 == 0) 12 else zdt.hour % 12
    val period = if (zdt.hour < 12) "AM" else "PM"
    return String.format("%d:%02d %s", displayHour, zdt.minute, period)
}

private fun optionSubtitle(option: TimeZoneOption, zone: ZoneId, homeZone: ZoneId, now: Instant): String {
    val homeOffset = homeZone.rules.getOffset(now).totalSeconds
    val zoneOffset = zone.rules.getOffset(now).totalSeconds
    val diffMinutes = (zoneOffset - homeOffset) / 60
    val offsetText = if (diffMinutes == 0) {
        "Home"
    } else {
        val sign = if (diffMinutes > 0) "+" else "−"
        val magnitude = kotlin.math.abs(diffMinutes)
        val hours = magnitude / 60
        val minutes = magnitude % 60
        val tenths = Math.round(minutes / 6.0)
        if (minutes == 0) "$sign${hours}h" else "$sign$hours.${tenths}h"
    }
    val countryName = option.country?.name
    return listOfNotNull(countryName, offsetText).joinToString(" · ")
}
