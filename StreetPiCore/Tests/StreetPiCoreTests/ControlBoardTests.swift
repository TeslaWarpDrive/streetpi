import XCTest
@testable import StreetPiCore

final class ControlBoardTests: XCTestCase {
    func testHouseFixtureIsAboutOneInFive() {
        let share = LookupShare.from(desk: .houseFixture)
        XCTAssertEqual(share.lookups, 2_049)
        XCTAssertEqual(share.stopped, 405)
        XCTAssertEqual(share.percent, 20)
        XCTAssertEqual(share.percentText, "20%")
        XCTAssertEqual(share.lastHourStopped, 6)
        XCTAssertEqual(
            share.fractionLine,
            "About 1 in 5 things your devices tried to load was an ad or tracker."
        )
        XCTAssertTrue(share.explainer.contains("divided by every lookup"))
        XCTAssertTrue(share.explainer.contains(share.fractionLine))
    }

    func testOneInThreeIsGeneratedFromTheCounts() {
        let share = LookupShare(stopped: 30, lookups: 90)
        XCTAssertEqual(share.percent, 33)
        XCTAssertEqual(LookupFraction.denominator(stopped: 30, lookups: 90), 3)
        XCTAssertEqual(
            share.fractionLine,
            "About 1 in 3 things your devices tried to load was an ad or tracker."
        )
    }

    func testEmptyAndFullWindows() {
        XCTAssertEqual(
            LookupFraction.line(stopped: 0, lookups: 0),
            "No lookups in the last 24 hours."
        )
        XCTAssertEqual(
            LookupFraction.line(stopped: 0, lookups: 40),
            "Nothing your devices tried to load was an ad or tracker."
        )
        XCTAssertEqual(
            LookupFraction.line(stopped: 12, lookups: 12),
            "About everything your devices tried to load was an ad or tracker."
        )
        XCTAssertEqual(LookupFraction.percent(stopped: 12, lookups: 12), 100)
        XCTAssertNil(LookupFraction.denominator(stopped: 0, lookups: 10))
    }

    func testMatchingKeepsHoursOnlyWhenTotalsAgree() {
        let matched = LookupShare.matching(summary: HouseholdSnapshot.healthyFixture.dns, desk: .houseFixture)
        XCTAssertEqual(matched?.hourlyStopped.count, 24 as Int?)
        let other = DNSSummary(blockingEnabled: true, queriesToday: 10, blockedToday: 2)
        let summaryOnly = LookupShare.matching(summary: other, desk: .houseFixture)
        XCTAssertEqual(summaryOnly?.lookups, 10 as Int?)
        XCTAssertEqual(summaryOnly?.hourlyStopped.isEmpty, true as Bool?)
        XCTAssertNil(LookupShare.matching(summary: HouseholdSnapshot.awayFreshFixture.dns, desk: .houseFixture))
    }

    func testPiWarmthUsesThreeWords() {
        XCTAssertEqual(PiWarmth.word(celsius: 47.2), "Cool")
        XCTAssertEqual(PiWarmth.word(celsius: 70), "Warm")
        XCTAssertEqual(PiWarmth.word(celsius: 80), "Hot")
        XCTAssertEqual(ReadingText.warmth(47.2), "Cool")
    }

    func testHealthyBoardFillsTheTiles() {
        let board = ControlBoardBuilder.make(
            snapshot: .healthyFixture,
            share: .from(desk: .houseFixture),
            deviceCount: DNSDesk.houseFixture.knownClients,
            headline: "Everything's good.",
            now: .streetFixtureNow
        )
        XCTAssertEqual(board.headline, "Everything's good.")
        XCTAssertEqual(board.checkedLine, "Checked just now")
        XCTAssertEqual(board.blocker.stateWord, "ON")
        XCTAssertEqual(board.blocker.percentText, "20%")
        XCTAssertTrue(board.blocker.canPause)
        XCTAssertEqual(board.pi.temperature, "47°")
        XCTAssertEqual(board.pi.warmth, "Cool")
        XCTAssertEqual(board.pi.line, "The Pi is cool.")
        XCTAssertEqual(board.squares.map(\.title), ["Streaming", "Remote", "DNS", "Address"])
        XCTAssertEqual(board.squares.map(\.word), ["Up", "Ready", "On", "Current"])
        XCTAssertEqual(board.monitors.figure, "8 of 8")
        XCTAssertEqual(board.monitors.marks.count, 8)
        XCTAssertEqual(board.monitors.line, "All 8 are answering.")
        XCTAssertEqual(board.backups.figure, "Copied")
        XCTAssertEqual(board.running.figure, "12 days")
        XCTAssertEqual(board.running.line, "The Pi has been on for 12 days.")
        XCTAssertEqual(board.devices.figure, "4")
        XCTAssertEqual(board.devices.line, "4 devices have asked for a name.")
    }

    func testDownDNSAndMissingReading() {
        let board = ControlBoardBuilder.make(
            snapshot: .awayTroubleFixture,
            share: nil,
            deviceCount: nil,
            headline: "The ad blocker is down.",
            now: .streetFixtureNow
        )
        XCTAssertEqual(board.squares.first { $0.id == "dns" }?.word, "Down" as String?)
        XCTAssertEqual(board.blocker.percentText, "—")
        XCTAssertTrue(board.blocker.canPause)
        XCTAssertEqual(board.devices.figure, "—")

        let empty = ControlBoardBuilder.make(
            snapshot: nil,
            share: nil,
            deviceCount: nil,
            headline: "The Pi is not answering.",
            now: .streetFixtureNow
        )
        XCTAssertEqual(empty.checkedLine, "Not checked yet")
        XCTAssertFalse(empty.blocker.canPause)
        XCTAssertEqual(empty.squares.map(\.word), ["Quiet", "Quiet", "Quiet", "Quiet"])
        XCTAssertEqual(empty.monitors.figure, "None")
        XCTAssertEqual(empty.pi.line, "No reading from the Pi yet.")
    }

    func testPausedBlockingChangesTheSquare() {
        var snapshot = HouseholdSnapshot.healthyFixture
        snapshot.dns = DNSSummary(blockingEnabled: false, queriesToday: 2_049, blockedToday: 405)
        let board = ControlBoardBuilder.make(
            snapshot: snapshot,
            share: .from(desk: .houseFixture),
            deviceCount: 1,
            headline: "Ad blocking is paused.",
            now: .streetFixtureNow
        )
        XCTAssertEqual(board.blocker.stateWord, "Paused")
        XCTAssertFalse(board.blocker.canPause)
        XCTAssertEqual(board.squares.first { $0.id == "dns" }?.word, "Paused" as String?)
        XCTAssertEqual(board.devices.line, "1 device has asked for a name.")
    }
}
