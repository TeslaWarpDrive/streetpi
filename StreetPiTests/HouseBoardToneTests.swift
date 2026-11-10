import StreetPiCore
import XCTest
@testable import StreetPi

final class HouseBoardToneTests: XCTestCase {
    func testFailedHouseDoesNotLookCalm() {
        let board = HouseBoard.make(screen: .failed, desk: .houseFixture, now: .streetFixtureNow)
        XCTAssertEqual(board.tone, .problem)
    }

    func testMissingStatusPageCarriesItsAttentionTone() {
        let board = HouseBoard.make(
            screen: .ready(.healthyFixture),
            desk: .houseFixture,
            now: .streetFixtureNow
        )
        let missing = HouseBoard.applying(status: .notSetUp(), to: board)
        XCTAssertEqual(missing.headline, StatusPageCopy.notSetUp)
        XCTAssertEqual(missing.tone, .attention)
    }

    /// "Ready" and "Up to date" are healthy words too, so a mark reads the row's tone.
    func testHealthyWordsDrawAsUp() {
        let rows = [
            GroupRow(id: "remote", name: "Remote", state: "Ready", tone: .calm),
            GroupRow(id: "address", name: "Address", state: "Up to date", tone: .calm),
            GroupRow(id: "proxy", name: "Proxy", state: "Not responding", tone: .problem),
        ]
        let tile = HouseStatusTile(id: .monitors, title: "Monitors", summary: "2 of 3 up", tone: .problem, rows: rows)
        let board = HouseBoard.make(screen: .ready(.healthyFixture), desk: .houseFixture, now: .streetFixtureNow)
        let status = HouseStatusBoard(tiles: [tile], services: [], isMissing: false)
        let marks = HouseBoard.applying(status: status, to: board).monitors.marks
        XCTAssertEqual(marks.map(\.up), [true, true, false])
    }

    /// A calm status page used to put "The house is up." back over the certificate sentence.
    /// House then looked fine while Ad blocker still showed the prompt.
    func testHealthyStatusDoesNotCoverCertificateHeadline() {
        let failed = AdBlockerHome.failed(.certificateChanged, now: .streetFixtureNow)
        let board = HouseBoard.make(
            screen: .explained(failed.status, failed.snapshot),
            desk: failed.desk,
            now: .streetFixtureNow
        )
        let calm = calmStatusPage()
        XCTAssertEqual(board.headline, PiholeProblem.certificateChanged.title)
        XCTAssertEqual(board.tone, .attention)
        XCTAssertEqual(board.blocker.stateWord, "Quiet")
        XCTAssertEqual(calm.briefing.headline, "The house is up.")
        XCTAssertEqual(calm.briefing.tone, .calm)

        let applied = HouseBoard.applying(status: calm, to: board)
        XCTAssertEqual(applied.headline, PiholeProblem.certificateChanged.title)
        XCTAssertEqual(applied.tone, .attention)
        XCTAssertEqual(applied.blocker.stateWord, "Quiet")
        XCTAssertEqual(applied.blocker.fractionLine, PiholeProblem.certificateChanged.title)
        XCTAssertFalse(applied.blocker.canPause)
        XCTAssertEqual(applied.squares.map(\.title), ["Streaming", "Remote", "Internet/DNS", "Address"])
    }

    func testHealthyStatusDoesNotCoverAdBlockerFailure() {
        let failed = AdBlockerHome.offline(now: .streetFixtureNow)
        let board = HouseBoard.make(
            screen: .explained(failed.status, failed.snapshot),
            desk: failed.desk,
            now: .streetFixtureNow
        )
        XCTAssertEqual(board.headline, AdBlockerVoice.unreachableTitle)

        let applied = HouseBoard.applying(status: calmStatusPage(), to: board)
        XCTAssertEqual(applied.headline, AdBlockerVoice.unreachableTitle)
        XCTAssertEqual(applied.tone, board.tone)
        XCTAssertEqual(applied.blocker.stateWord, "Quiet")
    }

