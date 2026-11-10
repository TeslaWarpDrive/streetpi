import XCTest
@testable import StreetPiCore

/// A pull that stays on the current road. A different road restarts the watch, so it is not a row here.
final class ManualRefreshTests: XCTestCase {
    func testPullReadsTheTilesThatWaitOnTheirOwnLoop() throws {
        let live = try gateway()
        let box = try mailbox()
        let tiles: Set<ManualRefresh.Source> = [.adBlocker, .temperature, .charts, .monitors]
        let rows: [Row] = [
            Row(mode: .home, signedOut: false, reads: tiles),
            Row(mode: .offline, signedOut: false, reads: tiles),
            Row(mode: .awayLive(live), signedOut: false, reads: tiles),
            Row(mode: .awayMailbox(box), signedOut: false, reads: [.mailbox]),
            Row(mode: .awayMailbox(box), signedOut: true, reads: [.mailbox]),
            Row(mode: .home, signedOut: true, reads: []),
            Row(mode: .offline, signedOut: true, reads: []),
            Row(mode: .awayLive(live), signedOut: true, reads: []),
        ]
        for row in rows {
            XCTAssertEqual(ManualRefresh.reads(mode: row.mode, signedOut: row.signedOut), row.reads)
            for source in ManualRefresh.Source.allCases {
                let paints = row.reads.contains(source)
                XCTAssertEqual(
                    ManualRefresh.mayPaint(source, mode: row.mode, signedOut: row.signedOut),
                    paints
                )
            }
        }
    }

    /// A pull while signed out still asks the ad blocker, and a clear read is what puts the desk back.
    /// Only a sign-out that lands while the read is out keeps the board off the screen.
    func testAnAdBlockerPullThatStartedSignedOutStillPaints() throws {
        let live = try gateway()
        let box = try mailbox()
        for mode in [ConnectionMode.home, .offline, .awayLive(live)] {
            XCTAssertTrue(ManualRefresh.mayPaintAdBlocker(mode: mode, startedSignedOut: false, signedOut: false))
            XCTAssertTrue(ManualRefresh.mayPaintAdBlocker(mode: mode, startedSignedOut: true, signedOut: true))
            XCTAssertTrue(ManualRefresh.mayPaintAdBlocker(mode: mode, startedSignedOut: true, signedOut: false))
            XCTAssertFalse(ManualRefresh.mayPaintAdBlocker(mode: mode, startedSignedOut: false, signedOut: true))
        }
        for (started, now) in [(false, false), (true, true), (false, true)] {
            XCTAssertFalse(
                ManualRefresh.mayPaintAdBlocker(mode: .awayMailbox(box), startedSignedOut: started, signedOut: now)
            )
        }
    }

    /// The pull stays in flight until temperature, the charts, and the monitors have all finished.
    @MainActor
    func testRefreshWaitsForTheTileReads() async {
        let board = RefreshBoard(identity: homeIdentity())
        let gate = TileGate()
        let task = pull(board, gate: gate)
        await gate.untilStarted()
        XCTAssertFalse(board.finished)
        XCTAssertEqual(Set(gate.started), [.temperature, .charts, .monitors])

        gate.resume(.temperature, "home temperature")
        gate.resume(.charts, "home charts")
        await board.untilPublished(2)
        XCTAssertFalse(board.finished)
        XCTAssertEqual(board.temperature, "home temperature")
        XCTAssertEqual(board.charts, "home charts")
        XCTAssertNil(board.monitors)
        XCTAssertEqual(board.logs, RefreshBoard.keptLogs)

        gate.resume(.monitors, "home monitors")
        await task.value
        XCTAssertTrue(board.finished)
        XCTAssertEqual(board.monitors, "home monitors")
        XCTAssertEqual(board.publishes, 3)
        XCTAssertEqual(board.logs, RefreshBoard.keptLogs)
    }

    /// The old home read is still suspended when the replacement road has already published.
    /// Finishing that home read must leave the new tiles and the logs alone.
    @MainActor
    func testASuspendedReadLeavesTheConnectionThatAlreadyPublished() async throws {
        let board = RefreshBoard(identity: homeIdentity())
        let gate = TileGate()
        let task = pull(board, gate: gate)
        await gate.untilStarted()
        XCTAssertFalse(board.finished)

        board.identity = try gatewayIdentity()
        board.temperature = "gateway meters"
        board.charts = "gateway charts"
        board.monitors = "gateway monitors"

        gate.resume(.temperature, "home failure")
        gate.resume(.charts, "home charts")
        gate.resume(.monitors, "home monitors")
        await task.value

        XCTAssertTrue(board.finished)
        XCTAssertEqual(board.publishes, 0)
        XCTAssertEqual(board.temperature, "gateway meters")
        XCTAssertEqual(board.charts, "gateway charts")
        XCTAssertEqual(board.monitors, "gateway monitors")
        XCTAssertEqual(board.logs, RefreshBoard.keptLogs)
    }

