import Foundation
import XCTest
@testable import StreetPiCore

/// One reply the scripted mailbox can give. Cancellation is the only error that leaves the session.
enum MailboxAnswer {
    case status(Int, Data)
    case timeout
    case cancel
}

/// Fixture replies, one per call, so a refresh can be stepped through.
final class ScriptedMailbox: MailboxTransport, @unchecked Sendable {
    private struct Unexpected: Error {}

    private let lock = NSLock()
    private var latest: [MailboxAnswer]
    private var history: [MailboxAnswer]
    private var historyReads = 0

    init(latest: [MailboxAnswer], history: [MailboxAnswer] = []) {
        self.latest = latest
        self.history = history
    }

    var historyReadCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return historyReads
    }

    /// Locking stays on this synchronous method. `NSLock` cannot be taken from an async function.
    private func take(_ kind: Kind) -> MailboxAnswer? {
        lock.lock()
        defer { lock.unlock() }
        switch kind {
        case .history:
            historyReads += 1
            return history.isEmpty ? nil : history.removeFirst()
        case .latest:
            return latest.isEmpty ? nil : latest.removeFirst()
        }
    }

    private enum Kind {
        case history
        case latest
    }

    func get(_ url: URL, token: MailboxToken) async throws -> MailboxReply {
        let answer = take(url.path.contains("history") ? .history : .latest)
        guard let answer else { throw Unexpected() }
        switch answer {
        case .status(let status, let body):
            return MailboxReply(status: status, body: body)
        case .timeout:
            throw URLError(.timedOut)
        case .cancel:
            throw CancellationError()
        }
    }
}

/// One open-session row. A history miss is `historyProblem`, never the badge problem.
private struct OpenRow {
    var name: String
    var latest: MailboxAnswer
    var history: MailboxAnswer?
    var problem: MailboxProblem?
    var offersSetup: Bool
    var hasLatest: Bool
    var hasHistory: Bool
    var historyProblem: MailboxProblem?

    init(
        name: String,
        latest: MailboxAnswer,
        history: MailboxAnswer?,
        problem: MailboxProblem?,
        offersSetup: Bool,
        hasLatest: Bool,
        hasHistory: Bool,
        historyProblem: MailboxProblem? = nil
    ) {
        self.name = name
        self.latest = latest
        self.history = history
        self.problem = problem
        self.offersSetup = offersSetup
        self.hasLatest = hasLatest
        self.hasHistory = hasHistory
        self.historyProblem = historyProblem
    }
}

/// Today's `AwaySession.refreshed` outputs, except the history-miss-while-latest-updates row.
final class AwaySessionTransitionTests: XCTestCase {
    private let now = Date.streetFixtureNow

    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    private func liveBody(stamp: String = "2026-10-19T14:59:48Z") throws -> Data {
        var text = try XCTUnwrap(String(data: fixture("away-live"), encoding: .utf8))
        text = text.replacingOccurrences(of: "2026-10-19T14:59:48Z", with: stamp)
        return Data(text.utf8)
    }

    private func historyPage() throws -> Data {
        Data("{\"snapshots\":[".utf8) + (try fixture("away-history")) + Data("]}".utf8)
    }

    private func client(_ transport: ScriptedMailbox) throws -> MailboxClient<ScriptedMailbox> {
        MailboxClient(
            transport: transport,
            setup: MailboxSetup(
                address: try XCTUnwrap(MailboxAddress(text: "https://mailbox.example.test")),
                token: try XCTUnwrap(MailboxToken(text: "fixture-not-a-real-read-token"))
            )
        )
    }

    private func refresh(
        _ session: AwaySession = AwaySession(),
        latest: [MailboxAnswer],
        history: [MailboxAnswer] = [],
        at time: Date
    ) async throws -> (AwaySession, ScriptedMailbox) {
        let transport = ScriptedMailbox(latest: latest, history: history)
        let next = try await session.refreshed(using: client(transport), now: time)
        return (next, transport)
    }

    // MARK: From an empty session

