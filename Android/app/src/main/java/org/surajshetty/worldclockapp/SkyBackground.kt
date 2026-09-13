package org.surajshetty.worldclockapp

import android.graphics.BlurMaskFilter
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Paint
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.asAndroidPath
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlin.math.min
import kotlin.math.sin

/**
 * Full-bleed sky illustration keyed to `hour` (0..<24, fractional, in whichever
 * timezone is the active anchor) — ported from the iOS app's BackgroundView.swift.
 *
 * Three layers, like the iOS version, so only the star field's twinkle needs to
 * tick continuously: the gradient and the (expensive, blur-heavy) foreground redraw
 * only when `hour` itself changes.
 */
@Composable
fun SkyBackground(hour: Double, modifier: Modifier = Modifier) {
    val animatedHour by animateFloatAsState(
        targetValue = hour.toFloat(),
        animationSpec = tween(300, easing = FastOutSlowInEasing),
        label = "skyHour"
    )
    val h = animatedHour.toDouble()
    Box(modifier = modifier) {
        SkyGradientLayer(h, Modifier)
        SkyStarLayer(h, Modifier)
        SkyForegroundLayer(h, Modifier)
    }
}

@Composable
private fun SkyGradientLayer(hour: Double, modifier: Modifier) {
    Canvas(modifier = modifier.fillMaxSize()) {
        val p = skyPalette(normalizedHour(hour))
        drawRect(
            brush = Brush.linearGradient(
                0f to p.top, 0.30f to p.up, 0.62f to p.mid, 1.0f to p.hz,
                start = Offset(0f, 0f), end = Offset(0f, size.height)
            )
        )
    }
}

@Composable
private fun SkyStarLayer(hour: Double, modifier: Modifier) {
    var tick by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) {
        while (isActive) {
            delay(100)
            tick++
        }
    }
    Canvas(modifier = modifier.fillMaxSize()) {
        // Read `tick` so this Canvas recomposes every 100ms without needing the
        // twinkle phase to live anywhere else.
        @Suppress("UNUSED_EXPRESSION") tick
        val p = skyPalette(normalizedHour(hour))
        if (p.star <= 0.01) return@Canvas
        val scaleFactor = min(size.width, size.height) / 390f
        val elapsed = System.nanoTime() / 1_000_000_000.0
        for (star in skyStars) {
            val twinkle = (sin(elapsed * (2 * Math.PI / star.dur) + star.delay) + 1) / 2
            val alpha = (star.baseBrightness * p.star * (0.35 + 0.65 * twinkle)).toFloat().coerceIn(0f, 1f)
            val point = Offset((star.x / 100 * size.width).toFloat(), (star.y / 100 * size.height).toFloat())
            val d = (star.d * scaleFactor).toFloat()
            drawCircle(color = Color(0xFFF3F5FE), radius = d / 2, center = point, alpha = alpha)
        }
    }
}

@Composable
private fun SkyForegroundLayer(hour: Double, modifier: Modifier) {
    Canvas(modifier = modifier.fillMaxSize()) {
        drawForeground(normalizedHour(hour))
    }
}

