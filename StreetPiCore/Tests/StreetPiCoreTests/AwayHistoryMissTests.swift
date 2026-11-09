import Foundation
import XCTest
@testable import StreetPiCore

/// The one changed row. A history miss must not stick on the badge while the latest report keeps updating.
final class AwayHistoryMissTests: XCTestCase {
    private let now = Date.streetFixtureNow

    private struct Miss {
        var name: String
        var answer: MailboxAnswer
        var problem: MailboxProblem
    }

    func testAHistoryMissStaysOffTheBadgeWhileTheReportUpdates() async throws {
        let misses = [
            Miss(name: "offline", answer: .status(500, Data()), problem: .offline),
            Miss(name: "timeout", answer: .timeout, problem: .offline),
            Miss(name: "refused", answer: .status(401, Data()), problem: .refused),
            Miss(name: "wrong address", answer: .status(404, Data()), problem: .wrongAddress),
            Miss(name: "unreadable", answer: .status(200, Data("{\"schema\":2}".utf8)), problem: .notUnderstood),
        ]
        for miss in misses {
            let (session, transport) = try await refresh(
                latest: [.status(200, liveBody())],
                history: [miss.answer],
                at: now
            )
            XCTAssertEqual(transport.historyReadCount, 1, miss.name)
            try assertStaysOffTheBadge(session, problem: miss.problem, at: now, name: miss.name)
            XCTAssertNil(session.history, miss.name)
            XCTAssertTrue(session.board.machine.series.isEmpty, miss.name)
            XCTAssertFalse(session.board.desk.hasDayLookups, miss.name)
        }
    }

    func testARepeatingHistoryMissDoesNotStickWhileLatestMoves() async throws {
        let transport = ScriptedMailbox(
            latest: [
                .status(200, try liveBody()),
                .status(200, try liveBody(stamp: "2026-10-19T15:00:48Z")),
                .status(200, try staleLiveBody(stamp: "2026-10-19T15:01:48Z")),
            ],
            history: [
                .status(200, try historyPage()),
                .status(404, Data()),
                .status(500, Data()),
            ]
        )
        let mailbox = try client(transport)
        var session = AwaySession()
        session = try await session.refreshed(using: mailbox, now: now)
        let savedChart = try XCTUnwrap(session.history).generatedAt
        XCTAssertNil(session.problem)
        XCTAssertNil(session.historyProblem)

        let firstMiss = now.addingTimeInterval(60)
        session = try await session.refreshed(using: mailbox, now: firstMiss)
        try assertStaysOffTheBadge(session, problem: .wrongAddress, at: firstMiss, name: "first miss")
        XCTAssertEqual(session.history?.generatedAt, savedChart)
        XCTAssertTrue(session.board.desk.hasDayLookups)
        XCTAssertEqual(
            session.latest?.generatedAt,
            try FixtureBook.away(named: "away-live").generatedAt.addingTimeInterval(60)
        )

        let secondMiss = now.addingTimeInterval(120)
        session = try await session.refreshed(using: mailbox, now: secondMiss)
        try assertStaysOffTheBadge(
            session,
            problem: .offline,
            at: secondMiss,
            detail: AwayCopy.someEarlier,
            name: "second miss"
        )
        XCTAssertEqual(session.history?.generatedAt, savedChart)
        XCTAssertEqual(transport.historyReadCount, 3)
    }

    func testALatestMissStillOwnsTheBadgeWhenTheChartIsAlreadyBehind() async throws {
        let (saved, _) = try await refresh(
            latest: [.status(200, liveBody())],
            history: [.status(404, Data())],
            at: now
        )
        XCTAssertEqual(saved.historyProblem, .wrongAddress)
        XCTAssertNil(saved.problem)
        let later = now.addingTimeInterval(15)
        let (session, transport) = try await refresh(
            saved,
            latest: [.status(500, Data())],
            history: [.status(500, Data())],
            at: later
        )
        XCTAssertEqual(transport.historyReadCount, 0)
        XCTAssertEqual(session.problem, .offline)
        XCTAssertEqual(session.historyProblem, .wrongAddress)
        XCTAssertEqual(session.latest?.generatedAt, saved.latest?.generatedAt)
        let badge = session.status.badge(now: later)
        XCTAssertEqual(badge.detail, AwayCopy.problem(.offline))
        XCTAssertFalse(badge.offersSetup)
        XCTAssertEqual(session.board.machine.chartNote, AwayCopy.problem(.wrongAddress))
    }

    func testALaterHistoryReadClearsOnlyTheChart() async throws {
        let (missed, _) = try await refresh(
            latest: [.status(200, liveBody())],
            history: [.status(500, Data())],
            at: now
        )
        XCTAssertEqual(missed.historyProblem, .offline)
        let (session, transport) = try await refresh(
            missed,
            latest: [.status(200, liveBody(stamp: "2026-10-19T15:00:48Z"))],
            history: [.status(200, historyPage())],
            at: now.addingTimeInterval(60)
        )
        XCTAssertEqual(transport.historyReadCount, 1)
        XCTAssertNil(session.problem)
        XCTAssertNil(session.historyProblem)
        XCTAssertNotNil(session.history)
        XCTAssertNil(session.status.badge(now: now.addingTimeInterval(60)).detail)
        XCTAssertEqual(session.board.machine.chartNote, AwayCopy.chartWaiting)
        XCTAssertFalse(session.board.machine.series.isEmpty)
    }

    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    private func liveBody(stamp: String = "2026-10-19T14:59:48Z") throws -> Data {
        var text = try XCTUnwrap(String(data: fixture("away-live"), encoding: .utf8))
        text = text.replacingOccurrences(of: "2026-10-19T14:59:48Z", with: stamp)
        return Data(text.utf8)
    }

    private func staleLiveBody(stamp: String) throws -> Data {
        var text = try XCTUnwrap(String(data: liveBody(stamp: stamp), encoding: .utf8))
        text = text.replacingOccurrences(of: "\"machine\": \"ok\"", with: "\"machine\": \"stale\"")
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

    private func assertStaysOffTheBadge(
        _ session: AwaySession,
        problem: MailboxProblem,
        at time: Date,
        detail: String? = nil,
        name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        XCTAssertNil(session.problem, name, file: file, line: line)
        XCTAssertEqual(session.historyProblem, problem, name, file: file, line: line)
        let generatedAt = try XCTUnwrap(session.latest, name, file: file, line: line).generatedAt
        let badge = session.status.badge(now: time)
        let freshness = AwayFreshness.make(generatedAt: generatedAt, now: time)
        XCTAssertEqual(badge.line, freshness.line, name, file: file, line: line)
        XCTAssertEqual(badge.detail, detail, name, file: file, line: line)
        let tone: PlainEnglishStatus.Tone = switch freshness.level {
        case .fresh: .calm
        case .stale: .attention
        case .silent: .problem
        }
        XCTAssertEqual(badge.tone, tone, name, file: file, line: line)
        XCTAssertFalse(badge.offersSetup, name, file: file, line: line)
        XCTAssertEqual(session.board.machine.chartNote, AwayCopy.problem(problem), name, file: file, line: line)
        XCTAssertEqual(session.board.desk.knownClients, 14, name, file: file, line: line)
    }
}
