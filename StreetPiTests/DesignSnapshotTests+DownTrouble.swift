import StreetPiCore
import XCTest
@testable import StreetPi

extension DesignSnapshotTests {
    /// Streaming reads Down and Remote reads Trouble. The status page never uses those words.
    func testTilesDownAndTrouble() {
        var house = HouseholdSnapshot.healthyFixture
        var markedDown = false
        house.services = house.services.map { service in
            var copy = service
            if service.kind == .media, markedDown == false {
                copy.state = .notResponding
                markedDown = true
            }
            if service.kind == .remoteHelp {
                copy.state = .degraded
            }
            return copy
        }
        let board = ControlBoardBuilder.make(
            snapshot: house,
            share: nil,
            deviceCount: nil,
            headline: "MediaFlow is down.",
            now: .streetFixtureNow
        )
        XCTAssertTrue(board.squares.contains { $0.title == "Streaming" && $0.word == "Down" })
        XCTAssertTrue(board.squares.contains { $0.title == "Remote" && $0.word == "Trouble" })
        assertMatrix(section: .home, screen: .ready(house), testName: "tiles-down-trouble")
    }
}
