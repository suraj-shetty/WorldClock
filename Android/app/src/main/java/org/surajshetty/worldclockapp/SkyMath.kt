package org.surajshetty.worldclockapp

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import kotlin.math.abs
import kotlin.math.exp
import kotlin.math.pow

// MARK: - "Nocturne" sky illustration
// Ported from the iOS app's BackgroundView.swift, which was itself transcribed
// directly from the Claude Design handoff (`Sky.dc.html`): a parametric sky driven
// by hour-of-day (0..24, fractional) — gradient, star field, sun/moon arc, clouds,
// haze, and a mountain/lake terrain layer. Values (colors, curves, geometry) match
// the iOS port so this renders the same sky, not just a similar one.

data class SkyKeyframe(
    val hour: Double,
    val top: Color, val up: Color, val mid: Color, val hz: Color,
    val star: Double,
    val cloudTint: Color, val cloudAlpha: Double,
    val haze: Color
)

val skyKeyframes: List<SkyKeyframe> = listOf(
    SkyKeyframe(0.0, Color(0xFF0B0D1C), Color(0xFF101228), Color(0xFF141830), Color(0xFF1D2140), 1.0, Color(0xFF3A3F63), 0.42, Color(0xFF141731)),
    SkyKeyframe(4.5, Color(0xFF101227), Color(0xFF181B38), Color(0xFF22254A), Color(0xFF3C3358), 0.5, Color(0xFF413F68), 0.5, Color(0xFF241F3D)),
    SkyKeyframe(6.5, Color(0xFF2B2C52), Color(0xFF4A4470), Color(0xFF6E5F85), Color(0xFFC49A8D), 0.04, Color(0xFFB48D94), 0.58, Color(0xFF8D6F78)),
    SkyKeyframe(9.0, Color(0xFF3A4570), Color(0xFF606B95), Color(0xFF7F8AAE), Color(0xFFBCC2D2), 0.0, Color(0xFFD2D8E6), 0.52, Color(0xFF9AA3BB)),
    SkyKeyframe(12.0, Color(0xFF47528A), Color(0xFF6B77A6), Color(0xFF8B98BD), Color(0xFFC6CDDB), 0.0, Color(0xFFE2E7F0), 0.58, Color(0xFFA5AEC6)),
    SkyKeyframe(15.0, Color(0xFF414877), Color(0xFF6A6C99), Color(0xFF8A86AB), Color(0xFFCBB3AE), 0.0, Color(0xFFD6C9D0), 0.54, Color(0xFFA08E9E)),
    SkyKeyframe(18.0, Color(0xFF1E2144), Color(0xFF413D67), Color(0xFF6D5B88), Color(0xFFC08E7F), 0.16, Color(0xFF8E7489), 0.6, Color(0xFF7D5C69)),
    SkyKeyframe(20.5, Color(0xFF131628), Color(0xFF1F2140), Color(0xFF33305A), Color(0xFF5C4A6E), 0.58, Color(0xFF4C4666), 0.5, Color(0xFF33294A)),
    SkyKeyframe(24.0, Color(0xFF0B0D1C), Color(0xFF101228), Color(0xFF141830), Color(0xFF1D2140), 1.0, Color(0xFF3A3F63), 0.42, Color(0xFF141731)),
)

val skyInk = Color(0xFF090B18)
val skyAccent = Color(0xFF9184D9) // Nocturne accent — used only for the moon's glow here

fun clamp01(v: Double): Double = v.coerceIn(0.0, 1.0)
fun ramp(v: Double, a: Double, b: Double): Double = clamp01((v - a) / (b - a))

data class SkyPalette(
    val top: Color, val up: Color, val mid: Color, val hz: Color,
    val star: Double,
    val cloudTint: Color, val cloudAlpha: Double,
    val haze: Color
)

fun skyPalette(hour: Double): SkyPalette {
    val h = hour % 24
    val hh = if (h < 0) h + 24 else h
    var i = 0
    while (i < skyKeyframes.size - 2 && hh >= skyKeyframes[i + 1].hour) i++
    val a = skyKeyframes[i]
    val b = skyKeyframes[i + 1]
    val t = if (a.hour == b.hour) 0.0 else clamp01((hh - a.hour) / (b.hour - a.hour))
    val tf = t.toFloat()
    return SkyPalette(
        top = lerp(a.top, b.top, tf), up = lerp(a.up, b.up, tf), mid = lerp(a.mid, b.mid, tf), hz = lerp(a.hz, b.hz, tf),
        star = a.star + (b.star - a.star) * t,
        cloudTint = lerp(a.cloudTint, b.cloudTint, tf), cloudAlpha = a.cloudAlpha + (b.cloudAlpha - a.cloudAlpha) * t,
        haze = lerp(a.haze, b.haze, tf)
    )
}