    /// A pull that is cancelled while the reads are still open does not publish them.
    @MainActor
    func testACancelledPullDoesNotPublishTheTiles() async {
        let board = RefreshBoard(identity: homeIdentity())
        let gate = TileGate()
        let task = pull(board, gate: gate)
        await gate.untilStarted()
        task.cancel()
        gate.resume(.temperature, "home temperature")
        gate.resume(.charts, "home charts")
        gate.resume(.monitors, "home monitors")
        await task.value
        XCTAssertEqual(board.publishes, 0)
        XCTAssertNil(board.temperature)
        XCTAssertNil(board.charts)
        XCTAssertNil(board.monitors)
        XCTAssertEqual(board.logs, RefreshBoard.keptLogs)
    }

    @MainActor
    private func pull(_ board: RefreshBoard, gate: TileGate) -> Task<Void, Never> {
        Task { @MainActor in
            await ManualRefresh.refreshTiles(
                reads: [.temperature, .charts, .monitors],
                identity: { board.identity },
                temperature: ManualRefresh.Tile(
                    load: { await gate.take(.temperature) },
                    publish: { board.publishTemperature($0) }
                ),
                charts: ManualRefresh.Tile(
                    load: { await gate.take(.charts) },
                    publish: { board.publishCharts($0) }
                ),
                monitors: ManualRefresh.Tile(
                    load: { await gate.take(.monitors) },
                    publish: { board.publishMonitors($0) }
                )
            )
            board.finished = true
        }
    }

    private struct Row {
        var mode: ConnectionMode
        var signedOut: Bool
        var reads: Set<ManualRefresh.Source>
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

    private func homeIdentity() -> ManualRefresh.Identity {
        ManualRefresh.Identity(
            mode: .home,
            generation: 2,
            host: "http://pi.example.test:19999",
            statusAddress: "http://status.example.test",
            statusSlug: "house",
            watch: 4,
            signedOut: false,
            retry: 1
        )
    }

    private func gatewayIdentity() throws -> ManualRefresh.Identity {
        let home = homeIdentity()
        return ManualRefresh.Identity(
            mode: .awayLive(try gateway()),
            generation: home.generation + 1,
            host: "https://gateway.example.test",
            statusAddress: home.statusAddress,
            statusSlug: home.statusSlug,
            watch: home.watch + 1,
            signedOut: home.signedOut,
            retry: home.retry
        )
    }
}

/// The tiles a pull publishes, plus the log lines a pull must leave alone.
@MainActor
private final class RefreshBoard {
    static let keptLogs = "The query log and the text log stay"

    var identity: ManualRefresh.Identity
    var temperature: String?
    var charts: String?
    var monitors: String?
    var logs = keptLogs
    var publishes = 0
    var finished = false
    private var publishWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    init(identity: ManualRefresh.Identity) {
        self.identity = identity
    }

    func publishTemperature(_ value: String) {
        temperature = value
        notePublish()
    }

    func publishCharts(_ value: String) {
        charts = value
        notePublish()
    }

    func publishMonitors(_ value: String) {
        monitors = value
        notePublish()
    }

    func untilPublished(_ count: Int) async {
        if publishes >= count { return }
        await withCheckedContinuation { publishWaiters.append((count, $0)) }
    }

    private func notePublish() {
        publishes += 1
        let ready = publishWaiters.filter { publishes >= $0.count }
        publishWaiters.removeAll { publishes >= $0.count }
        let continuations = ready.map(\.continuation)
        Task { @MainActor in
            continuations.forEach { $0.resume() }
        }
    }
}

/// Holds the three tile reads until the test lets them finish.
@MainActor
private final class TileGate {
    enum Tile: Hashable {
        case temperature
        case charts
        case monitors
    }

    private(set) var started: [Tile] = []
    private var waiting: [Tile: CheckedContinuation<String, Never>] = [:]
    private var parked: [Tile: String] = [:]
    private var startWaiters: [CheckedContinuation<Void, Never>] = []

    func take(_ tile: Tile) async -> String {
        if let value = parked.removeValue(forKey: tile) {
            begin(tile)
            return value
        }
        begin(tile)
        return await withCheckedContinuation { continuation in
            if let value = parked.removeValue(forKey: tile) {
                continuation.resume(returning: value)
            } else {
                waiting[tile] = continuation
            }
        }
    }

    func untilStarted() async {
        if started.count == 3 { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func resume(_ tile: Tile, _ value: String) {
        if let waiter = waiting.removeValue(forKey: tile) {
            waiter.resume(returning: value)
        } else {
            parked[tile] = value
        }
    }

    private func begin(_ tile: Tile) {
        started.append(tile)
        guard started.count == 3 else { return }
        let pending = startWaiters
        startWaiters.removeAll()
        Task { @MainActor in
            pending.forEach { $0.resume() }
        }
    }
}