private fun DrawScope.drawForeground(h: Double) {
    val p = skyPalette(h)
    val w = size.width
    val ht = size.height
    val scaleF = min(w, ht) / 390f

    // Sun rides 5:40->19:00 (opacity ramps 4.9-6.0 in, 18.1-19.4 out); moon 18:20->6:20,
    // continuous across midnight via `hh`.
    val sunT = clamp01((h - 6) / 12)
    val sunUp = sin(sunT * Math.PI)
    val sunO = min(ramp(h, 4.9, 6.0), 1 - ramp(h, 18.1, 19.4))
    val hh = if (h < 12) h + 24 else h
    val moonT = clamp01((hh - 18) / 12)
    val moonUp = sin(moonT * Math.PI)
    val moonO = min(ramp(hh, 18.4, 20.2), 1 - ramp(hh, 27.4, 29.0))

    val sunHi = Color(0xFFFFFAF0)
    val sunBody = lerpColor(Color(0xFFF6D9B4), Color(0xFFF9F2E0), sunUp)
    val sunEdge = lerpColor(Color(0xFFE5A274), Color(0xFFF2E2C0), sunUp)
    val sunX = 10 + sunT * 80
    val sunY = 80 - sunUp * 68
    val sunW = 7 + (1 - sunUp) * 6.5

    val moonHi = Color(0xFFF7F6FF)
    val moonBody = Color(0xFFDCD9F0)
    val moonEdge = Color(0xFFA9A3C9)
    val moonX = 10 + moonT * 80
    val moonY = 80 - moonUp * 66
    val moonW = 5.4 + (1 - moonUp) * 2.6

    // Blooms — horizon bloom first, then the soft halos riding with each disc.
    drawBloom(x = 50.0, y = 104.0, wPercent = 190.0, color = p.hz, colorOpacity = 0.7, opacity = 0.5)
    if (sunO > 0.01) {
        drawBloom(
            x = sunX, y = sunY + 3, wPercent = 130.0,
            color = lerpColor(Color(0xFFE08F63), Color(0xFFF4E8CC), sunUp), colorOpacity = 0.55,
            opacity = sunO * (0.34 + (1 - sunUp) * 0.3)
        )
    }
    if (moonO > 0.01) {
        drawBloom(x = moonX, y = moonY, wPercent = 70.0, color = skyAccent, colorOpacity = 0.5, opacity = moonO * 0.28)
    }

    // Sun / moon discs, each with its own tight glow.
    drawDisc(
        x = sunX, y = sunY, wPercent = sunW, opacity = sunO,
        highlight = sunHi, body = sunBody, edge = sunEdge,
        glowColor = lerpColor(Color(0xFFE08F63), Color(0xFFF6E6C4), sunUp), glowOpacity = 0.30 + (1 - sunUp) * 0.22,
        glowBlur = (52 + (1 - sunUp) * 68) * scaleF, glowSpread = (8 + (1 - sunUp) * 16) * scaleF
    )
    drawDisc(
        x = moonX, y = moonY, wPercent = moonW, opacity = moonO,
        highlight = moonHi, body = moonBody, edge = moonEdge,
        glowColor = skyAccent, glowOpacity = 0.34, glowBlur = 46.0 * scaleF, glowSpread = 6.0 * scaleF
    )

    // Clouds, tinted warm toward the sun's highlight as it rises.
    val lightC = lerpColor(p.cloudTint, sunHi, (sunO * 0.35 * sunUp))
    for (cloud in skyCloudBases) {
        drawCloud(
            x = cloud.x, y = cloud.y, wPercent = cloud.w, hPercent = cloud.h,
            blur = cloud.blur * scaleF, opacity = p.cloudAlpha * cloud.o, color = lightC
        )
    }

    // Atmospheric haze — bottom 34%.
    val hazeTop = ht * 0.66f
    val hazeRect = androidx.compose.ui.geometry.Rect(0f, hazeTop, w, ht)
    drawRect(
        brush = Brush.linearGradient(
            0f to p.haze.copy(alpha = 0f), 0.55f to p.haze.copy(alpha = 0.3f), 1f to p.haze.copy(alpha = 0.62f),
            start = Offset(0f, hazeRect.top), end = Offset(0f, hazeRect.bottom)
        ),
        topLeft = Offset(hazeRect.left, hazeRect.top),
        size = Size(hazeRect.width, hazeRect.height)
    )

    // Terrain — mountain ridges, ground, lake with reflection, mist.
    val lit = maxOf(sunO * sunUp, moonO * moonUp * 0.45)
    val domX = if (sunO >= moonO) sunX else moonX
    drawTerrain(p, lit, sunBody, moonBody, sunO, moonO, domX, scaleF)
}

