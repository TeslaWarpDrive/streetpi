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

    /// "Ready" and "Up to date" are healthy words too, so a mark reads the row's tone.
    func testHealthyWordsDrawAsUp() {
        let rows = [
            GroupRow(id: "remote", name: "Remote", state: "Ready", tone: .calm),
            GroupRow(id: "address", name: "Address", state: "Up to date", tone: .calm),
            GroupRow(id: "proxy", name: "Proxy", state: "Not responding", tone: .problem),
        ]
        let tile = HouseStatusTile(id: .monitors, title: "Monitors", summary: "2 of 3 up", tone: .problem, rows: rows)
        let board = HouseBoard.make(screen: .ready(.healthyFixture), desk: .houseFixture, now: .streetFixtureNow)
        let status = HouseStatusBoard(tiles: [tile], services: [], isMissing: false)
        let marks = HouseBoard.applying(status: status, to: board).monitors.marks
        XCTAssertEqual(marks.map(\.up), [true, true, false])
    }
}
