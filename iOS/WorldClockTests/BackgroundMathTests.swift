import XCTest
@testable import WorldClock

final class BackgroundMathTests: XCTestCase {
    private func day(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso + "T12:00:00Z")! }

    func testPaletteMatchesTheCanvasKeyframes() {
        XCTAssertEqual(SkyPalette(hour: 0).top, RGB(0x0b0d1c))
        XCTAssertEqual(SkyPalette(hour: 12).hz, RGB(0xc6cddb))
        XCTAssertEqual(SkyPalette(hour: 24), SkyPalette(hour: 0))
        XCTAssertEqual(SkyPalette(hour: 0).star, 1, accuracy: 0.001)
        XCTAssertEqual(SkyPalette(hour: 12).star, 0, accuracy: 0.001)
    }

    func testColourMixRoundsLikeTheCanvas() {
        // JS: Math.round(11 + (71 - 11) * 0.5) = 41, per channel.
        XCTAssertEqual(RGB(0x0b0d1c).mix(RGB(0x47528a), 0.5), RGB(r: 41, g: 48, b: 83))
    }

    func testMoonPhaseFollowsTheRealCalendar() {
        XCTAssertLessThan(MoonPhase(day: day("2026-10-10")).illumination, 0.05)      // new moon
        XCTAssertGreaterThan(MoonPhase(day: day("2026-10-26")).illumination, 0.95)   // full moon
        let gibbous = MoonPhase(day: day("2026-10-21"))
        XCTAssertTrue(gibbous.waxing)
        XCTAssertGreaterThan(SkyLight(hour: 18.5, day: day("2026-10-21")).moon.alt, 0.8)
    }

    func testMoonPhaseIsStableAcrossTheDay() {
        let morning = ISO8601DateFormatter().date(from: "2026-10-21T01:00:00Z")!
        let night = ISO8601DateFormatter().date(from: "2026-10-21T23:00:00Z")!
        XCTAssertEqual(MoonPhase(day: morning), MoonPhase(day: night))
    }

    func testLightSwitchesFromSunToMoonAfterSunset() {
        let today = day("2026-10-21")
        XCTAssertTrue(SkyLight(hour: 12, day: today).usesSun)
        XCTAssertTrue(SkyLight(hour: 18.2, day: today).usesSun)    // twilight glow, gone by 18:30
        let night = SkyLight(hour: 20, day: today)
        XCTAssertFalse(night.usesSun)
        XCTAssertGreaterThan(night.strength, 0)
    }

    func testGlassIsLitFromTheSunByDayAndTheMoonByNight() {
        let today = day("2026-10-21")
        let noon = GlassLight(hour: 12, day: today)
        XCTAssertTrue(noon.isSun)
        XCTAssertEqual(noon.strength, 1, accuracy: 0.001)
        XCTAssertLessThan(noon.dy, -0.9)                 // straight above the window
        XCTAssertGreaterThan(GlassLight(hour: 17, day: today).dx, 0)   // low sun to the right
        XCTAssertFalse(GlassLight(hour: 21, day: today).isSun)
    }

    func testCardSkyLabelsFollowTheLocalHour() {
        XCTAssertEqual(CardSky(hour: 6.5, moonRise: 18).label, "Sunrise")
        XCTAssertEqual(CardSky(hour: 12, moonRise: 18).label, "Sun up")
        XCTAssertEqual(CardSky(hour: 17.5, moonRise: 18).label, "Sunset")
        XCTAssertEqual(CardSky(hour: 22, moonRise: 18).label, "Moon up")
        XCTAssertEqual(CardSky(hour: 4, moonRise: 14).label, "Night")   // moon set at 2:00
        XCTAssertEqual(CardSky(hour: 12, moonRise: 18).y, 2, accuracy: 0.001)   // top of the arc
    }

    func testNoiseTableIsTheSpecLattice() {
        let table = SkyNoise.table(seed: 8)
        XCTAssertEqual(table.count, 514 + 4 * 514 * 2)
        XCTAssertEqual(Set(table[0..<256].map(Int.init)).count, 256)   // a permutation of 0…255
        XCTAssertEqual(Array(table[256..<512]), Array(table[0..<256]))   // repeated for wraparound
        let g = (table[514], table[515])
        XCTAssertEqual(Double(hypot(g.0, g.1)), 1, accuracy: 0.0001)    // unit gradients
    }
}

final class TimeWheelLabelTests: XCTestCase {
    func testNowForOffsetsUnderAMinute() {
        XCTAssertEqual(TimeWheelView.shiftedLabel(forOffset: 0), "Now")
        XCTAssertEqual(TimeWheelView.shiftedLabel(forOffset: 20), "Now")
        XCTAssertEqual(TimeWheelView.shiftedLabel(forOffset: -20), "Now")
    }

    // Regression test: sign used to be derived from truncated hours (always 0 for
    // |offset| < 1h), so a 30-minute backward scrub showed "+0h 30m".
    func testSubHourBackwardOffsetKeepsTheMinusSign() {
        XCTAssertEqual(TimeWheelView.shiftedLabel(forOffset: -1800), "Shifted by \u{2212}0h 30m")
    }

