package org.surajshetty.worldclockapp

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CountryLookupTest {
    @Test
    fun `known timezone resolves to its country and flag`() {
        val country = CountryLookup.lookup("Asia/Kolkata")
        assertEquals("India", country?.name)
        assertEquals("🇮🇳", country?.flag) // regional-indicator I + N
    }

    @Test
    fun `unknown timezone returns null`() {
        assertNull(CountryLookup.lookup("Not/A_Real_Zone"))
    }

    @Test
    fun `repeated lookups return an equal result`() {
        // Exercises the internal hit/miss cache without assuming its internals.
        val first = CountryLookup.lookup("America/New_York")
        val second = CountryLookup.lookup("America/New_York")
        assertEquals(first, second)
    }
}
