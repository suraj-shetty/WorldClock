package org.surajshetty.worldclockapp

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Easing
import androidx.compose.animation.core.animate
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Fill
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import kotlin.math.abs
import kotlin.math.roundToLong

enum class WheelStyle { Bottom, Inline }

private data class WheelMetrics(
    val ticksBottomInset: Float, val labelsBottomInset: Float,
    val caretTopInset: Float, val caretBottomInset: Float, val triangleTopInset: Float
) {
    companion object {
        val bottom = WheelMetrics(21f, 2f, 5f, 19f, 1f)
        val inline = WheelMetrics(19f, 0f, 3f, 17f, 0f)
    }
}

private val easeOutCubic = Easing { t -> 1f - (1f - t).let { it * it * it } }

/**
 * A tactile horizontal ruler: dragging slides the tape under a fixed center caret.
 * Ported from the iOS app's TimeWheelView — same drag-to-scrub-then-glide-and-snap
 * feel and tick/caret drawing math, mounted either as the global bottom bar or
 * inline inside a selected row.
 */
@Composable
fun TimeWheel(
    anchorNow: Instant,
    anchorZone: ZoneId,
    use24Hour: Boolean,
    style: WheelStyle,
    offset: Double,
    snapMinutes: Int,
    onOffsetChange: (Double) -> Unit,
    modifier: Modifier = Modifier
) {
    val density = LocalDensity.current
    val pixelsPerMinute = with(density) { 1.5.dp.toPx() }
    val limitSeconds = 48 * 3600.0
    val scope = rememberCoroutineScope()
    val metrics = if (style == WheelStyle.Bottom) WheelMetrics.bottom else WheelMetrics.inline
    val canvasHeight = if (style == WheelStyle.Bottom) 56.dp else 52.dp

    // `pointerInput(Unit)` launches its gesture-detection coroutine once and never
    // restarts it, so the drag closures below must read `offset` through this
    // (always-current) State rather than closing over the composable's parameter
    // directly — otherwise they'd keep using whatever `offset` was on first
    // composition.
    val currentOffset = rememberUpdatedState(offset)
    val dragStartOffset = remember { mutableFloatStateOf(0f) }
    val accumulatedDx = remember { mutableFloatStateOf(0f) }
    val velocityTracker = remember { VelocityTracker() }

    fun animateTo(target: Double) {
        scope.launch {
            animate(currentOffset.value.toFloat(), target.toFloat(), animationSpec = tween(500, easing = easeOutCubic)) { value, _ ->
                onOffsetChange(value.toDouble())
            }
        }
    }

    val content: @Composable () -> Unit = {
        Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            LabelRow(offset = offset, anchorZone = anchorZone, style = style, onNow = { animateTo(0.0) })

            Canvas(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(canvasHeight)
                    .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
                    .fadeMask(style)
                    .pointerInput(Unit) {
                        detectDragGestures(
                            onDragStart = {
                                dragStartOffset.floatValue = currentOffset.value.toFloat()
                                accumulatedDx.floatValue = 0f
                                velocityTracker.resetTracking()
                            },
                            onDrag = { change, dragAmount ->
                                velocityTracker.addPosition(change.uptimeMillis, change.position)
                                accumulatedDx.floatValue += dragAmount.x
                                val raw = dragStartOffset.floatValue - (accumulatedDx.floatValue / pixelsPerMinute) * 60
                                onOffsetChange(raw.toDouble().coerceIn(-limitSeconds, limitSeconds))
                            },
                            onDragEnd = {
                                val velocity = velocityTracker.calculateVelocity()
                                val flingSeconds = 0.3
                                // A flick's velocity projects a bit of extra glide before it
                                // settles — clamped well below the wheel's full 48h range so a
                                // fast flick can't coast absurdly far.
                                val projectedDelta = -(velocity.x / pixelsPerMinute) * 60 * flingSeconds
                                val maxGlide = 6 * 3600.0
                                val clampedGlide = projectedDelta.toDouble().coerceIn(-maxGlide, maxGlide)
                                val target = (currentOffset.value + clampedGlide).coerceIn(-limitSeconds, limitSeconds)
                                val snap = snapMinutes * 60.0
                                val snapped = (target / snap).roundToLong() * snap
                                animateTo(snapped)
                            }
                        )
                    }
            ) {
                drawWheel(
                    offset = offset, anchorNow = anchorNow, anchorZone = anchorZone,
                    use24Hour = use24Hour, metrics = metrics, pixelsPerMinute = pixelsPerMinute
                )
            }
        }
    }

    if (style == WheelStyle.Bottom) {
        Box(
            modifier = modifier
                .clip(RoundedCornerShape(Theme.Radius.bottomWheel))
                .background(Theme.glass.copy(alpha = 0.52f))
                .border(1.dp, Theme.text.copy(alpha = 0.12f), RoundedCornerShape(Theme.Radius.bottomWheel))
                .padding(vertical = 10.dp)
        ) { content() }
    } else {
        Box(modifier = modifier) { content() }
    }
}

