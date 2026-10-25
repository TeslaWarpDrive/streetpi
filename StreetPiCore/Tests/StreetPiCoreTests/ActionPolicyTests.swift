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
}
