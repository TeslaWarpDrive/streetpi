import XCTest
@testable import StreetPiCore

final class HomeDetailTests: XCTestCase {
    func testEveryStatusTileUsesItsOwnRowsEvenWithoutASnapshot() {
        let board = StatusPageFixture.previewBoard()
        for tile in board.tiles {
            let detail = HouseGuide.detail(tile.id, snapshot: nil, status: board)
            XCTAssertEqual(detail, tile.brief)
            XCTAssertFalse(detail.title.isEmpty)
            XCTAssertFalse(detail.summary.isEmpty)
            XCTAssertFalse(detail.rows.isEmpty, tile.title)
            XCTAssertFalse(HouseGuide.meaning(for: tile.id).isEmpty)
        }
    }

    func testAllRoutesHaveContentWhenNoReadingIsAvailable() {
        for group in HouseGroup.allCases {
            let detail = HouseGuide.detail(group, snapshot: nil, status: nil)
            XCTAssertEqual(detail.id, group)
            XCTAssertFalse(detail.title.isEmpty)
            XCTAssertEqual(detail.summary, "No recent reading yet.")
            XCTAssertFalse(HouseGuide.meaning(for: group).isEmpty)
        }
    }

    func testMissingSetupDoesNotFallBackToHealthyFixture() {
        let board = HouseStatusBoard.notSetUp()
        for tile in board.tiles {
            let detail = HouseGuide.detail(tile.id, snapshot: .healthyFixture, status: board)
            XCTAssertEqual(detail.summary, StatusPageCopy.notSetUp)
            XCTAssertTrue(detail.rows.isEmpty)
        }
    }

    func testClientAddressesAreStableAndUnnamedDevicesRemainVisible() throws {
        let json = #"{"clients":[{"ip":"192.0.2.1","name":"","count":5},{"ip":"2001:db8::1","name":null,"count":2}]}"#
        let clients = try PiholeDecode.activeClients(from: Data(json.utf8))
        XCTAssertEqual(clients.map(\.id), ["192.0.2.1", "2001:db8::1"])
        XCTAssertEqual(clients.map(\.name), clients.map(\.id))
        XCTAssertTrue(clients[0].detail.contains("5 lookups"))
        XCTAssertEqual(try PiholeDecode.activeClients(from: Data(#"{"clients":[]}"#.utf8)), [])
        XCTAssertThrowsError(try PiholeDecode.activeClients(from: Data(#"{"error":"unavailable"}"#.utf8)))
    }
}
