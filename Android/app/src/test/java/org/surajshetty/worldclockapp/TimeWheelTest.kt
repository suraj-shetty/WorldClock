package org.surajshetty.worldclockapp

import org.junit.Assert.assertEquals
import org.junit.Test

class TimeWheelTest {
    @Test
    fun `now for offsets under a minute`() {
        assertEquals("Now", shiftedLabel(0.0))
        assertEquals("Now", shiftedLabel(20.0))
        assertEquals("Now", shiftedLabel(-20.0))
    }

    @Test
    fun `sub-hour backward offset keeps the minus sign`() {
        // Regression test: sign used to be derived from truncated hours (always 0
        // for |offset| < 1h), so a 30-minute backward scrub showed "+0h 30m".
        assertEquals("Shifted by −0h 30m", shiftedLabel(-1800.0))
    }

    @Test
    fun `sub-hour forward offset`() {
        assertEquals("Shifted by +0h 30m", shiftedLabel(1800.0))
    }

    @Test
    fun `whole hour offsets`() {
        assertEquals("Shifted by −1h", shiftedLabel(-3600.0))
        assertEquals("Shifted by +2h", shiftedLabel(7200.0))
    }

    @Test
    fun `hours and minutes combined`() {
        assertEquals("Shifted by −1h 30m", shiftedLabel(-5400.0))
    }
}
