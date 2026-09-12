import XCTest
@testable import WorldClock

final class BackgroundMathTests: XCTestCase {
    func testMidnightIsNearBlack() {
        let midnight = skyColors(forHour: 0)
        XCTAssertLessThan(midnight.top.components.r, 0.1)
    }

    func testMiddayIsBrightBlue() {
        let midday = skyColors(forHour: 12)
        XCTAssertGreaterThan(midday.bottom.components.b, 0.8)
    }

    func testHour24WrapsToHour0() {
        let start = skyColors(forHour: 0)
        let end = skyColors(forHour: 24)
        XCTAssertEqual(start.top.components.r, end.top.components.r, accuracy: 0.001)
    }

    func testNightFactorPeaksAtMidnightAndTroughsAtNoon() {
        XCTAssertEqual(nightFactor(forHour: 0), 1, accuracy: 0.001)
        XCTAssertEqual(nightFactor(forHour: 12), 0, accuracy: 0.001)
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
