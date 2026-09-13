package org.surajshetty.worldclockapp

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * A single city card — ported from the iOS app's `ClockRow`. Collapsed, it shows
 * label/subtitle/time; tapping expands it in place to show its own inline scrub
 * wheel and a delete action, and collapses everything else that was expanded
 * (there's only ever one selected row on the whole board).
 */
@Composable
fun ClockRow(
    entry: ClockEntry,
    now: Instant,
    offset: Double,
    isSelected: Boolean,
    use24Hour: Boolean,
    showCountryName: Boolean,
    flagNextDayCities: Boolean,
    homeZone: ZoneId,
    snapMinutes: Int,
    onSelect: () -> Unit,
    onOffsetChange: (Double) -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier
) {
    val entryZone = remember(entry.timeZoneId) { runCatching { ZoneId.of(entry.timeZoneId) }.getOrDefault(ZoneId.systemDefault()) }
    val displayInstant = now.plusNanos((offset * 1_000_000_000).toLong())
    val zdt = ZonedDateTime.ofInstant(displayInstant, entryZone)

    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(Theme.Radius.row))
            .background(if (isSelected) Theme.glassExpanded.copy(alpha = 0.74f) else Theme.glass.copy(alpha = 0.48f))
            .border(
                width = 1.dp,
                color = if (isSelected) Theme.accent else Theme.text.copy(alpha = 0.13f),
                shape = RoundedCornerShape(Theme.Radius.row)
            )
            .clickable(onClick = onSelect)
            .animateContentSize(animationSpec = tween(300))
            .padding(horizontal = 15.dp, vertical = if (isSelected) 15.dp else 14.dp)
    ) {
        Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                    if (isSelected) {
                        Box(
                            modifier = Modifier
                                .size(5.dp)
                                .clip(RoundedCornerShape(50))
                                .background(Theme.accent)
                        )
                    }
                    BasicText(
                        text = entry.label,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        style = TextStyle(
                            color = if (isSelected) Theme.textBright else Theme.text,
                            fontSize = 22.sp, fontWeight = FontWeight.Bold, letterSpacing = (-0.19).sp
                        )
                    )
                }
                Spacer(Modifier.height(3.dp))
                BasicText(
                    text = subtitle(entry, entryZone, homeZone, displayInstant, showCountryName, flagNextDayCities),
                    style = TextStyle(color = Theme.text.copy(alpha = if (isSelected) 0.62f else 0.6f), fontSize = 14.sp, fontWeight = FontWeight.Medium)
                )
            }

            val time = formatTime(zdt, use24Hour)
            Row(verticalAlignment = Alignment.Bottom) {
                BasicText(
                    text = time.first,
                    style = TextStyle(color = if (isSelected) Theme.textBrightest else Theme.textBright, fontSize = (if (isSelected) 41 else 33).sp, fontWeight = FontWeight.Medium)
                )
                if (time.second.isNotEmpty()) {
                    BasicText(
                        text = " " + time.second,
                        style = TextStyle(color = if (isSelected) Theme.textBrightest else Theme.textBright, fontSize = (if (isSelected) 13 else 12).sp, fontWeight = FontWeight.Medium)
                    )
                }
            }
        }

        AnimatedVisibility(visible = isSelected, enter = fadeIn(), exit = fadeOut()) {
            Column {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 13.dp, bottom = 9.dp)
                        .height(1.dp)
                        .background(
                            Brush.horizontalGradient(
                                0f to androidx.compose.ui.graphics.Color.Transparent,
                                0.18f to Theme.accent.copy(alpha = 0.55f),
                                0.82f to Theme.accent.copy(alpha = 0.55f),
                                1f to androidx.compose.ui.graphics.Color.Transparent
                            )
                        )
                )

                TimeWheel(
                    anchorNow = now, anchorZone = entryZone, use24Hour = use24Hour,
                    style = WheelStyle.Inline, offset = offset, snapMinutes = snapMinutes,
                    onOffsetChange = onOffsetChange
                )

                Row(modifier = Modifier.fillMaxWidth().padding(top = 14.dp), horizontalArrangement = Arrangement.End) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        modifier = Modifier.clickable(onClick = onDelete)
                    ) {
                        Icon(Icons.Default.Delete, contentDescription = null, tint = Theme.danger, modifier = Modifier.size(15.dp))
                        BasicText("Delete City", style = TextStyle(color = Theme.danger, fontSize = 13.sp, fontWeight = FontWeight.Medium))
                    }
                }
            }
        }
    }
}

private fun formatTime(zdt: ZonedDateTime, use24Hour: Boolean): Pair<String, String> {
    if (use24Hour) return String.format("%02d:%02d", zdt.hour, zdt.minute) to ""
    val displayHour = if (zdt.hour % 12 == 0) 12 else zdt.hour % 12
    return String.format("%d:%02d", displayHour, zdt.minute) to (if (zdt.hour < 12) "AM" else "PM")
}

private fun deltaLabel(homeZone: ZoneId, entryZone: ZoneId, at: Instant): String {
    val homeOffsetSeconds = homeZone.rules.getOffset(at).totalSeconds
    val entryOffsetSeconds = entryZone.rules.getOffset(at).totalSeconds
    val diffMinutes = (entryOffsetSeconds - homeOffsetSeconds) / 60
    if (diffMinutes == 0) return "Home"
    val sign = if (diffMinutes > 0) "+" else "−"
    val magnitude = kotlin.math.abs(diffMinutes)
    val hours = magnitude / 60
    val minutes = magnitude % 60
    val tenths = Math.round(minutes / 6.0)
    return if (minutes == 0) "$sign${hours}h" else "$sign$hours.${tenths}h"
}

private fun isNextDay(homeZone: ZoneId, entryZone: ZoneId, at: Instant): Boolean {
    val homeDay = at.atZone(homeZone).toLocalDate()
    val entryDay = at.atZone(entryZone).toLocalDate()
    return entryDay.isAfter(homeDay)
}

private fun subtitle(
    entry: ClockEntry, entryZone: ZoneId, homeZone: ZoneId, at: Instant,
    showCountryName: Boolean, flagNextDayCities: Boolean
): String {
    val parts = mutableListOf<String>()
    if (showCountryName) {
        CountryLookup.lookup(entry.timeZoneId)?.let { parts.add("${it.flag} ${it.name}") }
    }
    parts.add(deltaLabel(homeZone, entryZone, at))
    if (flagNextDayCities && isNextDay(homeZone, entryZone, at)) parts.add("Next day")
    return parts.joinToString(" · ")
}
