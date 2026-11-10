import XCTest
@testable import StreetPiCore

final class ActionPolicyTests: XCTestCase {
    func testRefreshNeedsNothing() {
        XCTAssertEqual(ActionPolicy.confirmation(for: .refresh), .notRequired)
    }

    func testFilterWritesExplainThemselvesAndUseFaceID() throws {
        let pause = ActionPolicy.confirmation(for: .pauseAdBlocking(.fiveMinutes))
        let resume = ActionPolicy.confirmation(for: .resumeAdBlocking)
        let block = ActionPolicy.confirmation(for: .blockDomain(named: "ads.example.test"))
        let allow = ActionPolicy.confirmation(for: .allowDomain(named: "news.example.test"))
        let lists = ActionPolicy.confirmation(for: .updateBlockLists)
        let custom = try XCTUnwrap(PauseLength(seconds: 12 * 60))
        let customPause = ActionPolicy.confirmation(for: .pauseAdBlocking(custom))

        for confirmation in [pause, resume, block, allow, customPause, lists] {
            XCTAssertTrue(confirmation.requiresFaceID)
            XCTAssertFalse(confirmation.explanation?.isEmpty ?? true)
        }
        XCTAssertTrue(pause.explanation?.contains("5 minutes") ?? false)
        XCTAssertTrue(pause.explanation?.contains("turns itself back on") ?? false)
        XCTAssertTrue(customPause.explanation?.contains("12 minutes") ?? false)
        XCTAssertTrue(resume.explanation?.contains("turn back on") ?? false)
        XCTAssertEqual(block.explanation, "ads.example.test will be blocked for the whole house.")
        XCTAssertEqual(allow.explanation, "news.example.test will be allowed for the whole house.")
        XCTAssertTrue(lists.explanation?.contains("Block lists") ?? false)
        XCTAssertTrue(lists.explanation?.contains("minute") ?? false)
        XCTAssertFalse(ActionPolicy.confirmation(for: .signOutOfAdBlocker).requiresFaceID)
    }

    func testMailboxAfterFaceIDRefusesTheWrite() throws {
        let pause = HouseholdAction.pauseAdBlocking(.fiveMinutes)
        let block = HouseholdAction.blockDomain(named: "ads.example.test")
        let allow = HouseholdAction.allowDomain(named: "news.example.test")
        let box = ConnectionMode.awayMailbox(try mailbox())
        let live = ConnectionMode.awayLive(try gateway())
        let sameRoad: [Row] = [
            Row(action: pause, mode: .home, faceID: .notAsked, step: .wait),
            Row(action: pause, mode: .home, faceID: .passed, step: .allow),
            Row(action: pause, mode: live, faceID: .passed, step: .allow),
            Row(action: block, mode: .home, faceID: .passed, step: .allow),
            Row(action: allow, mode: .home, faceID: .passed, step: .allow),
            Row(action: .refresh, mode: box, faceID: .notAsked, step: .allow),
            Row(action: .signOutOfAdBlocker, mode: .home, faceID: .notAsked, step: .allow),
            Row(action: .signOutOfAdBlocker, mode: box, faceID: .notAsked, step: .refuse),
        ]
        for row in sameRoad {
            XCTAssertEqual(ActionPolicy.confirmStep(row.action, mode: row.mode, faceID: row.faceID), row.step)
        }
        for action in [pause, block, allow] {
            XCTAssertEqual(ActionPolicy.confirmStep(action, mode: box, faceID: .passed), .refuse)
            XCTAssertEqual(ActionPolicy.confirmStep(action, mode: box, faceID: .notAsked), .refuse)
        }
        // Face ID does not send these while the Pi is out of reach.
        let resume = HouseholdAction.resumeAdBlocking
        for action in [pause, resume, block, allow] {
            XCTAssertEqual(ActionPolicy.confirmStep(action, mode: .offline, faceID: .passed), .refuse)
            XCTAssertEqual(ActionPolicy.confirmStep(action, mode: .offline, faceID: .notAsked), .refuse)
        }
    }

    /// Deny stays on wait so the sheet can stay up. Cancel and failure are not a send.
    func testCancelOrFailedFaceIDDoesNotSend() {
        let pause = HouseholdAction.pauseAdBlocking(.fiveMinutes)
        let block = HouseholdAction.blockDomain(named: "ads.example.test")
        let allow = HouseholdAction.allowDomain(named: "news.example.test")
        for action in [pause, block, allow] {
            XCTAssertEqual(ActionPolicy.confirmStep(action, mode: .home, faceID: .cancelled), .wait)
            XCTAssertEqual(ActionPolicy.confirmStep(action, mode: .home, faceID: .failed), .wait)
            XCTAssertNotEqual(ActionPolicy.confirmStep(action, mode: .home, faceID: .cancelled), .allow)
            XCTAssertNotEqual(ActionPolicy.confirmStep(action, mode: .home, faceID: .failed), .allow)
        }
        XCTAssertEqual(ActionPolicy.confirmStep(pause, mode: .home, faceID: .denied), .wait)
        XCTAssertEqual(ActionPolicy.confirmStep(pause, mode: .home, faceID: .passed), .allow)
    }

    func testCopyDoesNotNameAPersonOrAPrivateAddress() throws {
        let custom = try XCTUnwrap(PauseLength(seconds: 120))
        let actions: [HouseholdAction] = [
            .pauseAdBlocking(.fiveMinutes), .pauseAdBlocking(custom), .resumeAdBlocking,
            .blockDomain(named: "ads.example.test"),
            .allowDomain(named: "news.example.test"),
            .updateBlockLists,
            .signOutOfAdBlocker,
        ]
        for action in actions {
            let text = ActionPolicy.confirmation(for: action).explanation ?? ""
            XCTAssertFalse(text.localizedCaseInsensitiveContains("bradley"))
            XCTAssertFalse(text.localizedCaseInsensitiveContains("brandy"))
            XCTAssertFalse(text.localizedCaseInsensitiveContains("admin"))
            XCTAssertFalse(text.contains("192.168"))
        }
    }

    private struct Row {
        var action: HouseholdAction
        var mode: ConnectionMode
        var faceID: FaceIDPrompt
        var step: ConfirmStep
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
