package org.surajshetty.worldclockapp

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ClockRepositoryTest {
    @Test
    fun `serialize then parse round-trips every field`() {
        val entries = listOf(
            ClockEntry(id = "a", timeZoneId = "Asia/Kolkata", label = "Bengaluru", sortOrder = 0),
            ClockEntry(id = "b", timeZoneId = "America/New_York", label = "New York", sortOrder = 1)
        )
        assertEquals(entries, parseEntries(serializeEntries(entries)))
    }

    @Test
    fun `empty list round-trips to empty list`() {
        assertTrue(parseEntries(serializeEntries(emptyList())).isEmpty())
    }

    @Test
    fun `malformed json self-heals to an empty list instead of throwing`() {
        // Regression test: a truncated write (process death mid-apply) used to crash
        // the app on every subsequent launch.
        assertTrue(parseEntries("not json").isEmpty())
        assertTrue(parseEntries("""[{"id":"a","timeZoneId":"Asia/Kolkata"}]""").isEmpty()) // missing fields
        assertTrue(parseEntries("""[{"id":"a","timeZoneId":"Asia/Kolkata","label":"X","sortOrder":"oops"}]""").isEmpty()) // wrong type
    }
}