private fun DrawScope.drawBloom(x: Double, y: Double, wPercent: Double, color: Color, colorOpacity: Double, opacity: Double) {
    if (opacity <= 0.005) return
    val d = (wPercent / 100 * size.width).toFloat()
    val cx = (x / 100 * size.width).toFloat()
    val cy = (y / 100 * size.height).toFloat()
    val brush = Brush.radialGradient(
        0f to color.copy(alpha = colorOpacity.toFloat()),
        0.7f to color.copy(alpha = 0f),
        center = Offset(cx, cy), radius = d / 2
    )
    drawCircle(brush = brush, radius = d / 2, center = Offset(cx, cy), alpha = opacity.toFloat())
}

/**
 * A radial gradient standing in for a Gaussian blur — reproducing the actual CSS
 * box-shadow math (a disc of radius R blurred by a Gaussian of sigma = blur/2) via
 * an erfc-shaped falloff, exactly as the iOS app does, rather than an approximated
 * blur filter.
 */
private fun DrawScope.drawDisc(
    x: Double, y: Double, wPercent: Double, opacity: Double,
    highlight: Color, body: Color, edge: Color,
    glowColor: Color, glowOpacity: Double, glowBlur: Double, glowSpread: Double
) {
    if (opacity <= 0.005) return
    val d = (wPercent / 100 * size.width)
    val cx = (x / 100 * size.width).toFloat()
    val cy = (y / 100 * size.height).toFloat()

    val edgeRadius = d / 2 + glowSpread
    val sigma = maxOf(glowBlur / 2, 0.01)
    val maxRadius = edgeRadius + 4 * sigma
    val stopCount = 16
    val stops = Array(stopCount + 1) { i ->
        val t = i.toDouble() / stopCount
        val r = t * maxRadius
        val alpha = 0.5 * erfc((r - edgeRadius) / (sigma * 1.4142135623730951))
        t.toFloat() to glowColor.copy(alpha = (glowOpacity * alpha).toFloat().coerceIn(0f, 1f))
    }
    val glowBrush = Brush.radialGradient(*stops, center = Offset(cx, cy), radius = maxRadius.toFloat())
    drawCircle(brush = glowBrush, radius = maxRadius.toFloat(), center = Offset(cx, cy), alpha = opacity.toFloat())

    val gradCenter = Offset(cx - (d / 2).toFloat() + (d * 0.36).toFloat(), cy - (d / 2).toFloat() + (d * 0.32).toFloat())
    val bodyBrush = Brush.radialGradient(
        0f to highlight, 0.55f to body, 1f to edge,
        center = gradCenter, radius = (d * 0.72).toFloat()
    )
    drawCircle(brush = bodyBrush, radius = (d / 2).toFloat(), center = Offset(cx, cy), alpha = opacity.toFloat())
}

/**
 * CSS `radial-gradient(closest-side at 46% 58%, ...)`: an off-center ellipse whose
 * radius on each axis is the distance from that center to the *nearer* edge on that
 * axis. Drawn as a solid soft-edged oval rather than the iOS gradient-in-a-scaled-
 * unit-circle — combined with the heavy blur every cloud already has, a true
 * elliptical gradient wouldn't read as visually different, and skipping the scale
 * transform avoids BlurMaskFilter's blur radius warping non-uniformly under it.
 */
private fun DrawScope.drawCloud(x: Double, y: Double, wPercent: Double, hPercent: Double, blur: Double, opacity: Double, color: Color) {
    if (opacity <= 0.005) return
    val w = (wPercent / 100 * size.width)
    val h = (hPercent / 100 * size.height)
    val centerX = (x / 100 * size.width)
    val centerY = (y / 100 * size.height)
    val offsetX = (0.46 - 0.5) * w
    val offsetY = (0.58 - 0.5) * h
    val radiusX = w / 2 - kotlin.math.abs(offsetX)
    val radiusY = h / 2 - kotlin.math.abs(offsetY)
    val cx = (centerX + offsetX).toFloat()
    val cy = (centerY + offsetY).toFloat()

    val path = Path().apply {
        addOval(androidx.compose.ui.geometry.Rect(cx - radiusX.toFloat(), cy - radiusY.toFloat(), cx + radiusX.toFloat(), cy + radiusY.toFloat()))
    }
    drawBlurredPath(path, SolidColor(color.copy(alpha = 0.55f)), blur.toFloat(), opacity.toFloat())
}

