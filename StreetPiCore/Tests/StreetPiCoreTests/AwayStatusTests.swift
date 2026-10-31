import Foundation
import XCTest
@testable import StreetPiCore

final class AwayStatusTests: XCTestCase {
    private let now = Date.streetFixtureNow

    private func setup() throws -> MailboxSetup {
        MailboxSetup(
            address: try XCTUnwrap(MailboxAddress(text: "https://mailbox.example.test")),
            token: try XCTUnwrap(MailboxToken(text: "fixture-not-a-real-read-token"))
        )
    }

    private func freshness(age: TimeInterval) -> AwayFreshness {
        AwayFreshness.make(generatedAt: now.addingTimeInterval(-age), now: now)
    }

    func testModePrefersThePi() throws {
        XCTAssertEqual(HouseMode.choose(piAnswered: true, setup: try setup()), .home)
        XCTAssertEqual(HouseMode.choose(piAnswered: true, setup: nil), .home)
    }

    func testModeFallsBackToTheMailbox() throws {
        let setup = try setup()
        XCTAssertEqual(HouseMode.choose(piAnswered: false, setup: setup), .away(setup))
    }

    func testModeWithNoMailboxKeepsTryingThePi() {
        XCTAssertEqual(HouseMode.choose(piAnswered: false, setup: nil), .homeOnly)
    }

    func testFreshUnderAMinute() {
        XCTAssertEqual(freshness(age: 12).line, "Away · updated 12s ago")
        XCTAssertEqual(freshness(age: 59.9).level, .fresh)
        XCTAssertEqual(freshness(age: 1).spoken, "Away from home. Updated 1 second ago.")
    }

    func testStaleFromAMinute() {
        XCTAssertEqual(freshness(age: 60).level, .stale)
        XCTAssertEqual(freshness(age: 60).line, "Away · updated 1 min ago")
        XCTAssertEqual(freshness(age: 179.9).level, .stale)
    }

    func testSilentFromThreeMinutes() {
        XCTAssertEqual(freshness(age: 180).level, .silent)
        XCTAssertEqual(freshness(age: 180).line, "Pi hasn't reported in 3 min")
        XCTAssertEqual(freshness(age: 3 * 3_600).line, "Pi hasn't reported in 3 hr")
        XCTAssertEqual(freshness(age: 3 * 3_600).spoken, "The Pi hasn't reported in 3 hours.")
    }

    func testAClockAheadOfThePhoneReadsAsNew() {
        XCTAssertEqual(freshness(age: -30).line, "Away · updated 0s ago")
    }

    func testBadgeSymbolChangesWithTheTone() {
        let badges = [12.0, 90, 400].map { age in
            AwayStatus.reading(generatedAt: now.addingTimeInterval(-age), problem: nil, note: nil).badge(now: now)
        }
        XCTAssertEqual(badges.map(\.tone), [.calm, .attention, .problem])
        XCTAssertEqual(Set(badges.map(\.symbol)).count, 3)
    }

    func testBadgeKeepsTheAgeAndSaysWhatWentWrong() {
        let status = AwayStatus.reading(generatedAt: now.addingTimeInterval(-90), problem: .offline, note: nil)
        let badge = status.badge(now: now)
        XCTAssertEqual(badge.line, "Away · updated 1 min ago")
        XCTAssertEqual(badge.detail, "Can't reach the mailbox right now.")
        XCTAssertTrue(badge.spoken.hasSuffix("Can't reach the mailbox right now."))
    }

    func testTheHeadlineStopsGuessingOnceThePiGoesQuiet() {
        func status(age: TimeInterval) -> AwayStatus {
            .reading(generatedAt: now.addingTimeInterval(-age), problem: nil, note: nil)
        }
        XCTAssertNil(status(age: 179).quietHeadline(now: now))
        XCTAssertEqual(status(age: 180).quietHeadline(now: now), AwayCopy.quietHeadline)
        XCTAssertNil(AwayStatus.notSetUp.quietHeadline(now: now))
    }

    func testBadgeBeforeTheFirstReport() {
        let badge = AwayStatus.reading(generatedAt: nil, problem: nil, note: nil).badge(now: now)
        XCTAssertEqual(badge.line, "Away · waiting for the Pi's first report")
    }

    func testBadgeSendsATokenProblemToSettings() {
        let refused = AwayStatus.reading(generatedAt: nil, problem: .refused, note: nil).badge(now: now)
        XCTAssertTrue(refused.offersSetup)
        let offline = AwayStatus.reading(generatedAt: nil, problem: .offline, note: nil).badge(now: now)
        XCTAssertFalse(offline.offersSetup)
    }

    func testNotSetUpOffersSetupAndLeavesControlsOpen() {
        XCTAssertTrue(AwayStatus.notSetUp.badge(now: now).offersSetup)
        XCTAssertFalse(AwayStatus.notSetUp.isAway)
        XCTAssertTrue(AwayStatus.reading(generatedAt: nil, problem: nil, note: nil).isAway)
    }

    func testGateOpensOnlyToday() {
        XCTAssertEqual(DNSPage.allCases.filter(AwayGate.allows), [.today])
    }

    func testGateKeepsPiPagesWithNumbers() {
        XCTAssertEqual(MachinePage.allCases.filter(AwayGate.allows), [.dashboard, .chart, .services])
    }

    func testGateRefusesEveryWrite() {
        let writes: [HouseholdAction] = [
            .pauseAdBlocking(.thirtySeconds), .resumeAdBlocking, .blockDomain(named: "ads.example.test"),
            .allowDomain(named: "news.example.test"), .updateBlockLists, .signOutOfAdBlocker,
        ]
        XCTAssertTrue(writes.allSatisfy { !AwayGate.allows($0) })
        XCTAssertTrue(AwayGate.allows(.refresh))
    }

    func testPollWaitsLongerAfterAMiss() {
        XCTAssertEqual(AwayPace.waitSeconds(afterFailures: 0), 15)
        XCTAssertEqual(AwayPace.waitSeconds(afterFailures: 1), 60)
        XCTAssertEqual(AwayPace.waitSeconds(afterFailures: 9), 300)
    }
}
