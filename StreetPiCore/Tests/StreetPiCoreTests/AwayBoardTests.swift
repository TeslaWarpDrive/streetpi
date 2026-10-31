import Foundation
import XCTest
@testable import StreetPiCore

private struct Replies: MailboxTransport {
    final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var stored = 0

        func bump() {
            lock.lock()
            stored += 1
            lock.unlock()
        }

        var value: Int {
            lock.lock()
            defer { lock.unlock() }
            return stored
        }
    }

    var latest: MailboxReply
    var history: MailboxReply
    var historyReads = Counter()

    func get(_ url: URL, token: MailboxToken) async throws -> MailboxReply {
        if url.path.hasSuffix("history") {
            historyReads.bump()
            return history
        }
        return latest
    }
}

final class AwayBoardTests: XCTestCase {
    private let now = Date.streetFixtureNow

    private func live(_ change: (inout AwaySnapshot) throws -> Void = { _ in }) throws -> AwaySnapshot {
        var snapshot = try FixtureBook.away(named: "away-live")
        try change(&snapshot)
        return snapshot
    }

    private func tile(_ group: HouseGroup, in board: AwayBoard) throws -> HouseStatusTile {
        try XCTUnwrap(board.status?.tiles.first { $0.id == group })
    }

    func testHouseNumbersComeFromTheReport() throws {
        let latest = try live()
        let board = AwayBoard.make(latest: latest, history: nil)
        let snapshot = try XCTUnwrap(board.snapshot)
        XCTAssertEqual(snapshot.link, .away(cachedAt: latest.generatedAt))
        XCTAssertEqual(try XCTUnwrap(snapshot.machine?.cpuUsedFraction), 0.074, accuracy: 0.0001)
        XCTAssertEqual(snapshot.machine?.temperatureCelsius, 52.1)
        XCTAssertEqual(snapshot.machine?.uptimeSeconds, 1_209_600)
        XCTAssertEqual(snapshot.dns?.blockingEnabled, true)
        XCTAssertEqual(snapshot.dns?.queriesToday, 41_234)
        XCTAssertEqual(board.desk.knownClients, 14)
    }

    func testAdBlockerOverviewKeepsTheReportedShareWithoutHours() throws {
        let board = AwayBoard.make(latest: try live(), history: nil)
        XCTAssertFalse(board.desk.hasDayLookups)
        let share = LookupShare.from(desk: board.desk)
        XCTAssertEqual(share.stopped, 6_120)
        XCTAssertEqual(share.lookups, 41_234)
    }

    func testHistoryFillsTheHoursAndTheChart() throws {
        let board = try FixtureBook.awayBoard()
        XCTAssertEqual(board.desk.day.count, 24)
        XCTAssertTrue(board.desk.hasDayLookups)
        XCTAssertEqual(board.machine.series.map(\.id), ["cpu"])
        let points = try XCTUnwrap(board.machine.series.first?.points)
        XCTAssertEqual(points.count, 24)
        XCTAssertTrue(points.allSatisfy { (0...23).contains($0.hour) && (0...1).contains($0.value) })
    }

    func testPiPagesSayWhatIsMissing() throws {
        let board = AwayBoard.make(latest: try live(), history: nil)
        XCTAssertTrue(board.machine.series.isEmpty)
        XCTAssertEqual(board.machine.chartNote, AwayCopy.chartWaiting)
        XCTAssertEqual(board.machine.alertNote, AwayCopy.alertsAtHome)
    }

    func testChecksJoinTheirSections() throws {
        let board = AwayBoard.make(latest: try live(), history: nil)
        XCTAssertEqual(try tile(.streaming, in: board).summary, "Streaming is up.")
        XCTAssertEqual(try tile(.remoteHelp, in: board).summary, "Remote help is up.")
        XCTAssertEqual(try tile(.internet, in: board).tone, .calm)
        XCTAssertEqual(try tile(.monitors, in: board).summary, "8 of 8 up")
    }

    func testMonitorRowsAreTheReportedChecks() throws {
        let board = AwayBoard.make(latest: try live(), history: nil)
        XCTAssertEqual(try tile(.monitors, in: board).rows.count, 8)
    }

