import Foundation
import XCTest
@testable import StreetPiCore

final class AwayNoticeRecoveryTests: XCTestCase {
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
            token: try XCTUnwrap(MailboxToken(text: "FAKE_mailbox_token"))
        )
    }

    func testAnyRoadLooksAgainAfterAFailedRead() throws {
        for mode in [ConnectionMode.home, .offline, .awayLive(try gateway()), .awayMailbox(try mailbox())] {
            XCTAssertTrue(mode.looksAgain(readFailed: true, keyRejected: false))
        }
    }

    func testARejectedKeyKeepsTheAppLookingEvenWhenTheReadWorked() throws {
        for mode in [ConnectionMode.awayLive(try gateway()), .awayMailbox(try mailbox())] {
            XCTAssertTrue(mode.looksAgain(readFailed: false, keyRejected: true))
        }
    }

    func testOfflineKeepsLookingWhenTheHouseAnswers() {
        XCTAssertTrue(ConnectionMode.offline.looksAgain(readFailed: false, keyRejected: false))
    }

    /// The badge stays "Can't reach the Pi" on this road. One row changes: a read that
    /// worked stays off the house. A miss still shows, and every other road paints both.
    func testOnlyAnOfflineSuccessStaysOffTheHouse() throws {
        let gateway = try gateway()
        let mailbox = try mailbox()
        let rows = [
            PaintRow(mode: .home, succeeded: true, paints: true),
            PaintRow(mode: .home, succeeded: false, paints: true),
            PaintRow(mode: .awayLive(gateway), succeeded: true, paints: true),
            PaintRow(mode: .awayLive(gateway), succeeded: false, paints: true),
            PaintRow(mode: .awayMailbox(mailbox), succeeded: true, paints: true),
            PaintRow(mode: .awayMailbox(mailbox), succeeded: false, paints: true),
            PaintRow(mode: .offline, succeeded: false, paints: true),
            PaintRow(mode: .offline, succeeded: true, paints: false),
        ]
        for row in rows {
            XCTAssertEqual(row.mode.paintsHouse(readSucceeded: row.succeeded), row.paints)
        }
    }

    func testHomeStaysPutOnAGoodRead() {
        XCTAssertFalse(ConnectionMode.home.looksAgain(readFailed: false, keyRejected: false))
    }

    func testAHealthyLiveGatewayKeepsLookingForHome() throws {
        XCTAssertTrue(ConnectionMode.awayLive(try gateway()).looksAgain(readFailed: false, keyRejected: false))
    }
}

private struct PaintRow {
    var mode: ConnectionMode
    var succeeded: Bool
    var paints: Bool
}
