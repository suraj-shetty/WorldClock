import XCTest
@testable import WorldClock

final class BackgroundMathTests: XCTestCase {
    func testMidnightIsNearBlack() {
        let midnight = skyPalette(forHour: 0)
        XCTAssertLessThan(midnight.top.components.r, 0.1)
    }

    func testMiddayHorizonIsPaleAndBright() {
        let midday = skyPalette(forHour: 12)
        XCTAssertGreaterThan(midday.hz.components.b, 0.8)
    }

    func testHour24WrapsToHour0() {
        let start = skyPalette(forHour: 0)
        let end = skyPalette(forHour: 24)
        XCTAssertEqual(start.top.components.r, end.top.components.r, accuracy: 0.001)
    }

    func testStarVisibilityPeaksAtMidnightAndVanishesAtNoon() {
        XCTAssertEqual(skyPalette(forHour: 0).star, 1, accuracy: 0.001)
        XCTAssertEqual(skyPalette(forHour: 12).star, 0, accuracy: 0.001)
    }

    // Regression test: the moon's arc used to be computed with `h < 12 ? h + 24 : h`,
    // which wraps at noon instead of at the moon's 18:00 rise reference. That's deep
    // in broad daylight (moonO already 0 well before and after noon), but any
    // transition crossing that point still jumped the moon's off-screen resting
    // position, and the invisible-but-wrong position could show once opacity ramped
    // back up on the far side of a fast transition.
    func testMoonIsInvisibleAndContinuousAcrossTheNoonBoundary() {
        let justBefore = sunMoonPosition(forHour: 11.999)
        let atNoon = sunMoonPosition(forHour: 12)
        let justAfter = sunMoonPosition(forHour: 12.001)
        XCTAssertEqual(justBefore.moonO, 0, accuracy: 0.001)
        XCTAssertEqual(atNoon.moonO, 0, accuracy: 0.001)
        XCTAssertEqual(justAfter.moonO, 0, accuracy: 0.001)
        // The arc parameter itself (not just its opacity) must also be continuous,
        // since it's still driven through an eased animation even while invisible.
        XCTAssertEqual(justBefore.moonT, atNoon.moonT, accuracy: 0.01)
        XCTAssertEqual(atNoon.moonT, justAfter.moonT, accuracy: 0.01)
    }

    func testMoonIsFullyUpAtItsMidpointBetweenRiseAndSet() {
        // Rises 18:20, sets 6:20 -> apex around 0:20.
        let apex = sunMoonPosition(forHour: 0.333)
        XCTAssertEqual(apex.moonUp, 1, accuracy: 0.01)
    }

    func testSunIsFullyUpAtSolarNoon() {
        let noon = sunMoonPosition(forHour: 12)
        XCTAssertEqual(noon.sunUp, 1, accuracy: 0.001)
    }

    func testGlassIsLitFromTheSunByDayAndTheMoonByNight() {
        let noon = GlassLight(hour: 12)
        XCTAssertTrue(noon.isSun)
        XCTAssertEqual(noon.strength, 1, accuracy: 0.001)
        XCTAssertLessThan(noon.dy, -0.9)                 // straight above the window
        let evening = GlassLight(hour: 17)
        XCTAssertGreaterThan(evening.dx, 0)              // low sun to the right
        let midnight = GlassLight(hour: 0)
        XCTAssertFalse(midnight.isSun)
        XCTAssertGreaterThan(midnight.strength, 0)
        XCTAssertLessThan(midnight.dy, 0)                // moon high, past its 18:00 rise
    }

    func testCardSkyLabelsFollowTheLocalHour() {
        XCTAssertEqual(CardSky(hour: 6.5).label, "Sunrise")
        XCTAssertEqual(CardSky(hour: 12).label, "Sun up")
        XCTAssertEqual(CardSky(hour: 17.5).label, "Sunset")
        XCTAssertEqual(CardSky(hour: 22).label, "Moon up")
        XCTAssertEqual(CardSky(hour: 12).y, 2, accuracy: 0.001)   // top of the arc
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
