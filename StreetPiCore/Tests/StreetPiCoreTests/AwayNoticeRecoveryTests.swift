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

    func testASettledRoadDoesNotProbeOnEveryRead() throws {
        for mode in [ConnectionMode.home, .awayLive(try gateway()), .awayMailbox(try mailbox())] {
            XCTAssertFalse(mode.looksAgain(readFailed: false, keyRejected: false))
        }
    }
}