    func testTheProxyDrivesStreaming() throws {
        let latest = try live { $0.streamingProxy = try Self.proxy(healthy: false) }
        let board = AwayBoard.make(latest: latest, history: nil)
        XCTAssertEqual(try tile(.streaming, in: board).summary, "Streaming is down.")
        XCTAssertEqual(board.status?.briefing.tone, .problem)
    }

    private static func proxy(healthy: Bool) throws -> AwayStreamingProxy {
        try JSONDecoder().decode(AwayStreamingProxy.self, from: Data("{\"healthy\":\(healthy)}".utf8))
    }

    func testAnEmptySectionDoesNotRaiseAnAlarm() throws {
        let latest = try live { $0.monitors?.items = [] }
        let board = AwayBoard.make(latest: latest, history: nil)
        XCTAssertEqual(try tile(.smartHome, in: board).summary, AwayCopy.notInReport)
        XCTAssertEqual(try tile(.smartHome, in: board).tone, .calm)
    }

    func testAFailedCheckPartIsNamed() throws {
        let latest = try live { $0.monitors = nil }
        let board = AwayBoard.make(latest: latest, history: nil)
        XCTAssertEqual(try tile(.monitors, in: board).summary, AwayCopy.noChecks)
        XCTAssertEqual(board.status?.briefing.tone, .attention)
    }

    func testAMonitorThatIsDownOffTheListStillCounts() throws {
        let latest = try live {
            $0.monitors?.up = 7
            $0.monitors?.down = 1
        }
        let board = AwayBoard.make(latest: latest, history: nil)
        XCTAssertEqual(try tile(.monitors, in: board).summary, "7 of 8 up")
        XCTAssertEqual(try tile(.monitors, in: board).tone, .problem)
    }

    func testBackupStates() throws {
        let good = AwayBoard.make(latest: try live(), history: nil)
        XCTAssertTrue(try tile(.backups, in: good).summary.hasPrefix("Last backup:"))
        XCTAssertEqual(try tile(.backups, in: good).tone, .calm)

        let failed = AwayBoard.make(latest: try live { $0.backup?.ok = false }, history: nil)
        XCTAssertEqual(try tile(.backups, in: failed).summary, AwayCopy.backupFailed)
        XCTAssertEqual(try tile(.backups, in: failed).tone, .problem)

        let unknown = AwayBoard.make(latest: try live { $0.backup = nil }, history: nil)
        XCTAssertEqual(try tile(.backups, in: unknown).summary, AwayCopy.noBackupWord)
        XCTAssertEqual(try tile(.backups, in: unknown).tone, .calm)
    }

    func testAPartThatFailedIsEmptyNotZero() throws {
        let latest = try live {
            $0.machine = nil
            $0.adBlocker = nil
        }
        let board = AwayBoard.make(latest: latest, history: nil)
        XCTAssertNil(board.snapshot?.machine)
        XCTAssertNil(board.snapshot?.dns)
        XCTAssertEqual(board.piNotice, AwayCopy.noMeters)
        XCTAssertEqual(board.desk.spokenLine, AwayCopy.noChecks)
    }

    func testUnknownBlockingSaysSo() throws {
        let latest = try live { $0.adBlocker?.blocking = .unknown }
        let board = AwayBoard.make(latest: latest, history: nil)
        XCTAssertNil(board.snapshot?.dns)
        XCTAssertEqual(board.desk.spokenLine, AwayCopy.notSure)
    }

    func testPausedBlockingIsPaused() throws {
        let latest = try live { $0.adBlocker?.blocking = .disabled }
        let board = AwayBoard.make(latest: latest, history: nil)
        XCTAssertEqual(board.snapshot?.dns?.blockingEnabled, false)
        XCTAssertFalse(board.desk.blocking.enabled)
    }

