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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** Ported from the iOS app's `SettingsView`: Home card, Clock toggles, Scrub-snap
 * segmented control, About section. */
@Composable
fun SettingsScreen(
    viewModel: ClockViewModel,
    onOpenHomePicker: () -> Unit,
    onDismiss: () -> Unit
) {
    val settings = viewModel.settings
    val context = LocalContext.current
    val versionName = remember(context) {
        runCatching { context.packageManager.getPackageInfo(context.packageName, 0).versionName }.getOrNull() ?: "1.0"
    }

    Column(modifier = Modifier.fillMaxSize().background(Theme.ground).statusBarsPadding().navigationBarsPadding()) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = Theme.Spacing.base).padding(top = 12.dp, bottom = 8.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Box(
                modifier = Modifier.size(40.dp).clip(CircleShape).background(Theme.glass.copy(alpha = 0.5f))
                    .border(1.dp, Theme.accent, CircleShape).clickable(onClick = onDismiss),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = Theme.accentText, modifier = Modifier.size(16.dp))
            }
            BasicText("Settings", style = TextStyle(color = Theme.text, fontSize = 29.sp, fontWeight = FontWeight.Medium, letterSpacing = (-0.5).sp))
        }

        LazyColumn(
            modifier = Modifier.weight(1f).fillMaxWidth(),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(Theme.Spacing.base)
        ) {
            item { SectionLabel("HOME") }
            item {
                val homeCountry = CountryLookup.lookup(viewModel.homeTimeZone.id)
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(14.dp))
                        .background(Theme.glass.copy(alpha = 0.5f))
                        .border(1.dp, Theme.accent.copy(alpha = 0.5f), RoundedCornerShape(14.dp))
                        .clickable(onClick = onOpenHomePicker)
                        .padding(15.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    homeCountry?.let { BasicText(it.flag, style = TextStyle(fontSize = 22.sp)) }
                    Column(modifier = Modifier.weight(1f)) {
                        BasicText(
                            viewModel.homeTimeZoneLabel,
                            style = TextStyle(color = Theme.textBright, fontSize = 18.sp, fontWeight = FontWeight.Medium)
                        )
                        val suffix = "all offsets are measured from here"
                        BasicText(
                            listOfNotNull(homeCountry?.name, suffix).joinToString(" · "),
                            style = TextStyle(color = Theme.text.copy(alpha = 0.62f), fontSize = 13.sp)
                        )
                    }
                    Icon(Icons.Default.ChevronRight, contentDescription = null, tint = Theme.text.copy(alpha = 0.5f), modifier = Modifier.size(16.dp))
                }
                Spacer(Modifier.height(28.dp))
            }

            item { SectionLabel("CLOCK") }
            item {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    ToggleRow("Use 24-hour time", "Times and wheel ticks read 18:30 instead of 6:30 PM.", settings.use24Hour) {
                        viewModel.updateSettings { s -> s.copy(use24Hour = it) }
                    }
                    ToggleRow("Show country name", "Adds the country beside each city's offset.", settings.showCountryName) {
                        viewModel.updateSettings { s -> s.copy(showCountryName = it) }
                    }
                    ToggleRow("Animate the sky", "The illustration follows the scrubbed time as you drag.", settings.animateSky) {
                        viewModel.updateSettings { s -> s.copy(animateSky = it) }
                    }
                    ToggleRow("Flag next-day cities", "Marks rows whose local date is ahead of home.", settings.flagNextDayCities) {
                        viewModel.updateSettings { s -> s.copy(flagNextDayCities = it) }
                    }
                }
                Spacer(Modifier.height(28.dp))
            }

            item { SectionLabel("SCRUB SNAPS TO") }
            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(14.dp))
                        .background(Theme.glass.copy(alpha = 0.5f))
                        .border(1.dp, Theme.text.copy(alpha = 0.13f), RoundedCornerShape(14.dp))
                        .padding(6.dp),
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    listOf(15, 30, 60).forEach { minutes ->
                        val isSelected = settings.snapMinutes == minutes
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .clip(RoundedCornerShape(10.dp))
                                .background(if (isSelected) Theme.accent.copy(alpha = 0.28f) else androidx.compose.ui.graphics.Color.Transparent)
                                .clickable { viewModel.updateSettings { s -> s.copy(snapMinutes = minutes) } }
                                .padding(vertical = 9.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            BasicText(
                                "$minutes min",
                                style = TextStyle(
                                    color = if (isSelected) Theme.textBrightest else Theme.text.copy(alpha = 0.66f),
                                    fontSize = 15.sp, fontWeight = FontWeight.Medium, textAlign = TextAlign.Center
                                )
                            )
                        }
                    }
                }
                Spacer(Modifier.height(28.dp))
            }

            item { SectionLabel("ABOUT") }
            item {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    InfoRow("Version", versionName)
                    InfoRow("Time zone data", "IANA (platform)")
                }
            }
        }
    }
}

@Composable
private fun SectionLabel(text: String) {
    BasicText(
        text, style = TextStyle(color = Theme.accentText, fontSize = 12.sp, fontWeight = FontWeight.Medium, letterSpacing = 1.2.sp)
    )
    Spacer(Modifier.height(10.dp))
}

@Composable
private fun ToggleRow(title: String, subtitle: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Theme.glass.copy(alpha = 0.5f))
            .border(1.dp, Theme.text.copy(alpha = 0.13f), RoundedCornerShape(14.dp))
            .padding(15.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            BasicText(title, style = TextStyle(color = Theme.textBright, fontSize = 17.sp, fontWeight = FontWeight.Medium))
            BasicText(subtitle, style = TextStyle(color = Theme.text.copy(alpha = 0.62f), fontSize = 13.sp))
        }
        Switch(
            checked = checked, onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(checkedTrackColor = Theme.accent)
        )
    }
}

@Composable
private fun InfoRow(title: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Theme.glass.copy(alpha = 0.5f))
            .border(1.dp, Theme.text.copy(alpha = 0.13f), RoundedCornerShape(14.dp))
            .padding(15.dp),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        BasicText(title, style = TextStyle(color = Theme.textBright, fontSize = 16.sp, fontWeight = FontWeight.Medium))
        BasicText(value, style = TextStyle(color = Theme.text.copy(alpha = 0.6f), fontSize = 15.sp))
    }
}