@Composable
private fun LabelRow(offset: Double, anchorZone: ZoneId, style: WheelStyle, onNow: () -> Unit) {
    val homeLabel = TimeZoneCatalog.displayLabel(anchorZone.id)
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        BasicText(
            text = shiftedLabel(offset),
            style = TextStyle(color = Theme.accentText, fontSize = 10.5.sp, fontWeight = FontWeight.Medium, letterSpacing = 1.1.sp)
        )
        AnimatedVisibility(visible = offset != 0.0, enter = fadeIn(), exit = fadeOut()) {
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .border(1.dp, Theme.accent, RoundedCornerShape(50))
                    .clickable(onClick = onNow)
            ) {
                BasicText(
                    text = "NOW",
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
                    style = TextStyle(color = Theme.accentText, fontSize = 10.sp, fontWeight = FontWeight.Medium, letterSpacing = 1.sp)
                )
            }
        }
        if (offset == 0.0 && style == WheelStyle.Bottom) {
            BasicText(
                text = "Ticks in $homeLabel time",
                style = TextStyle(color = Theme.text.copy(alpha = 0.5f), fontSize = 10.5.sp)
            )
        }
    }
}

private fun shiftedLabel(offset: Double): String {
    val totalMinutes = (offset / 60).roundToLong()
    if (abs(totalMinutes) < 1) return "Now"
    val hours = totalMinutes / 60
    val minutes = abs(totalMinutes % 60)
    val sign = if (hours >= 0) "+" else "−"
    val magnitude = abs(hours)
    return if (minutes == 0L) "Shifted by $sign${magnitude}h" else "Shifted by $sign${magnitude}h ${minutes}m"
}