    func testPrivateListsStayEmpty() throws {
        let desk = try FixtureBook.awayBoard().desk
        XCTAssertTrue(desk.clients.isEmpty)
        XCTAssertTrue(desk.queries.isEmpty)
        XCTAssertTrue(desk.topDomains.isEmpty)
        XCTAssertTrue(desk.topClients.isEmpty)
        XCTAssertTrue(desk.domains.isEmpty)
    }

    func testWaitingBoardCarriesNoReading() {
        XCTAssertNil(AwaySession().board.snapshot)
        XCTAssertNil(AwaySession().board.status)
        XCTAssertEqual(AwaySession().status, .reading(generatedAt: nil, problem: nil, note: nil))
    }

    // MARK: Session

    private func replies() throws -> Replies {
        let live = try Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: "away-live", withExtension: "json")))
        let row = try Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: "away-history", withExtension: "json")))
        let page = Data("{\"snapshots\":[".utf8) + row + Data("]}".utf8)
        return Replies(latest: MailboxReply(status: 200, body: live), history: MailboxReply(status: 200, body: page))
    }

    private func client(_ transport: Replies) throws -> MailboxClient<Replies> {
        MailboxClient(
            transport: transport,
            setup: MailboxSetup(
                address: try XCTUnwrap(MailboxAddress(text: "https://mailbox.example.test")),
                token: try XCTUnwrap(MailboxToken(text: "fixture-not-a-real-read-token"))
            )
        )
    }

    func testHistoryIsReadAtMostOnceAMinute() async throws {
        let transport = try replies()
        let client = try client(transport)
        var session = AwaySession()
        session = try await session.refreshed(using: client, now: now)
        session = try await session.refreshed(using: client, now: now.addingTimeInterval(15))
        session = try await session.refreshed(using: client, now: now.addingTimeInterval(59))
        XCTAssertEqual(transport.historyReads.value, 1)
        session = try await session.refreshed(using: client, now: now.addingTimeInterval(60))
        XCTAssertEqual(transport.historyReads.value, 2)
        XCTAssertNotNil(session.history)
    }

    func testAFailedHistoryReadStillWaitsAMinute() async throws {
        var transport = try replies()
        transport.history = MailboxReply(status: 500, body: Data())
        let client = try client(transport)
        var session = AwaySession()
        session = try await session.refreshed(using: client, now: now)
        XCTAssertEqual(session.problem, .offline)
        XCTAssertNotNil(session.latest)
        session = try await session.refreshed(using: client, now: now.addingTimeInterval(15))
        XCTAssertEqual(transport.historyReads.value, 1)
        XCTAssertNil(session.problem)
    }

    func testAFailedReadKeepsTheLastReport() async throws {
        let good = try replies()
        var session = try await AwaySession().refreshed(using: client(good), now: now)
        var bad = good
        bad.latest = MailboxReply(status: 500, body: Data())
        session = try await session.refreshed(using: client(bad), now: now.addingTimeInterval(15))
        XCTAssertNotNil(session.latest)
        XCTAssertEqual(session.problem, .offline)
        guard case .reading(let generatedAt?, .offline?, nil) = session.status else {
            return XCTFail("Expected the age and the problem")
        }
        XCTAssertEqual(generatedAt, session.latest?.generatedAt)
    }

    func testNoReportYetKeepsWaiting() async throws {
        var transport = try replies()
        transport.latest = MailboxReply(status: 204, body: Data())
        transport.history = MailboxReply(status: 200, body: Data("{\"snapshots\":[]}".utf8))
        let session = try await AwaySession().refreshed(using: client(transport), now: now)
        XCTAssertNil(session.latest)
        XCTAssertNil(session.problem)
    }

    func testPartHealthBecomesANote() throws {
        var stale = try live()
        stale.sources.machine = .stale
        XCTAssertEqual(
            AwaySession(latest: stale, history: nil).status,
            .reading(generatedAt: stale.generatedAt, problem: nil, note: AwayCopy.someEarlier)
        )
        var failed = stale
        failed.sources.monitors = .error
        XCTAssertEqual(
            AwaySession(latest: failed, history: nil).status,
            .reading(generatedAt: failed.generatedAt, problem: nil, note: AwayCopy.someMissing)
        )
    }
}