    func testOpenSessionTransitions() async throws {
        for row in try openRows() {
            let history = row.history.map { [$0] } ?? []
            let (session, transport) = try await refresh(latest: [row.latest], history: history, at: now)
            let badge = session.status.badge(now: now)
            XCTAssertEqual(session.problem, row.problem, row.name)
            XCTAssertEqual(session.historyProblem, row.historyProblem, row.name)
            XCTAssertEqual(session.latest != nil, row.hasLatest, row.name)
            XCTAssertEqual(session.history != nil, row.hasHistory, row.name)
            XCTAssertEqual(transport.historyReadCount, row.history == nil ? 0 : 1, row.name)
            XCTAssertEqual(badge.offersSetup, row.offersSetup, row.name)
            if session.board.machine.series.isEmpty {
                let note = row.historyProblem.map(AwayCopy.problem) ?? AwayCopy.chartWaiting
                XCTAssertEqual(session.board.machine.chartNote, note, row.name)
            } else {
                XCTAssertNil(session.board.machine.chartNote, row.name)
            }
            XCTAssertEqual(session.board.desk.dayChartNote, row.historyProblem.map(AwayCopy.problem), row.name)
            if row.hasLatest {
                let generatedAt = try XCTUnwrap(session.latest, row.name).generatedAt
                let freshness = AwayFreshness.make(generatedAt: generatedAt, now: now)
                XCTAssertEqual(badge.line, freshness.line, row.name)
                XCTAssertNil(badge.detail, row.name)
                XCTAssertEqual(badge.tone, .calm, row.name)
            } else if let problem = row.problem {
                XCTAssertEqual(badge.line, AwayCopy.problem(problem), row.name)
                XCTAssertNil(badge.detail, row.name)
                XCTAssertEqual(badge.tone, .problem, row.name)
                XCTAssertNil(session.board.snapshot, row.name)
            } else {
                XCTAssertEqual(badge.line, AwayCopy.waitingFirstReport, row.name)
                XCTAssertNil(badge.detail, row.name)
                XCTAssertNil(session.board.snapshot, row.name)
            }
        }
    }

    private func openRows() throws -> [OpenRow] {
        let live = try liveBody()
        let day = try historyPage()
        let empty = Data("{\"snapshots\":[]}".utf8)
        let garbage = Data("{\"schema\":2}".utf8)
        return [
            OpenRow(
                name: "both succeed",
                latest: .status(200, live), history: .status(200, day),
                problem: nil, offersSetup: false, hasLatest: true, hasHistory: true
            ),
            OpenRow(
                name: "latest offline",
                latest: .status(500, Data()), history: nil,
                problem: .offline, offersSetup: false, hasLatest: false, hasHistory: false
            ),
            OpenRow(
                name: "latest timeout",
                latest: .timeout, history: nil,
                problem: .offline, offersSetup: false, hasLatest: false, hasHistory: false
            ),
            OpenRow(
                name: "latest refused",
                latest: .status(401, Data()), history: nil,
                problem: .refused, offersSetup: true, hasLatest: false, hasHistory: false
            ),
            OpenRow(
                name: "latest wrong address",
                latest: .status(404, Data()), history: nil,
                problem: .wrongAddress, offersSetup: true, hasLatest: false, hasHistory: false
            ),
            OpenRow(
                name: "latest unreadable",
                latest: .status(200, garbage), history: nil,
                problem: .notUnderstood, offersSetup: false, hasLatest: false, hasHistory: false
            ),
            OpenRow(
                name: "no report yet",
                latest: .status(204, Data()), history: .status(200, empty),
                problem: nil, offersSetup: false, hasLatest: false, hasHistory: false
            ),
            OpenRow(
                name: "history before the first report",
                latest: .status(204, Data()), history: .status(200, day),
                problem: nil, offersSetup: false, hasLatest: false, hasHistory: true
            ),
            OpenRow(
                name: "history offline before the first report",
                latest: .status(204, Data()), history: .status(500, Data()),
                problem: nil, offersSetup: false, hasLatest: false, hasHistory: false,
                historyProblem: .offline
            ),
            OpenRow(
                name: "history refused before the first report",
                latest: .status(204, Data()), history: .status(401, Data()),
                problem: nil, offersSetup: false, hasLatest: false, hasHistory: false,
                historyProblem: .refused
            ),
            OpenRow(
                name: "history wrong address before the first report",
                latest: .status(204, Data()), history: .status(404, Data()),
                problem: nil, offersSetup: false, hasLatest: false, hasHistory: false,
                historyProblem: .wrongAddress
            ),
            OpenRow(
                name: "history unreadable before the first report",
                latest: .status(204, Data()), history: .status(200, garbage),
                problem: nil, offersSetup: false, hasLatest: false, hasHistory: false,
                historyProblem: .notUnderstood
            ),
            OpenRow(
                name: "history timeout before the first report",
                latest: .status(204, Data()), history: .timeout,
                problem: nil, offersSetup: false, hasLatest: false, hasHistory: false,
                historyProblem: .offline
            ),
        ]
    }

