import Foundation
import XCTest
@testable import StreetPiCore

final class PauseEndTests: XCTestCase {
    func testReportedTimerBecomesAnAbsoluteEndTime() throws {
        let now = Date.streetFixtureNow
        let blocking = try PiholeDecode.blocking(
            from: Data(#"{"blocking":"disabled","timer":300}"#.utf8),
            now: now
        )
        XCTAssertFalse(blocking.enabled)
        XCTAssertEqual(blocking.pauseEndsAt, now.addingTimeInterval(300))
    }

    func testNoTimerDoesNotInventAnEndTime() throws {
        for response in [
            #"{"blocking":"disabled","timer":null}"#,
            #"{"blocking":"enabled","timer":300}"#,
            #"{"blocking":"disabled","timer":0}"#,
        ] {
            let blocking = try PiholeDecode.blocking(from: Data(response.utf8), now: .streetFixtureNow)
            XCTAssertNil(blocking.pauseEndsAt)
        }
    }
}
