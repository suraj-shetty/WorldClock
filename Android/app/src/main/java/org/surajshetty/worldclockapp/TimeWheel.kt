package org.surajshetty.worldclockapp

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Easing
import androidx.compose.animation.core.animate
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
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
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
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

/** Ticks within this many px of the center caret get the "near" accent treatment
 * (brighter color, taller mark) instead of the ambient fade. */
private const val nearCaretRadiusPx = 44f

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
    val scope = rememberCoroutineScope()
    val metrics = if (style == WheelStyle.Bottom) WheelMetrics.bottom else WheelMetrics.inline
    val canvasHeight = if (style == WheelStyle.Bottom) 56.dp else 52.dp

    // The drag callbacks outlive a single composition, so they read `offset` through
    // this always-current State. `dragOffset` accumulates the drag itself, since
    // several drag events can land before `offset` recomposes back down.
    val currentOffset = rememberUpdatedState(offset)
    val dragOffset = remember { mutableDoubleStateOf(0.0) }

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
                    .semantics { contentDescription = "Time scrub wheel: ${shiftedLabel(offset)}" }
                    .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
                    .fadeMask(style)
                    .draggable(
                        state = rememberDraggableState { dx ->
                            dragOffset.doubleValue -= dx / pixelsPerMinute * 60.0
                            onOffsetChange(dragOffset.doubleValue)
                        },
                        orientation = Orientation.Horizontal,
                        onDragStarted = { dragOffset.doubleValue = currentOffset.value },
                        onDragStopped = { velocity ->
                            // A flick's velocity projects a bit of extra glide before it
                            // settles — the drag itself is unbounded (scrub as many days
                            // forward/back as you like), but the glide is capped so a fast
                            // flick can't coast absurdly far past where the finger let go.
                            val flingSeconds = 0.3
                            val maxGlide = 6 * 3600.0
                            val glide = (-(velocity / pixelsPerMinute) * 60 * flingSeconds).toDouble().coerceIn(-maxGlide, maxGlide)
                            val snap = snapMinutes * 60.0
                            animateTo(((currentOffset.value + glide) / snap).roundToLong() * snap)
                        }
                    )
            ) {
                drawWheel(
                    offset = offset, anchorNow = anchorNow, anchorZone = anchorZone,
                    use24Hour = use24Hour, metrics = metrics, pixelsPerMinute = pixelsPerMinute
                )
            }
        }
    }

    // Only the bottom-bar mount has its own glass chrome; inline sits in its row.
    val chrome = if (style == WheelStyle.Bottom) {
        Modifier.card(Theme.glass.copy(alpha = 0.52f), Theme.text.copy(alpha = 0.12f), Theme.Radius.bottomWheel).padding(vertical = 10.dp)
    } else Modifier
    Box(modifier.then(chrome)) { content() }
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
                    .clip(CircleShape)
                    .border(1.dp, Theme.accent, CircleShape)
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

internal fun shiftedLabel(offset: Double): String {
    val totalMinutes = (offset / 60).roundToLong()
    if (abs(totalMinutes) < 1) return "Now"
    val hours = totalMinutes / 60
    val minutes = abs(totalMinutes % 60)
    val sign = if (totalMinutes >= 0) "+" else MINUS_SIGN
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

    val labelPaint = android.graphics.Paint().apply {
        isAntiAlias = true
        textAlign = android.graphics.Paint.Align.CENTER
        textSize = with(this@drawWheel) { 10.sp.toPx() }
    }

    var tickEpoch = startEpoch
    while (tickEpoch <= rangeEnd.epochSecond) {
        val minutesFromCenter = (tickEpoch - display.epochSecond) / 60.0
        val x = half + (minutesFromCenter * pixelsPerMinute).toFloat()
        val d = abs(x - half)
        val near = (1 - d / nearCaretRadiusPx).coerceAtLeast(0f)
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
            labelPaint.color = Theme.text.copy(alpha = 0.42f + 0.58f * near).toArgb()
            drawContext.canvas.nativeCanvas.drawText(
                tickLabel(hour, isHour, use24Hour), x, height - metrics.labelsBottomInset - 3, labelPaint
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
