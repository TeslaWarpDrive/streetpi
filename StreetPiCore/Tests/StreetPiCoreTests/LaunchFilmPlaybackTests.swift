import XCTest
@testable import StreetPiCore

final class LaunchFilmPlaybackTests: XCTestCase {
    private struct Row {
        var duration: TimeInterval?
        var elapsed: TimeInterval
        var remaining: TimeInterval?
        var sawPlayback: Bool
        var transport: LaunchFilmPlayback.Transport
        var ended: Bool
    }

    /// A pause does not end the film when the clock passes the length plus three seconds.
    func testPauseDoesNotUseTheClock() {
        let length: TimeInterval = 8
        let grace = length + LaunchFilmPlayback.overtime
        let rows = [
            Row(
                duration: length, elapsed: grace + 1, remaining: 4,
                sawPlayback: true, transport: .paused, ended: false
            ),
            Row(
                duration: length, elapsed: grace + 1, remaining: length,
                sawPlayback: false, transport: .paused, ended: false
            ),
            Row(
                duration: length, elapsed: grace + 1, remaining: 0.05,
                sawPlayback: true, transport: .paused, ended: true
            ),
            Row(
                duration: length, elapsed: grace + 1, remaining: 0.25,
                sawPlayback: true, transport: .paused, ended: false
            ),
        ]
        assertEnd(rows)
    }

    /// Playing or waiting past the grace ends the film. The real end still counts while paused.
    func testStallGraceAndTheRealEnd() {
        let length: TimeInterval = 8
        let grace = length + LaunchFilmPlayback.overtime
        let rows = [
            Row(
                duration: length, elapsed: grace, remaining: 4,
                sawPlayback: true, transport: .playing, ended: false
            ),
            Row(
                duration: length, elapsed: grace + 1, remaining: 4,
                sawPlayback: true, transport: .playing, ended: true
            ),
            Row(
                duration: length, elapsed: grace + 1, remaining: 4,
                sawPlayback: true, transport: .waiting, ended: true
            ),
            Row(
                duration: length, elapsed: grace + 1, remaining: length,
                sawPlayback: false, transport: .waiting, ended: true
            ),
            Row(
                duration: length, elapsed: grace + 1, remaining: nil,
                sawPlayback: false, transport: .playing, ended: true
            ),
            Row(
                duration: length, elapsed: length, remaining: 0,
                sawPlayback: true, transport: .paused, ended: true
            ),
            Row(
                duration: length, elapsed: length, remaining: 0.05,
                sawPlayback: true, transport: .paused, ended: true
            ),
            Row(
                duration: length, elapsed: length, remaining: 0.2,
                sawPlayback: true, transport: .paused, ended: true
            ),
            Row(
                duration: length, elapsed: length, remaining: 0.2,
                sawPlayback: true, transport: .waiting, ended: true
            ),
            Row(
                duration: length, elapsed: length, remaining: 0.2,
                sawPlayback: true, transport: .playing, ended: false
            ),
            Row(
                duration: length, elapsed: 1, remaining: 0.25,
                sawPlayback: true, transport: .paused, ended: false
            ),
            Row(
                duration: length, elapsed: 1, remaining: 0,
                sawPlayback: false, transport: .playing, ended: false
            ),
            Row(
                duration: length, elapsed: 1, remaining: nil,
                sawPlayback: true, transport: .paused, ended: false
            ),
            Row(
                duration: nil, elapsed: grace + 1, remaining: nil,
                sawPlayback: true, transport: .playing, ended: false
            ),
            Row(
                duration: nil, elapsed: grace + 1, remaining: nil,
                sawPlayback: false, transport: .paused, ended: false
            ),
            Row(
                duration: .infinity, elapsed: grace + 1, remaining: 0,
                sawPlayback: true, transport: .paused, ended: false
            ),
        ]
        assertEnd(rows)
    }

    private func assertEnd(_ rows: [Row]) {
        for row in rows {
            XCTAssertEqual(
                LaunchFilmPlayback.reachedEnd(
                    duration: row.duration,
                    elapsed: row.elapsed,
                    remaining: row.remaining,
                    sawPlayback: row.sawPlayback,
                    transport: row.transport
                ),
                row.ended,
                "\(row.transport) elapsed=\(row.elapsed) remaining=\(String(describing: row.remaining))"
            )
        }
    }
}
