import StreetPiCore
import XCTest
@testable import StreetPi

@MainActor
final class MonitorDrillDownTests: XCTestCase {
    func testServicesShowTheStatusPageChecksIncludingFailures() throws {
        let document = StatusPageFixture.previewDocument()
        let failedID = try XCTUnwrap(document.sections.first?.monitors.first?.id)
        var history = StatusPageFixture.previewHistory(now: .streetFixtureNow)
        history.latest[failedID] = StatusBeat(status: 0, time: .streetFixtureNow)
        let board = HouseStatusBoard.make(document: document, history: history, now: .streetFixtureNow)
        let monitors = try XCTUnwrap(board.tiles.first { $0.id == .monitors })
        let shell = AppShell(
            section: .group(.piHealth),
            screen: .ready(.healthyFixture),
            now: .streetFixtureNow,
            onSection: { _ in },
            statusBoard: board
        )
        let rows = shell.piDesk.services
        XCTAssertEqual(rows.count, 28)
        XCTAssertEqual(Set(rows.map(\.name)), Set(monitors.rows.map(\.name)))
        XCTAssertTrue(rows.contains { $0.detail == "Down" })
    }
}