private fun DrawScope.drawTerrain(
    p: SkyPalette, lit: Double, sunColor: Color, moonColor: Color, sunO: Double, moonO: Double, domX: Double, scaleF: Float
) {
    val w = size.width
    val ht = size.height

    for (ridge in ridgeShapes) {
        val top = ht - ht * ((ridge.bottomPercent + ridge.heightPercent) / 100).toFloat()
        val rect = androidx.compose.ui.geometry.Rect(-0.02f * w, top, 1.02f * w, top + ht * (ridge.heightPercent / 100).toFloat())
        val cTop = lerpColor(lerpColor(p.hz, Color.White, (0.10 * (1 - ridge.ink) + lit * 0.12)), skyInk, ridge.ink * 0.72)
        val cMid = lerpColor(p.hz, skyInk, ridge.ink)
        val cBot = lerpColor(p.mid, skyInk, minOf(1.0, ridge.ink + 0.12))
        val path = ridgePath(ridge.points, rect)
        val brush = Brush.linearGradient(
            0f to cTop, 0.38f to cMid, 1f to cBot,
            start = Offset(0f, rect.top), end = Offset(0f, rect.bottom)
        )
        if (ridge.blur > 0.01) {
            drawBlurredPath(path, brush, (ridge.blur * scaleF).toFloat(), 1f)
        } else {
            drawPath(path, brush = brush)
        }
    }

    // Ground band.
    val groundTop = ht * 0.76f
    drawRect(
        brush = Brush.linearGradient(
            0f to p.mid.copy(alpha = 0f), 0.28f to lerpColor(p.mid, skyInk, 0.88), 1f to lerpColor(p.mid, skyInk, 0.95),
            start = Offset(0f, groundTop), end = Offset(0f, ht)
        ),
        topLeft = Offset(0f, groundTop), size = Size(w, ht - groundTop)
    )

    // Lake — clipped to a soft irregular shoreline on its top edge only.
    val waterTop = ht * (1 - (waterHeightPercent / 100)).toFloat()
    val waterRect = androidx.compose.ui.geometry.Rect(0f, waterTop, w, ht)
    val surface = lerpColor(p.hz, p.mid, 0.35)
    val waterFar = lerpColor(surface, skyInk, 0.6)
    val waterNear = lerpColor(surface, skyInk, 0.5)
    val domColor = if (sunO >= moonO) sunColor else moonColor

    clipPath(ridgePath(shorelinePoints, waterRect)) {
        drawRect(
            brush = Brush.linearGradient(listOf(waterFar, waterNear), start = Offset(0f, waterRect.top), end = Offset(0f, waterRect.bottom)),
            topLeft = Offset(waterRect.left, waterRect.top), size = Size(waterRect.width, waterRect.height)
        )

        ridgeShapes.forEachIndexed { i, ridge ->
            val reflHeightPercent = ridge.heightPercent * 0.55 / waterHeightPercent * 100
            val reflRect = androidx.compose.ui.geometry.Rect(
                -0.02f * w, waterRect.top, 1.02f * w, waterRect.top + waterRect.height * (reflHeightPercent / 100).toFloat()
            )
            val mirrored = ridge.points.map { (x, y) -> x to (100 - y) }
            val color = lerpColor(waterFar, skyInk, 0.18 + i * 0.16)
            val alpha = (0.9 - i * 0.12).toFloat()
            val blur = 2.2 - i * 0.5
            val reflPath = ridgePath(mirrored, reflRect)
            if (blur > 0.01) {
                drawBlurredPath(reflPath, SolidColor(color), (blur * scaleF).toFloat(), alpha)
            } else {
                drawPath(reflPath, color = color, alpha = alpha)
            }
        }

        // Specular column: `radial-gradient(36% 104% at 50% 0%, ...)` on a 24%-wide,
        // full-height box — an ellipse centered at the box's top-middle, wide 36% of
        // the box width and tall 104% of the box height. Built via a non-uniform
        // scale around that pivot so a unit circle becomes the right ellipse — same
        // technique as the iOS app; unlike the clouds, nothing here is blurred, so
        // there's no risk of the scale warping a blur radius.
        val specColor = lerpColor(domColor, Color.White, 0.12)
        val specO = (0.3 + lit * 0.45).toFloat()
        val specX = domX.coerceIn(6.0, 94.0)
        val specBoxLeft = waterRect.left + ((specX / 100 - 0.12) * w).toFloat()
        val specBoxWidth = 0.24f * w
        val specRadiusX = 0.36f * specBoxWidth
        val specRadiusY = 1.04f * waterRect.height
        translate(left = specBoxLeft + specBoxWidth / 2, top = waterRect.top) {
            scale(scaleX = specRadiusX, scaleY = specRadiusY, pivot = Offset.Zero) {
                val brush = Brush.radialGradient(
                    0f to specColor.copy(alpha = specO), 0.76f to specColor.copy(alpha = 0f),
                    center = Offset.Zero, radius = 1f
                )
                drawCircle(brush = brush, radius = 1f, center = Offset.Zero)
            }
        }

        // Shoreline highlight.
        val shoreHeight = waterRect.height * 0.16f
        val shoreColor = lerpColor(surface, Color.White, 0.3).copy(alpha = (0.16 + lit * 0.1).toFloat())
        drawRect(
            brush = Brush.linearGradient(
                listOf(shoreColor, shoreColor.copy(alpha = 0f)),
                start = Offset(0f, waterRect.top), end = Offset(0f, waterRect.top + shoreHeight)
            ),
            topLeft = Offset(waterRect.left, waterRect.top), size = Size(waterRect.width, shoreHeight)
        )
    }

    // Mist band, above the lake.
    val mistTop = ht * (1 - 0.29f)
    val mistHeight = ht * 0.14f
    val mistColor = p.haze.copy(alpha = (0.22 + lit * 0.08).toFloat())
    drawRect(
        brush = Brush.linearGradient(
            0f to mistColor.copy(alpha = 0f), 0.42f to mistColor, 1f to mistColor.copy(alpha = 0f),
            start = Offset(0f, mistTop + mistHeight), end = Offset(0f, mistTop)
        ),
        topLeft = Offset(0f, mistTop), size = Size(w, mistHeight)
    )
}

