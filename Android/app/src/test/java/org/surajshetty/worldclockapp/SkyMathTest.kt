package org.surajshetty.worldclockapp

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SkyMathTest {
    @Test
    fun `normalizedHour wraps into 0 to 24`() {
        assertEquals(0.0, normalizedHour(24.0), 1e-9)
        assertEquals(23.0, normalizedHour(-1.0), 1e-9)
        assertEquals(1.0, normalizedHour(25.0), 1e-9)
        assertEquals(12.0, normalizedHour(12.0), 1e-9)
    }

    @Test
    fun `clamp01 clamps outside 0 to 1`() {
        assertEquals(0.0, clamp01(-5.0), 1e-9)
        assertEquals(1.0, clamp01(5.0), 1e-9)
        assertEquals(0.5, clamp01(0.5), 1e-9)
    }

    @Test
    fun `skyPalette midnight matches the 0h keyframe`() {
        val p = skyPalette(0.0)
        assertEquals(1.0, p.star, 1e-9)
    }

    @Test
    fun `skyPalette is continuous across the day-end wrap`() {
        // The 24.0 keyframe mirrors the 0.0 keyframe exactly, so approaching hour 24
        // from either side should land on (near) the same star intensity.
        val justBefore = skyPalette(23.999)
        val justAfter = skyPalette(0.001)
        assertTrue(Math.abs(justBefore.star - justAfter.star) < 0.01)
    }

    @Test
    fun `skyPalette handles negative and over-range hours like normalizedHour`() {
        val direct = skyPalette(normalizedHour(-3.0))
        val viaNegative = skyPalette(normalizedHour(21.0))
        assertEquals(direct.star, viaNegative.star, 1e-9)
    }
}