    func testSubHourForwardOffset() {
        XCTAssertEqual(TimeWheelView.shiftedLabel(forOffset: 1800), "Shifted by +0h 30m")
    }

    func testRulerOffsetLabel() {
        XCTAssertEqual(TimeWheelView.rulerOffsetLabel(forOffset: 0), "Now")
        XCTAssertEqual(TimeWheelView.rulerOffsetLabel(forOffset: 900), "+0.25 h from now")
        XCTAssertEqual(TimeWheelView.rulerOffsetLabel(forOffset: -5400), "\u{2212}1.5 h from now")
        XCTAssertEqual(TimeWheelView.rulerOffsetLabel(forOffset: 7200), "+2 h from now")
    }

    func testWholeHourOffsets() {
        XCTAssertEqual(TimeWheelView.shiftedLabel(forOffset: -3600), "Shifted by \u{2212}1h")
        XCTAssertEqual(TimeWheelView.shiftedLabel(forOffset: 7200), "Shifted by +2h")
    }
}

final class ClockFormattingTests: XCTestCase {
    func testTimeComponents24Hour() {
        let (main, period) = ClockFormatting.timeComponents(hour: 14, minute: 5, use24Hour: true)
        XCTAssertEqual(main, "14:05")
        XCTAssertEqual(period, "")
    }

    func testTimeComponents12HourNoonAndMidnight() {
        XCTAssertEqual(ClockFormatting.timeComponents(hour: 0, minute: 0, use24Hour: false).main, "12:00")
        XCTAssertEqual(ClockFormatting.timeComponents(hour: 12, minute: 0, use24Hour: false).period, "PM")
    }

    func testOffsetLabelRoundsRatherThanTruncates() {
        // 45 minutes = 0.75h, which rounds to ".8h" (not truncates to ".7h").
        let label = ClockFormatting.offsetLabel(homeOffsetSeconds: 0, zoneOffsetSeconds: (5 * 3600 + 45 * 60))
        XCTAssertEqual(label, "+5.8h")
    }

    func testOffsetLabelIsHomeWhenZonesMatch() {
        XCTAssertEqual(ClockFormatting.offsetLabel(homeOffsetSeconds: 3600, zoneOffsetSeconds: 3600), "Home")
    }

    func testDisplayLabelExtractsCityFromIdentifier() {
        XCTAssertEqual(ClockFormatting.displayLabel(for: "Asia/Kolkata"), "Kolkata")
        XCTAssertEqual(ClockFormatting.displayLabel(for: "America/Los_Angeles"), "Los Angeles")
    }

    func testCityCode() {
        XCTAssertEqual(ClockFormatting.cityCode(for: "Tokyo"), "TOK")
        XCTAssertEqual(ClockFormatting.cityCode(for: "New York"), "NY")
        XCTAssertEqual(ClockFormatting.cityCode(for: "Ho Chi Minh City"), "HCM")
        XCTAssertEqual(ClockFormatting.cityCode(for: "Port-au-Prince"), "PAP")
    }

    func testDayOffsetAheadBehindAndSame() {
        let home = TimeZone(identifier: "Asia/Kolkata")!
        // 2026-10-21 18:30 in Kolkata = 13:00 UTC.
        let date = Date(timeIntervalSince1970: 1_792_587_600)
        XCTAssertEqual(ClockFormatting.dayOffset(of: TimeZone(identifier: "Australia/Sydney")!, from: home, at: date), 1)   // 00:00 Wed
        XCTAssertEqual(ClockFormatting.dayOffset(of: TimeZone(identifier: "Europe/London")!, from: home, at: date), 0)      // 14:00 Tue
        XCTAssertEqual(ClockFormatting.dayOffset(of: TimeZone(identifier: "Pacific/Honolulu")!, from: home, at: date), 0)   // 03:00 Tue
        // 01:00 in Kolkata (19:30 UTC the day before): Honolulu is still on the previous day.
        let early = Date(timeIntervalSince1970: 1_792_524_600)
        XCTAssertEqual(ClockFormatting.dayOffset(of: TimeZone(identifier: "Pacific/Honolulu")!, from: home, at: early), -1)
    }
}

final class ClockBoardViewModelTests: XCTestCase {
    func testSelectingARowSwapsAnchorAndResetsOffset() {
        let viewModel = ClockBoardViewModel()
        let entry = ClockEntry(timeZoneIdentifier: "Asia/Tokyo", label: "Tokyo", sortOrder: 0)
        viewModel.offset = 3600

        viewModel.select(entry)

        XCTAssertEqual(viewModel.selectedEntryID, entry.id)
        XCTAssertEqual(viewModel.offset, 0)
        XCTAssertEqual(viewModel.anchorTimeZone(entries: [entry]).identifier, "Asia/Tokyo")
    }

    func testSelectingTheSameRowTwiceDeselectsAndResetsToDeviceAnchor() {
        let viewModel = ClockBoardViewModel()
        let entry = ClockEntry(timeZoneIdentifier: "Asia/Tokyo", label: "Tokyo", sortOrder: 0)

        viewModel.select(entry)
        viewModel.offset = 1800
        viewModel.select(entry)

        XCTAssertNil(viewModel.selectedEntryID)
        XCTAssertEqual(viewModel.offset, 0)
    }
}
