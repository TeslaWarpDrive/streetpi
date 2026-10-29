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

    func testMonitorsKeepSnapshotChecksWhileTheStatusBoardIsUnavailable() {
        let snapshot = HouseholdSnapshot.healthyFixture
        let detail = HouseGuide.detail(.monitors, snapshot: snapshot, status: nil)
        XCTAssertEqual(detail.rows.map(\.id), snapshot.services.map(\.id))
        XCTAssertEqual(detail.rows.map(\.state), snapshot.services.map { ReadingText.stateWord(for: $0) })
    }

    func testMissingSetupDoesNotFallBackToHealthyFixture() {
        let board = HouseStatusBoard.notSetUp()
        for tile in board.tiles {
            let detail = HouseGuide.detail(tile.id, snapshot: .healthyFixture, status: board)
            XCTAssertEqual(detail.summary, StatusPageCopy.notSetUp)
            XCTAssertTrue(detail.rows.isEmpty)
        }
    }

    func testActiveDevicesAreNotLimitedToTheTopTen() async throws {
        let clients = (1...67).map { index in
            ["ip": "192.0.2.\(index)", "name": "Fixture device \(index)", "count": index] as [String: Any]
        }
        let body = try JSONSerialization.data(withJSONObject: ["clients": clients])
        let transport = ScriptedPiholeTransport(steps: [
            .json(200, #"{"session":{"sid":"fixture-session","validity":1800}}"#),
            .json(200, try XCTUnwrap(String(data: body, encoding: .utf8))),
        ])
        let client = PiholeClient(transport: transport, password: { "fixture-not-a-real-password" })
        let rows = try await client.activeClients(count: 67)
        XCTAssertEqual(rows.count, 67)
        XCTAssertEqual(rows.first?.detail, "192.0.2.1 · 1 lookup")
        XCTAssertEqual(rows.last?.id, "192.0.2.67")
        XCTAssertEqual(transport.sent.last?.path, "/api/stats/top_clients?count=67")
        XCTAssertEqual(transport.sent.filter { $0.method != "GET" }.map(\.path), ["/api/auth"])
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