fun normalizedHour(hour: Double): Double {
    val raw = hour % 24
    return if (raw < 0) raw + 24 else raw
}

/**
 * Complementary error function, Abramowitz & Stegun 7.1.26 (max error ~1.5e-7) —
 * plenty precise for a visual glow falloff. Used to reproduce CSS box-shadow blur
 * math exactly: a disc of radius R blurred by a Gaussian of sigma = blur/2 has an
 * edge profile of erfc((r - R) / (sigma*sqrt2)), see `drawDisc` in SkyBackground.kt.
 */
fun erfc(x: Double): Double {
    val sign = if (x < 0) -1.0 else 1.0
    val ax = abs(x)
    val t = 1.0 / (1.0 + 0.3275911 * ax)
    val poly = ((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592
    val erf = 1.0 - poly * t * exp(-ax * ax)
    return 1.0 - sign * erf
}

// MARK: - Star field
// Same deterministic PRNG (seed + LCG) as the iOS app so the star layout matches.

data class SkyStar(val x: Double, val y: Double, val d: Double, val baseBrightness: Double, val dur: Double, val delay: Double)

val skyStars: List<SkyStar> = run {
    var seed = 20260910L
    fun rnd(): Double {
        seed = (seed * 1664525L + 1013904223L) % 4294967296L
        return seed / 4294967296.0
    }
    (0 until 90).map {
        val y = rnd().pow(1.7) * 58
        SkyStar(x = rnd() * 100, y = y, d = 0.9 + rnd() * 1.7, baseBrightness = 0.35 + rnd() * 0.65, dur = 2.6 + rnd() * 4.4, delay = rnd() * 5)
    }
}

// MARK: - Clouds (fixed layout, per-frame color/opacity)

data class SkyCloudBase(val x: Double, val y: Double, val w: Double, val h: Double, val blur: Double, val o: Double)

val skyCloudBases: List<SkyCloudBase> = listOf(
    SkyCloudBase(22.0, 16.0, 54.0, 9.0, 13.0, 0.9),
    SkyCloudBase(74.0, 27.0, 44.0, 7.0, 11.0, 0.7),
    SkyCloudBase(40.0, 44.0, 68.0, 8.0, 15.0, 0.55),
    SkyCloudBase(86.0, 57.0, 38.0, 6.0, 10.0, 0.45),
    SkyCloudBase(12.0, 66.0, 50.0, 6.0, 12.0, 0.38),
)

// MARK: - Terrain (mountain ridges + lake), fixed geometry per the design's clip-paths

data class RidgeShape(
    val bottomPercent: Double, val heightPercent: Double, val blur: Double, val ink: Double,
    val points: List<Pair<Double, Double>>
)

val ridgeShapes: List<RidgeShape> = listOf(
    RidgeShape(18.0, 27.0, 2.4, 0.42, listOf(
        0.0 to 100.0, 0.0 to 66.0, 8.0 to 44.0, 16.0 to 58.0, 26.0 to 28.0, 34.0 to 47.0, 43.0 to 20.0, 52.0 to 43.0,
        61.0 to 25.0, 70.0 to 50.0, 79.0 to 32.0, 88.0 to 54.0, 96.0 to 38.0, 100.0 to 52.0, 100.0 to 100.0,
    )),
    RidgeShape(17.0, 21.0, 1.2, 0.66, listOf(
        0.0 to 100.0, 0.0 to 78.0, 9.0 to 54.0, 16.0 to 70.0, 25.0 to 40.0, 34.0 to 63.0, 42.0 to 32.0, 51.0 to 58.0,
        59.0 to 36.0, 69.0 to 64.0, 77.0 to 46.0, 86.0 to 66.0, 94.0 to 50.0, 100.0 to 68.0, 100.0 to 100.0,
    )),
    RidgeShape(16.0, 16.0, 0.0, 0.84, listOf(
        0.0 to 100.0, 0.0 to 62.0, 11.0 to 32.0, 21.0 to 56.0, 30.0 to 26.0, 38.0 to 52.0, 45.0 to 78.0, 50.0 to 92.0,
        55.0 to 78.0, 62.0 to 50.0, 71.0 to 24.0, 81.0 to 54.0, 91.0 to 38.0, 100.0 to 64.0, 100.0 to 100.0,
    )),
)

const val waterHeightPercent: Double = 15.0
val shorelinePoints: List<Pair<Double, Double>> = listOf(
    0.0 to 5.0, 13.0 to 2.0, 27.0 to 6.0, 40.0 to 2.5, 53.0 to 6.5, 67.0 to 3.0, 80.0 to 7.0, 92.0 to 3.5, 100.0 to 6.0, 100.0 to 100.0, 0.0 to 100.0,
)
