import XCTest
@testable import StreetPiCore

/// A pull that stays on the current road. A different road restarts the watch, so it is not a row here.
final class ManualRefreshTests: XCTestCase {
    func testPullReadsTheTilesThatWaitOnTheirOwnLoop() throws {
        let live = try gateway()
        let box = try mailbox()
        let tiles: Set<ManualRefresh.Source> = [.adBlocker, .temperature, .charts, .monitors]
        let rows: [Row] = [
            Row(mode: .home, signedOut: false, reads: tiles),
            Row(mode: .offline, signedOut: false, reads: tiles),
            Row(mode: .awayLive(live), signedOut: false, reads: tiles),
            Row(mode: .awayMailbox(box), signedOut: false, reads: [.mailbox]),
            Row(mode: .awayMailbox(box), signedOut: true, reads: [.mailbox]),
            Row(mode: .home, signedOut: true, reads: []),
            Row(mode: .offline, signedOut: true, reads: []),
            Row(mode: .awayLive(live), signedOut: true, reads: []),
        ]
        for row in rows {
            XCTAssertEqual(ManualRefresh.reads(mode: row.mode, signedOut: row.signedOut), row.reads)
        }
    }

    private struct Row {
        var mode: ConnectionMode
        var signedOut: Bool
        var reads: Set<ManualRefresh.Source>
    }

    private func gateway() throws -> AwayGatewaySettings {
        try XCTUnwrap(AwayGatewaySettings(
            url: "https://gateway.example.test",
            clientID: "test-client.access",
            clientSecret: "cfast_FAKE_not_a_real_secret"
        ))
    }

    private func mailbox() throws -> MailboxSetup {
        MailboxSetup(
            address: try XCTUnwrap(MailboxAddress(text: "https://mailbox.example.test")),
            token: try XCTUnwrap(MailboxToken(text: "fixture-not-a-real-read-token"))
        )
    }
}