    // MARK: After a report is already on screen

    func testALatestMissKeepsTheReportOnTheBadge() async throws {
        let (saved, _) = try await refresh(
            latest: [.status(200, liveBody())],
            history: [.status(200, historyPage())],
            at: now
        )
        let later = now.addingTimeInterval(15)
        let (session, transport) = try await refresh(
            saved,
            latest: [.status(500, Data())],
            history: [.status(500, Data())],
            at: later
        )
        XCTAssertEqual(transport.historyReadCount, 0)
        XCTAssertEqual(session.latest?.generatedAt, saved.latest?.generatedAt)
        XCTAssertEqual(session.history?.generatedAt, saved.history?.generatedAt)
        XCTAssertEqual(session.problem, .offline)
        let badge = session.status.badge(now: later)
        let freshness = AwayFreshness.make(generatedAt: try XCTUnwrap(session.latest).generatedAt, now: later)
        XCTAssertEqual(badge.line, freshness.line)
        XCTAssertEqual(badge.detail, AwayCopy.problem(.offline))
        XCTAssertEqual(badge.tone, .calm)
        XCTAssertFalse(badge.offersSetup)
        XCTAssertNil(session.board.machine.chartNote)
        XCTAssertFalse(session.board.machine.series.isEmpty)
        XCTAssertEqual(session.board.desk.knownClients, 14)
    }

    func testALaterRefusalKeepsTheReportAndDoesNotOfferSetup() async throws {
        let (saved, _) = try await refresh(
            latest: [.status(200, liveBody())],
            history: [.status(200, historyPage())],
            at: now
        )
        let (session, transport) = try await refresh(
            saved,
            latest: [.status(401, Data())],
            history: [.status(401, Data())],
            at: now.addingTimeInterval(15)
        )
        XCTAssertEqual(transport.historyReadCount, 0)
        XCTAssertEqual(session.problem, .refused)
        XCTAssertEqual(session.latest?.generatedAt, saved.latest?.generatedAt)
        let badge = session.status.badge(now: now.addingTimeInterval(15))
        XCTAssertEqual(badge.detail, AwayCopy.problem(.refused))
        XCTAssertFalse(badge.offersSetup)
    }

    func testAWrongAddressAfterAReportOpensSettings() async throws {
        let (saved, _) = try await refresh(
            latest: [.status(200, liveBody())],
            history: [.status(200, historyPage())],
            at: now
        )
        let (session, _) = try await refresh(
            saved,
            latest: [.status(404, Data())],
            at: now.addingTimeInterval(15)
        )
        XCTAssertEqual(session.problem, .wrongAddress)
        XCTAssertTrue(session.status.badge(now: now.addingTimeInterval(15)).offersSetup)
        XCTAssertEqual(session.latest?.generatedAt, saved.latest?.generatedAt)
    }

    func testNoContentKeepsTheReportAndClearsALatestMiss() async throws {
        let (saved, _) = try await refresh(
            latest: [.status(200, liveBody())],
            history: [.status(200, historyPage())],
            at: now
        )
        let (missed, _) = try await refresh(
            saved,
            latest: [.status(500, Data())],
            at: now.addingTimeInterval(15)
        )
        XCTAssertEqual(missed.problem, .offline)
        let (session, transport) = try await refresh(
            missed,
            latest: [.status(204, Data())],
            history: [.status(500, Data())],
            at: now.addingTimeInterval(30)
        )
        XCTAssertEqual(transport.historyReadCount, 0)
        XCTAssertNil(session.problem)
        XCTAssertEqual(session.latest?.generatedAt, saved.latest?.generatedAt)
        XCTAssertEqual(session.history?.generatedAt, saved.history?.generatedAt)
        XCTAssertNil(session.status.badge(now: now.addingTimeInterval(30)).detail)
        XCTAssertNil(session.board.machine.chartNote)
        XCTAssertFalse(session.board.machine.series.isEmpty)
    }