    func testHealthyStatusDoesNotCoverUnreachableHouse() {
        let board = HouseBoard.make(screen: .failed, desk: .houseFixture, now: .streetFixtureNow)
        XCTAssertEqual(board.headline, HouseReadingCopy.unreachableTitle)
        XCTAssertEqual(board.tone, .problem)

        let applied = HouseBoard.applying(status: calmStatusPage(), to: board)
        XCTAssertEqual(applied.headline, HouseReadingCopy.unreachableTitle)
        XCTAssertEqual(applied.tone, .problem)
    }

    func testHealthyStatusStillReplacesACalmHouse() {
        let board = HouseBoard.make(
            screen: .ready(.healthyFixture),
            desk: .houseFixture,
            now: .streetFixtureNow
        )
        XCTAssertEqual(board.headline, "Everything's good.")
        XCTAssertEqual(board.tone, .calm)

        let applied = HouseBoard.applying(status: calmStatusPage(), to: board)
        XCTAssertEqual(applied.headline, "The house is up.")
        XCTAssertEqual(applied.tone, .calm)
    }

    /// A narrated outage is not a failed read. The status page may still say the house is up.
    func testHealthyStatusStillReplacesANarratedOutage() {
        var house = HouseholdSnapshot.healthyFixture
        house.services[0].state = .notResponding
        let board = HouseBoard.make(screen: .ready(house), desk: .houseFixture, now: .streetFixtureNow)
        XCTAssertEqual(board.headline, "The ad blocker is down.")
        XCTAssertEqual(board.tone, .problem)

        let applied = HouseBoard.applying(status: calmStatusPage(), to: board)
        XCTAssertEqual(applied.headline, "The house is up.")
        XCTAssertEqual(applied.tone, .calm)
    }

    /// Mailbox uncertainty is not a certificate or a failed read.
    func testHealthyStatusStillReplacesAnUncertainAwayLine() {
        var desk = DNSDesk.quiet
        desk.spokenLine = AwayCopy.notSure
        let snapshot = HouseholdSnapshot(
            capturedAt: .streetFixtureNow,
            link: .away(cachedAt: .streetFixtureNow),
            services: [],
            machine: nil,
            dns: nil
        )
        let screen = HouseScreen.explained(
            PlainEnglishStatus(
                headline: "Everything's good.",
                detail: nil,
                tone: .calm,
                linkLine: AwayCopy.awayChip
            ),
            snapshot
        )
        let board = HouseBoard.make(screen: screen, desk: desk, now: .streetFixtureNow)
        XCTAssertEqual(board.headline, AwayCopy.notSure)

        let applied = HouseBoard.applying(status: calmStatusPage(), to: board)
        XCTAssertEqual(applied.headline, "The house is up.")
        XCTAssertEqual(applied.tone, .calm)
    }

    /// Trouble on the status page may still name itself. Only a healthy line is refused.
    func testTroubledStatusStillReplacesCertificateHeadline() {
        let failed = AdBlockerHome.failed(.certificateChanged, now: .streetFixtureNow)
        let board = HouseBoard.make(
            screen: .explained(failed.status, failed.snapshot),
            desk: failed.desk,
            now: .streetFixtureNow
        )
        var status = calmStatusPage()
        status.tiles[0].tone = .problem
        status.tiles[0].summary = "Streaming is down."

        let applied = HouseBoard.applying(status: status, to: board)
        XCTAssertEqual(applied.headline, "Streaming is down.")
        XCTAssertEqual(applied.tone, .problem)
        XCTAssertEqual(
            applied.squares.map(\.word),
            ["Streaming is down.", "Remote help is up.", "Internet is up.", "Address is up to date."]
        )
    }

    private func calmStatusPage() -> HouseStatusBoard {
        HouseStatusBoard(
            tiles: [
                HouseStatusTile(
                    id: .streaming, title: "Streaming", summary: "Streaming is up.", tone: .calm, rows: []
                ),
                HouseStatusTile(
                    id: .remoteHelp, title: "Remote", summary: "Remote help is up.", tone: .calm, rows: []
                ),
                HouseStatusTile(
                    id: .internet, title: "Internet/DNS", summary: "Internet is up.", tone: .calm, rows: []
                ),
                HouseStatusTile(
                    id: .address, title: "Address", summary: "Address is up to date.", tone: .calm, rows: []
                ),
            ],
            services: [],
            isMissing: false
        )
    }
}
