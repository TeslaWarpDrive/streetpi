import XCTest
@testable import StreetPiCore

final class HomeBoardTests: XCTestCase {
    private let now = Date.streetFixtureNow

    func testHealthyBoardUsesTheDayShare() {
        let board = HomeBoard.make(
            snapshot: .healthyFixture,
            desk: .houseFixture,
            status: StatusNarrator.narrate(.healthyFixture, now: now),
            now: now
        )
        XCTAssertEqual(board.title, "Pi Stats")
        XCTAssertEqual(board.statusTitle, "Everything's good")
        XCTAssertEqual(board.statusAccent, "good")
        XCTAssertEqual(board.checkedLine, "Checked just now")
        XCTAssertEqual(board.adBlocker.stateWord, "ON")
        XCTAssertEqual(board.adBlocker.percentText, "20%")
        XCTAssertEqual(board.adBlocker.blockedText, "405")
        XCTAssertEqual(board.adBlocker.lookupsText, "2,049")
        XCTAssertEqual(board.adBlocker.lastHourText, "6")
        XCTAssertEqual(
            board.adBlocker.fractionLine,
            "About 1 in 5 things your devices tried to load was an ad or tracker."
        )
        XCTAssertEqual(board.adBlocker.hourlyStopped.count, 24)
        XCTAssertEqual(board.pi.temperature, "47°")
        XCTAssertEqual(board.pi.warmth, "Cool")
        XCTAssertEqual(board.pi.meters.map(\.title), ["CPU", "RAM", "Disk"])
        XCTAssertEqual(board.services.map(\.title), ["Streaming", "Remote", "DNS", "Address"])
        XCTAssertEqual(board.services.map(\.word), ["Up", "Ready", "On", "Current"])
        XCTAssertEqual(board.monitors.summary, "7 of 7 up")
        XCTAssertEqual(board.monitors.monitors.count, 7)
        XCTAssertEqual(board.backups.value, "Copied")
        XCTAssertEqual(board.uptime.value, "12 days")
        XCTAssertEqual(board.devices.value, "4")
        XCTAssertEqual(board.footer, HomeBoard.footerLine)
        XCTAssertFalse(board.adBlocker.fractionLine.contains("not live"))
    }

    func testEmptyBoardDoesNotInventCounts() {
        let board = HomeBoard.make(
            snapshot: nil,
            desk: .houseFixture,
            status: PlainEnglishStatus(
                headline: HouseReadingCopy.emptyTitle,
                detail: HouseReadingCopy.emptyDetail,
                tone: .calm,
                linkLine: "No reading yet"
            ),
            now: now
        )
        XCTAssertEqual(board.adBlocker.percentText, "—")
        XCTAssertEqual(board.adBlocker.stateWord, "Quiet")
        XCTAssertEqual(board.checkedLine, "Not checked yet")
        XCTAssertEqual(board.devices.value, "—")
        XCTAssertEqual(board.monitors.summary, "None yet")
        XCTAssertTrue(board.services.allSatisfy { $0.word == "Quiet" })
    }

    func testShareLineRoundsToAPlainFraction() {
        XCTAssertEqual(
            BlockedShare.line(blocked: 1, lookups: 3),
            "About 1 in 3 things your devices tried to load was an ad or tracker."
        )
        XCTAssertEqual(BlockedShare.percent(blocked: 405, lookups: 2_049), 20)
        XCTAssertEqual(
            BlockedShare.line(blocked: 0, lookups: 10),
            "Nothing your devices tried to load was an ad or tracker."
        )
        XCTAssertNil(BlockedShare.percent(blocked: 0, lookups: 0))
    }

    func testWarmthBandsStayCoolWarmHot() {
        XCTAssertEqual(PiWarmthWord.word(celsius: 47.2), "Cool")
        XCTAssertEqual(PiWarmthWord.word(celsius: 72), "Warm")
        XCTAssertEqual(PiWarmthWord.word(celsius: 81), "Hot")
    }

    func testPauseShortTitles() {
        XCTAssertEqual(PauseLength.thirtySeconds.shortTitle, "30 sec")
        XCTAssertEqual(PauseLength.fiveMinutes.shortTitle, "5 min")
        XCTAssertEqual(PauseLength.thirtyMinutes.shortTitle, "30 min")
    }

    func testCheckedLineUsesMinutes() {
        let past = now.addingTimeInterval(-120)
        XCTAssertEqual(CheckedPhrase.english(from: past, now: now), "Checked 2 min ago")
    }
}
