import StreetPiCore
import XCTest
@testable import StreetPi

final class HouseBoardToneTests: XCTestCase {
    func testFailedHouseDoesNotLookCalm() {
        let board = HouseBoard.make(screen: .failed, desk: .houseFixture, now: .streetFixtureNow)
        XCTAssertEqual(board.tone, .problem)
    }

    func testMissingStatusPageCarriesItsAttentionTone() {
        let board = HouseBoard.make(
            screen: .ready(.healthyFixture),
            desk: .houseFixture,
            now: .streetFixtureNow
        )
        let missing = HouseBoard.applying(status: .notSetUp(), to: board)
        XCTAssertEqual(missing.headline, StatusPageCopy.notSetUp)
        XCTAssertEqual(missing.tone, .attention)
    }
}
