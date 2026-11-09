import XCTest
@testable import StreetPiCore

final class LaunchFilmHandoffTests: XCTestCase {
    private struct Row {
        var cue: LaunchFilmCue
        var finished: Bool
        var handoff: LaunchFilmHandoff
    }

    /// Skip, the end of the film, a missing file, and the Reduce Motion hold finish.
    /// A cancelled wait stays. Backgrounding finishes too, because a paused film never starts again.
    func testCues() {
        let rows = [
            Row(cue: .tap, finished: false, handoff: .finish),
            Row(cue: .playbackEnded, finished: false, handoff: .finish),
            Row(cue: .missingFilm, finished: false, handoff: .finish),
            Row(cue: .stillHeld, finished: false, handoff: .finish),
            Row(cue: .scene(.active), finished: false, handoff: .stay),
            Row(cue: .scene(.inactive), finished: false, handoff: .stay),
            Row(cue: .scene(.background), finished: false, handoff: .finish),
            Row(cue: .sleepCancelled, finished: false, handoff: .stay),
            Row(cue: .tap, finished: true, handoff: .stay),
            Row(cue: .playbackEnded, finished: true, handoff: .stay),
            Row(cue: .missingFilm, finished: true, handoff: .stay),
            Row(cue: .stillHeld, finished: true, handoff: .stay),
            Row(cue: .scene(.active), finished: true, handoff: .stay),
            Row(cue: .scene(.inactive), finished: true, handoff: .stay),
            Row(cue: .scene(.background), finished: true, handoff: .stay),
            Row(cue: .sleepCancelled, finished: true, handoff: .stay),
        ]
        for row in rows {
            XCTAssertEqual(
                LaunchFilmHandoff.step(row.cue, alreadyFinished: row.finished),
                row.handoff,
                "\(row.cue) finished=\(row.finished)"
            )
        }
    }
}