private fun DrawScope.drawWheel(
    offset: Double, anchorNow: Instant, anchorZone: ZoneId,
    use24Hour: Boolean, metrics: WheelMetrics, pixelsPerMinute: Float
) {
    val width = size.width
    val height = size.height
    val half = width / 2
    val display = anchorNow.plusNanos((offset * 1_000_000_000).toLong())

    val halfRangeMinutes = half / pixelsPerMinute + 25
    val halfRangeSeconds = halfRangeMinutes * 60
    val rangeStart = display.minusNanos((halfRangeSeconds * 1_000_000_000).toLong())
    val rangeEnd = display.plusNanos((halfRangeSeconds * 1_000_000_000).toLong())
    val startEpoch = Math.floorDiv(rangeStart.epochSecond, 300L) * 300L

    var tickEpoch = startEpoch
    while (tickEpoch <= rangeEnd.epochSecond) {
        val minutesFromCenter = (tickEpoch - display.epochSecond) / 60.0
        val x = half + (minutesFromCenter * pixelsPerMinute).toFloat()
        val d = abs(x - half)
        val near = (1 - d / 44f).coerceAtLeast(0f)
        val zdt = ZonedDateTime.ofInstant(Instant.ofEpochSecond(tickEpoch), anchorZone)
        val minute = zdt.minute
        val isHour = minute == 0
        val isHalf = isHour || minute == 30

        val tickHeight = if (isHour) 26f else if (isHalf) 16f else 9f
        val baseOpacity = if (isHour) 0.82f else if (isHalf) 0.56f else 0.32f
        val opacity = baseOpacity * (0.4f + 0.6f * (1 - d / half).coerceAtLeast(0f))
        val tickColor = if (near > 0.4f) Theme.accentLight else Theme.text
        val tickTop = height - metrics.ticksBottomInset - tickHeight
        drawRoundRect(
            color = tickColor.copy(alpha = opacity),
            topLeft = Offset(x - 0.75f, tickTop),
            size = Size(1.5f, tickHeight),
            cornerRadius = CornerRadius(1f, 1f)
        )

        if (isHalf) {
            val hour = zdt.hour
            val paint = android.graphics.Paint().apply {
                isAntiAlias = true
                textAlign = android.graphics.Paint.Align.CENTER
                textSize = with(this@drawWheel) { 10.sp.toPx() }
                color = Theme.text.copy(alpha = 0.42f + 0.58f * near).toArgb()
            }
            drawContext.canvas.nativeCanvas.drawText(
                tickLabel(hour, isHour, use24Hour), x, height - metrics.labelsBottomInset - 3, paint
            )
        }

        tickEpoch += 300L
    }

    val shiftMinutes = offset / 60
    val nowX = half - (shiftMinutes * pixelsPerMinute).toFloat()
    if (offset != 0.0 && nowX > 10 && nowX < width - 10) {
        drawRect(
            color = Theme.text.copy(alpha = 0.425f),
            topLeft = Offset(nowX - 0.5f, height - metrics.ticksBottomInset - 30),
            size = Size(1f, 30f)
        )
    }

    // Center caret: a glowing accent line plus a small downward-pointing triangle at its top.
    val caretTop = metrics.caretTopInset
    val caretHeight = height - metrics.caretTopInset - metrics.caretBottomInset
    drawRoundRect(
        color = Theme.accent,
        topLeft = Offset(half - 1f, caretTop),
        size = Size(2f, caretHeight),
        cornerRadius = CornerRadius(1f, 1f)
    )
    val triangle = Path().apply {
        moveTo(half - 4f, metrics.triangleTopInset)
        lineTo(half + 4f, metrics.triangleTopInset)
        lineTo(half, metrics.triangleTopInset + 5f)
        close()
    }
    drawPath(triangle, color = Theme.accent, style = Fill)
}

private fun tickLabel(hour: Int, isHour: Boolean, use24Hour: Boolean): String {
    if (use24Hour) return String.format("%02d:%02d", hour, if (isHour) 0 else 30)
    val hour12 = ((hour + 11) % 12) + 1
    return if (isHour) "$hour12 ${if (hour < 12) "AM" else "PM"}" else "$hour12:30"
}

/** Fades the wheel's ticks out toward its left/right edges — `BlendMode.DstIn`
 * multiplies the already-drawn content's alpha by this gradient's alpha channel,
 * matching the iOS app's `LinearGradient` mask. Needs the offscreen compositing
 * layer the caller sets via `graphicsLayer` for the blend mode to apply correctly
 * instead of blending straight onto whatever is behind it. */
private fun Modifier.fadeMask(style: WheelStyle): Modifier {
    val inset = if (style == WheelStyle.Bottom) 0.10f else 0.11f
    return this.drawWithContent {
        drawContent()
        drawRect(
            brush = Brush.horizontalGradient(
                0f to Color.Transparent, inset to Color.Black, (1 - inset) to Color.Black, 1f to Color.Transparent
            ),
            blendMode = BlendMode.DstIn
        )
    }
}
