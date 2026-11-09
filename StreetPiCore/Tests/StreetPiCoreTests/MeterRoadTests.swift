import XCTest
@testable import StreetPiCore

final class MeterRoadTests: XCTestCase {
    func testABackgroundMeterMissStaysOnTheRoad() {
        XCTAssertFalse(MeterRoad.missAsksForNewRoad())
    }
}
