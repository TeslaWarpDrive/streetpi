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

    /// A successful log half stays off the desk while the badge says the Pi is out of reach.
    /// A miss on the other half, or a later miss that returns the withheld feed, still must not publish it.
    func testAnOfflineLogSuccessStaysOffTheDesk() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let older = DNSQuery(id: "1", domain: "old.example.test", client: "Kitchen", outcome: .allowed, at: now)
        let fresh = DNSQuery(
            id: "9", domain: "news.example.test", client: "Kitchen", outcome: .allowed, at: now.addingTimeInterval(5)
        )
        let liveMiss = "The live log could not be read."
        let textMiss = "The text log could not be read."
        let desk = DNSDesk.quiet

        let liveSucceeded = desk.applyingLiveLog(
            queries: LiveLogFeed(queries: [fresh]),
            liveNote: nil,
            text: TextLogFeed(lines: ["gravity updated"], fileEnabled: true),
            textNote: textMiss,
            mode: .offline
        )
        XCTAssertNil(liveSucceeded.liveFeed)
        XCTAssertNil(liveSucceeded.liveReadNote)
        XCTAssertEqual(liveSucceeded.textLogLines, [])
        XCTAssertFalse(liveSucceeded.textLogKnown)
        XCTAssertFalse(liveSucceeded.textLogFileEnabled)
        XCTAssertEqual(liveSucceeded.textLogReadNote, textMiss)

        let textSucceeded = desk.applyingLiveLog(
            queries: LiveLogFeed(queries: [fresh]),
            liveNote: liveMiss,
            text: TextLogFeed(lines: ["gravity updated"], fileEnabled: true),
            textNote: nil,
            mode: .offline
        )
        XCTAssertNil(textSucceeded.liveFeed)
        XCTAssertEqual(textSucceeded.liveReadNote, liveMiss)
        XCTAssertEqual(textSucceeded.textLogLines, [])
        XCTAssertFalse(textSucceeded.textLogKnown)
        XCTAssertFalse(textSucceeded.textLogFileEnabled)
        XCTAssertNil(textSucceeded.textLogReadNote)

        var shown = DNSDesk.quiet
        shown.liveFeed = [older]
        shown.textLogLines = ["already shown"]
        shown.textLogKnown = true
        let withheld = shown.applyingLiveLog(
            queries: LiveLogFeed(queries: [fresh, older]),
            liveNote: nil,
            text: TextLogFeed(lines: ["already shown", "new line"], fileEnabled: true),
            textNote: nil,
            mode: .offline
        )
        XCTAssertEqual(withheld.liveFeed, [older])
        XCTAssertEqual(withheld.textLogLines, ["already shown"])
        XCTAssertTrue(withheld.textLogKnown)
        XCTAssertNil(withheld.liveReadNote)
        XCTAssertNil(withheld.textLogReadNote)

        let later = withheld.applyingLiveLog(
            queries: LiveLogFeed(queries: [fresh, older]),
            liveNote: LiveReadCopy.offline,
            text: TextLogFeed(lines: ["already shown", "new line"], fileEnabled: true),
            textNote: LiveReadCopy.offline,
            mode: .offline
        )
        XCTAssertEqual(later.liveFeed, [older])
        XCTAssertEqual(later.textLogLines, ["already shown"])
        XCTAssertTrue(later.textLogKnown)
        XCTAssertEqual(later.liveReadNote, LiveReadCopy.offline)
        XCTAssertEqual(later.textLogReadNote, LiveReadCopy.offline)

        for mode in [ConnectionMode.home, .awayLive(try gateway()), .awayMailbox(try mailbox())] {
            let painted = desk.applyingLiveLog(
                queries: LiveLogFeed(queries: [fresh]),
                liveNote: nil,
                text: TextLogFeed(lines: ["gravity updated"], fileEnabled: true),
                textNote: nil,
                mode: mode
            )
            XCTAssertEqual(painted.liveFeed, [fresh])
            XCTAssertEqual(painted.textLogLines, ["gravity updated"])
            XCTAssertTrue(painted.textLogKnown)
            XCTAssertTrue(painted.textLogFileEnabled)
            XCTAssertNil(painted.liveReadNote)
            XCTAssertNil(painted.textLogReadNote)
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
