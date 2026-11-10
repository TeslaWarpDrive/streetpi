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

    func testANamedDownCheckCannotLookAllUp() throws {
        let latest = try live {
            $0.monitors?.items[0].status = .down
        }
        let monitors = try tile(.monitors, in: AwayBoard.make(latest: latest, history: nil))
        XCTAssertEqual(monitors.summary, AwayCopy.noChecks)
        XCTAssertEqual(monitors.tone, .problem)
        let down = try XCTUnwrap(monitors.rows.first { $0.name == "Pi-hole DNS" })
        XCTAssertEqual(down.tone, .problem)
    }

    func testAnImpossibleMonitorCountIsNotShown() throws {
        let latest = try live {
            $0.monitors?.up = 5
            $0.monitors?.down = 0
            $0.monitors?.total = 0
        }
        let monitors = try tile(.monitors, in: AwayBoard.make(latest: latest, history: nil))
        XCTAssertEqual(monitors.summary, AwayCopy.noChecks)
        XCTAssertEqual(monitors.tone, .attention)
    }

    func testAnAllUpCountBesideAPendingCheckIsNotShown() throws {
        let latest = try live {
            $0.monitors?.items[0].status = .pending
        }
        let monitors = try tile(.monitors, in: AwayBoard.make(latest: latest, history: nil))
        XCTAssertEqual(monitors.summary, AwayCopy.noChecks)
        XCTAssertEqual(monitors.tone, .attention)
    }

    func testAnAllUpCountBesideMaintenanceIsNotShown() throws {
        let latest = try live {
            $0.monitors?.items[0].status = .maintenance
        }
        let monitors = try tile(.monitors, in: AwayBoard.make(latest: latest, history: nil))
        XCTAssertEqual(monitors.summary, AwayCopy.noChecks)
        XCTAssertEqual(monitors.tone, .attention)
    }

    func testADownCountAboveTheTotalIsNotShown() throws {
        let latest = try live {
            $0.monitors?.down = 9
        }
        let monitors = try tile(.monitors, in: AwayBoard.make(latest: latest, history: nil))
        XCTAssertEqual(monitors.summary, AwayCopy.noChecks)
        XCTAssertEqual(monitors.tone, .attention)
    }

    func testAPendingCheckBesideAPartialCountStillShows() throws {
        let latest = try live {
            $0.monitors?.up = 7
            $0.monitors?.items[0].status = .pending
        }
        let monitors = try tile(.monitors, in: AwayBoard.make(latest: latest, history: nil))
        XCTAssertEqual(monitors.summary, "7 of 8 up")
        XCTAssertEqual(monitors.tone, .attention)
    }

    func testACountedDownStillUsesTheCount() throws {
        let monitors: [String: Any] = [
            "up": 2, "down": 1, "total": 2,
            "items": [["name": "Internet", "status": "down"]],
        ]
        let data = try jsonReplacingMonitors(monitors)
        let snapshot = try JSONDecoder().decode(AwaySnapshot.self, from: data)
        let tile = try tile(.monitors, in: AwayBoard.make(latest: snapshot, history: nil))
        XCTAssertEqual(tile.summary, "2 of 2 up")
        XCTAssertEqual(tile.tone, .problem)
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

    func testAFutureBackupDoesNotReadAsRecent() throws {
        let later = try live {
            $0.backup?.lastRunAt = $0.generatedAt.addingTimeInterval(3_600)
        }
        let backups = try tile(.backups, in: AwayBoard.make(latest: later, history: nil))
        XCTAssertEqual(backups.summary, "No backup check-in yet.")
        XCTAssertEqual(backups.tone, .attention)
        XCTAssertFalse(backups.rows.contains { $0.state == "just now" })

        let skewed = try live {
            $0.backup?.lastRunAt = $0.generatedAt.addingTimeInterval(60)
        }
        let still = try tile(.backups, in: AwayBoard.make(latest: skewed, history: nil))
        XCTAssertTrue(still.summary.hasPrefix("Last backup:"))
        XCTAssertEqual(still.tone, .calm)
    }

    func testBlockedQueriesCannotExceedQueriesToday() throws {
        let latest = try live {
            $0.adBlocker?.queriesToday = 10
            $0.adBlocker?.blockedToday = 11
        }
        let board = AwayBoard.make(latest: latest, history: nil)
        XCTAssertNil(board.snapshot?.dns)
        XCTAssertNil(board.desk.reportedQueries)
        XCTAssertNil(board.desk.reportedBlocked)
        let share = LookupShare.from(desk: board.desk)
        XCTAssertLessThanOrEqual(share.stopped, share.lookups)
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

    private func jsonReplacingMonitors(_ monitors: [String: Any]) throws -> Data {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: fixtureBody("away-live")) as? [String: Any])
        object["monitors"] = monitors
        return try JSONSerialization.data(withJSONObject: object)
    }

    private func fixtureBody(_ name: String) throws -> Data {
        try Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json")))
    }

    private func markingFirstMonitor(_ status: String, in data: Data) throws -> Data {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var monitors = try XCTUnwrap(object["monitors"] as? [String: Any])
        var items = try XCTUnwrap(monitors["items"] as? [[String: Any]])
        items[0]["status"] = status
        monitors["items"] = items
        object["monitors"] = monitors
        return try JSONSerialization.data(withJSONObject: object)
    }

    private func downAboveTotal(_ data: Data) throws -> Data {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var monitors = try XCTUnwrap(object["monitors"] as? [String: Any])
        monitors["up"] = 1
        monitors["down"] = 9
        monitors["total"] = 2
        object["monitors"] = monitors
        return try JSONSerialization.data(withJSONObject: object)
    }

    private func fiveOfZero(_ data: Data) throws -> Data {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var monitors = try XCTUnwrap(object["monitors"] as? [String: Any])
        monitors["up"] = 5
        monitors["down"] = 0
        monitors["total"] = 0
        monitors["items"] = [Any]()
        object["monitors"] = monitors
        return try JSONSerialization.data(withJSONObject: object)
    }

    private func patchedHistory(uptime: Int, generatedAt: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "away-history", withExtension: "json"))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        object["generatedAt"] = generatedAt
        var machine = try XCTUnwrap(object["machine"] as? [String: Any])
        machine["uptimeSeconds"] = uptime
        object["machine"] = machine
        return try JSONSerialization.data(withJSONObject: object)
    }

    private func blockedAboveQueries(_ data: Data) throws -> Data {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var part = try XCTUnwrap(object["adBlocker"] as? [String: Any])
        part["queriesToday"] = 10
        part["blockedToday"] = 11
        object["adBlocker"] = part
        return try JSONSerialization.data(withJSONObject: object)
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
        XCTAssertNil(session.problem)
        XCTAssertEqual(session.historyProblem, .offline)
        XCTAssertEqual(session.board.machine.chartNote, AwayCopy.problem(.offline))
        XCTAssertEqual(session.board.desk.dayChartNote, AwayCopy.problem(.offline))
        XCTAssertFalse(session.board.desk.hasDayLookups)
        XCTAssertNotNil(session.latest)
        session = try await session.refreshed(using: client, now: now.addingTimeInterval(15))
        XCTAssertEqual(transport.historyReads.value, 1)
        XCTAssertNil(session.problem)
        XCTAssertEqual(session.historyProblem, .offline)
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

    func testARefusedTokenKeepsTheReportAndDoesNotOpenSettings() async throws {
        let good = try replies()
        var session = try await AwaySession().refreshed(using: client(good), now: now)
        let kept = try XCTUnwrap(session.latest)
        XCTAssertFalse(session.status.badge(now: now).offersSetup)

        var refused = good
        refused.latest = MailboxReply(status: 401, body: Data())
        let later = now.addingTimeInterval(15)
        session = try await session.refreshed(using: client(refused), now: later)
        XCTAssertEqual(session.latest, kept)
        XCTAssertEqual(session.problem, .refused)
        let badge = session.status.badge(now: later)
        XCTAssertFalse(badge.offersSetup)
        XCTAssertEqual(badge.detail, "The mailbox refused the read token. Check Settings.")
    }

    func testAWrongAddressKeepsTheReportAndOpensSettings() async throws {
        let good = try replies()
        let saved = try await AwaySession().refreshed(using: client(good), now: now)
        let kept = try XCTUnwrap(saved.latest)
        var missed = good
        missed.latest = MailboxReply(status: 404, body: Data())
        let later = now.addingTimeInterval(15)
        let session = try await saved.refreshed(using: client(missed), now: later)
        XCTAssertEqual(session.latest, kept)
        XCTAssertEqual(session.problem, .wrongAddress)
        let badge = session.status.badge(now: later)
        XCTAssertTrue(badge.offersSetup)
        XCTAssertEqual(badge.detail, "Nothing answered at that mailbox address. Check Settings.")
    }

    func testASavedReportStillHidesSettingsForAnOfflineMailbox() async throws {
        let good = try replies()
        let saved = try await AwaySession().refreshed(using: client(good), now: now)
        let later = now.addingTimeInterval(15)
        var bad = good
        bad.latest = MailboxReply(status: 500, body: Data())
        let session = try await saved.refreshed(using: client(bad), now: later)
        XCTAssertEqual(session.latest, saved.latest)
        XCTAssertEqual(session.problem, .offline)
        XCTAssertFalse(session.status.badge(now: later).offersSetup)
    }

    func testNoReportYetKeepsWaiting() async throws {
        var transport = try replies()
        transport.latest = MailboxReply(status: 204, body: Data())
        transport.history = MailboxReply(status: 200, body: Data("{\"snapshots\":[]}".utf8))
        let session = try await AwaySession().refreshed(using: client(transport), now: now)
        XCTAssertNil(session.latest)
        XCTAssertNil(session.problem)
    }

    func testAFalseAllUpPayloadDoesNotReplaceTheReport() async throws {
        let good = try replies()
        var session = try await AwaySession().refreshed(using: client(good), now: now)
        var bad = good
        bad.latest = MailboxReply(status: 200, body: try markingFirstMonitor("down", in: good.latest.body))
        session = try await session.refreshed(using: client(bad), now: now.addingTimeInterval(15))
        XCTAssertEqual(session.problem, .notUnderstood)
        let row = try XCTUnwrap(try tile(.monitors, in: session.board).rows.first { $0.name == "Pi-hole DNS" })
        XCTAssertEqual(row.tone, .calm)
    }

    func testAnImpossibleCountPayloadPaintsNothing() async throws {
        var transport = try replies()
        transport.latest = MailboxReply(status: 200, body: try fiveOfZero(transport.latest.body))
        let session = try await AwaySession().refreshed(using: client(transport), now: now)
        XCTAssertNil(session.latest)
        XCTAssertEqual(session.problem, .notUnderstood)
        XCTAssertNil(session.board.status)
    }

    func testTheDayChartFollowsTheLaterHistoryTime() async throws {
        let olderTime = "2026-10-19T04:55:00Z"
        let newerTime = "2026-10-19T14:55:00Z"
        let older = try patchedHistory(uptime: 10, generatedAt: olderTime)
        let newer = try patchedHistory(uptime: 60, generatedAt: newerTime)
        var transport = try replies()
        transport.history = MailboxReply(
            status: 200,
            body: Data("{\"snapshots\":[".utf8) + older + Data(",".utf8) + newer + Data("]}".utf8)
        )
        let session = try await AwaySession().refreshed(using: client(transport), now: now)
        XCTAssertEqual(session.history?.machine?.uptimeSeconds, 60)
        let chosen = try XCTUnwrap(session.history)
        let latest = try live()
        let shown = AwayBoard.make(latest: latest, history: chosen)
        XCTAssertEqual(session.board.desk.day, shown.desk.day)
        XCTAssertEqual(session.board.machine.series, shown.machine.series)
        let earlier = try JSONDecoder().decode(AwaySnapshot.self, from: older)
        let missed = AwayBoard.make(latest: latest, history: earlier)
        XCTAssertNotEqual(session.board.desk.day, missed.desk.day)
    }

    func testTooManyBlockedQueriesDoNotReplaceTheReport() async throws {
        let good = try replies()
        var session = try await AwaySession().refreshed(using: client(good), now: now)
        let kept = try XCTUnwrap(session.latest?.adBlocker?.queriesToday)
        var bad = good
        bad.latest = MailboxReply(status: 200, body: try blockedAboveQueries(good.latest.body))
        session = try await session.refreshed(using: client(bad), now: now.addingTimeInterval(15))
        XCTAssertEqual(session.problem, .notUnderstood)
        XCTAssertEqual(session.latest?.adBlocker?.queriesToday, kept)
        XCTAssertEqual(session.board.desk.reportedQueries, kept)
    }

    func testADownCountAboveTheTotalDoesNotReplaceTheReport() async throws {
        let good = try replies()
        var session = try await AwaySession().refreshed(using: client(good), now: now)
        let kept = try tile(.monitors, in: session.board).summary
        var bad = good
        bad.latest = MailboxReply(status: 200, body: try downAboveTotal(good.latest.body))
        session = try await session.refreshed(using: client(bad), now: now.addingTimeInterval(15))
        XCTAssertEqual(session.problem, .notUnderstood)
        XCTAssertEqual(try tile(.monitors, in: session.board).summary, kept)
    }

    func testAnAllUpCountBesidePendingDoesNotReplaceTheReport() async throws {
        let good = try replies()
        var session = try await AwaySession().refreshed(using: client(good), now: now)
        var bad = good
        bad.latest = MailboxReply(status: 200, body: try markingFirstMonitor("pending", in: good.latest.body))
        session = try await session.refreshed(using: client(bad), now: now.addingTimeInterval(15))
        XCTAssertEqual(session.problem, .notUnderstood)
        let row = try XCTUnwrap(try tile(.monitors, in: session.board).rows.first { $0.name == "Pi-hole DNS" })
        XCTAssertEqual(row.tone, .calm)
    }

    func testAnAllUpCountBesideMaintenancePaintsNothing() async throws {
        var transport = try replies()
        transport.latest = MailboxReply(
            status: 200,
            body: try markingFirstMonitor("maintenance", in: transport.latest.body)
        )
        let session = try await AwaySession().refreshed(using: client(transport), now: now)
        XCTAssertNil(session.latest)
        XCTAssertEqual(session.problem, .notUnderstood)
        XCTAssertNil(session.board.status)
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
