package org.surajshetty.worldclockapp

import androidx.compose.ui.graphics.Color
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
        val xs = 4.dp
        val sm = 8.dp
        val md = 12.dp
        val base = 16.dp
        val lg = 20.dp
    }
}