    func testTheReadAfterALatestMissStillFetchesHistory() async throws {
        let (missed, first) = try await refresh(latest: [.status(500, Data())], at: now)
        XCTAssertEqual(first.historyReadCount, 0)
        XCTAssertEqual(missed.problem, .offline)
        let (session, transport) = try await refresh(
            missed,
            latest: [.status(200, liveBody())],
            history: [.status(200, historyPage())],
            at: now.addingTimeInterval(15)
        )
        XCTAssertEqual(transport.historyReadCount, 1)
        XCTAssertNil(session.problem)
        XCTAssertNotNil(session.latest)
        XCTAssertNotNil(session.history)
        XCTAssertNil(session.board.machine.chartNote)
        XCTAssertFalse(session.board.machine.series.isEmpty)
    }

    func testAnEmptyHistoryPageKeepsThePreviousChart() async throws {
        let (saved, _) = try await refresh(
            latest: [.status(200, liveBody())],
            history: [.status(200, historyPage())],
            at: now
        )
        let (session, transport) = try await refresh(
            saved,
            latest: [.status(200, liveBody())],
            history: [.status(200, Data("{\"snapshots\":[]}".utf8))],
            at: now.addingTimeInterval(60)
        )
        XCTAssertEqual(transport.historyReadCount, 1)
        XCTAssertNil(session.problem)
        XCTAssertEqual(session.history?.generatedAt, saved.history?.generatedAt)
        XCTAssertFalse(session.board.machine.series.isEmpty)
        XCTAssertNil(session.board.machine.chartNote)
    }

    func testHistoryIsNotReadAgainInsideAMinute() async throws {
        let transport = ScriptedMailbox(
            latest: [
                .status(200, try liveBody()),
                .status(200, try liveBody(stamp: "2026-10-19T15:00:03Z")),
                .status(200, try liveBody(stamp: "2026-10-19T15:00:47Z")),
                .status(200, try liveBody(stamp: "2026-10-19T15:00:48Z")),
            ],
            history: [
                .status(200, try historyPage()),
                .status(200, try historyPage()),
            ]
        )
        let mailbox = try client(transport)
        var session = AwaySession()
        session = try await session.refreshed(using: mailbox, now: now)
        let firstReport = try XCTUnwrap(session.latest).generatedAt
        let firstChart = try XCTUnwrap(session.history).generatedAt
        session = try await session.refreshed(using: mailbox, now: now.addingTimeInterval(15))
        session = try await session.refreshed(using: mailbox, now: now.addingTimeInterval(59))
        XCTAssertEqual(transport.historyReadCount, 1)
        XCTAssertNil(session.problem)
        XCTAssertGreaterThan(try XCTUnwrap(session.latest).generatedAt, firstReport)
        XCTAssertEqual(session.history?.generatedAt, firstChart)
        session = try await session.refreshed(using: mailbox, now: now.addingTimeInterval(60))
        XCTAssertEqual(transport.historyReadCount, 2)
        XCTAssertNil(session.problem)
        XCTAssertEqual(session.history?.generatedAt, firstChart)
        XCTAssertNil(session.board.machine.chartNote)
        XCTAssertFalse(session.board.machine.series.isEmpty)
    }

    func testAHistoryMissIsNotAskedAgainInsideAMinute() async throws {
        let transport = ScriptedMailbox(
            latest: [
                .status(200, try liveBody()),
                .status(200, try liveBody(stamp: "2026-10-19T15:00:03Z")),
            ],
            history: [.status(500, Data()), .status(404, Data())]
        )
        let mailbox = try client(transport)
        var session = AwaySession()
        session = try await session.refreshed(using: mailbox, now: now)
        XCTAssertNotNil(session.latest)
        session = try await session.refreshed(using: mailbox, now: now.addingTimeInterval(15))
        XCTAssertEqual(transport.historyReadCount, 1)
        XCTAssertNil(session.problem)
        XCTAssertEqual(
            session.latest?.generatedAt,
            try FixtureBook.away(named: "away-live").generatedAt.addingTimeInterval(15)
        )
    }

    func testCancellationLeavesTheSessionAlone() async throws {
        let saved = try await refresh(
            latest: [.status(200, liveBody())],
            history: [.status(200, historyPage())],
            at: now
        ).0
        let transport = ScriptedMailbox(
            latest: [.status(200, try liveBody(stamp: "2026-10-19T15:00:03Z"))],
            history: [.cancel]
        )
        do {
            _ = try await saved.refreshed(using: client(transport), now: now.addingTimeInterval(60))
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertEqual(transport.historyReadCount, 1)
        XCTAssertEqual(saved.problem, nil)
        XCTAssertEqual(saved.latest?.generatedAt, try FixtureBook.away(named: "away-live").generatedAt)
        XCTAssertNotNil(saved.history)
    }

}
