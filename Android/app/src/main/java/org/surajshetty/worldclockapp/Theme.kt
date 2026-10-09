package org.surajshetty.worldclockapp

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/** Colors and constants from the "Nocturne" design system — ported 1:1 from the
 * iOS app's DesignSystem/Theme.swift so both platforms read as the same product. */
object Theme {
    val ground = Color(0xFF161826)

    val text = Color(0xFFE9E9ED)
    val textBright = Color(0xFFF3F5FE)
    val textBrightest = Color(0xFFF5F4FF)

    val accent = Color(0xFF9184D9) // center caret, selected row edge, glows
    val accentText = Color(0xFFB5ABFC) // accent-colored labels/icons on dark
    val accentLight = Color(0xFFC7C0FD) // near-center wheel ticks

    val glass = Color(0xFF121221) // collapsed row / bottom wheel base
    val glassExpanded = Color(0xFF10121E) // expanded row base

    val danger = Color(0xFFFF8A80) // delete action

    object Radius {
        val row = 14.dp
        val bottomWheel = 16.dp
    }

    object Spacing {
        val base = 16.dp
    }
}

/** The rounded glass card every list row, field and panel sits on. */
fun Modifier.card(fill: Color, stroke: Color, radius: Dp = Theme.Radius.row): Modifier {
    val shape = RoundedCornerShape(radius)
    return clip(shape).background(fill).border(1.dp, stroke, shape)
}

/** The round 40dp glass icon button used in every screen header. */
@Composable
fun CircleIconButton(icon: ImageVector, contentDescription: String?, onClick: () -> Unit) {
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