private fun ridgePath(points: List<Pair<Double, Double>>, rect: androidx.compose.ui.geometry.Rect): Path {
    val path = Path()
    if (points.isEmpty()) return path
    val first = points.first()
    path.moveTo(rect.left + (first.first / 100 * rect.width).toFloat(), rect.top + (first.second / 100 * rect.height).toFloat())
    for ((x, y) in points.drop(1)) {
        path.lineTo(rect.left + (x / 100 * rect.width).toFloat(), rect.top + (y / 100 * rect.height).toFloat())
    }
    path.close()
    return path
}

/** True Gaussian-ish blur via BlurMaskFilter on the framework Canvas/Paint — Compose's
 * own `Modifier.blur()` only works on API 31+ (RenderEffect); this works from
 * minSdk 26 up since it operates at the Paint/Canvas level Compose already draws
 * through, not through a hardware-layer View. */
private fun DrawScope.drawBlurredPath(path: Path, brush: Brush, blurRadiusPx: Float, alpha: Float) {
    val paint = Paint()
    brush.applyTo(size, paint, alpha)
    val framework = paint.asFrameworkPaint()
    if (blurRadiusPx > 0f) {
        framework.maskFilter = BlurMaskFilter(blurRadiusPx, BlurMaskFilter.Blur.NORMAL)
    }
    drawContext.canvas.nativeCanvas.drawPath(path.asAndroidPath(), framework)
}

private fun lerpColor(a: Color, b: Color, t: Double): Color =
    androidx.compose.ui.graphics.lerp(a, b, t.toFloat().coerceIn(0f, 1f))
