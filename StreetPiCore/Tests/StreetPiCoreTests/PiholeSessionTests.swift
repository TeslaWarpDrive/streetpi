import XCTest
@testable import StreetPiCore

/// A stale session id must never reach the "Sign in again" screen while the saved password works.
final class PiholeSessionTests: XCTestCase {
    func testConcurrentReadsOnAStaleSessionShareOneSignIn() async throws {
        let pi = FakePi()
        let client = makeClient(pi)
        await client.restoreSession(id: "stale-sid", expiresAt: .streetFixtureNow.addingTimeInterval(600))
        try await withThrowingTaskGroup(of: Int.self) { group in
            for _ in 0..<6 {
                group.addTask { try await client.summary().queriesToday ?? 0 }
            }
            for try await total in group {
                XCTAssertEqual(total, 12)
            }
        }
        XCTAssertEqual(pi.logins, 1)
    }

    func testSignOutLandingDuringTheRetrySignsInOnceMore() async throws {
        let pi = FakePi()
        pi.dropNextIssuedSession = true
        let client = makeClient(pi)
        await client.restoreSession(id: "stale-sid", expiresAt: .streetFixtureNow.addingTimeInterval(600))
        let summary = try await client.summary()
        XCTAssertEqual(summary.queriesToday, 12)
        XCTAssertEqual(pi.logins, 2)
    }

    func testBackgroundSignOutWhileReadsAreInFlight() async throws {
        let pi = FakePi()
        let client = makeClient(pi)
        _ = try await client.summary()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<4 {
                group.addTask { _ = try await client.summary() }
            }
            group.addTask { await client.appDidEnterBackground() }
            try await group.waitForAll()
        }
        _ = try await client.summary()
    }

    func testWrongPasswordIsTheOnlyWayToSignInAgain() async {
        let pi = FakePi()
        pi.acceptsPassword = false
        let client = makeClient(pi)
        await client.restoreSession(id: "stale-sid", expiresAt: .streetFixtureNow.addingTimeInterval(600))
        await assertProblem(.needsSignIn) { _ = try await client.summary() }
    }

    func testAPiThatKeepsDroppingSessionsIsNotASignInProblem() async {
        let pi = FakePi()
        pi.rejectsEverySession = true
        let client = makeClient(pi)
        await assertProblem(.offline) { _ = try await client.summary() }
        XCTAssertEqual(pi.logins, 3)
    }

    private func makeClient(_ pi: FakePi) -> PiholeClient {
        PiholeClient(transport: pi, password: { "fixture-not-a-real-password" }, now: { .streetFixtureNow })
    }

    private func assertProblem(
        _ expected: PiholeProblem,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ work: () async throws -> Void
    ) async {
        do {
            try await work()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch let problem as PiholeProblem {
            XCTAssertEqual(problem, expected, file: file, line: line)
        } catch {
            XCTFail("Unexpected error", file: file, line: line)
        }
    }
}

/// Behaves like FTL: a login issues a new id, DELETE drops one, and a read with an unknown id is a 401.
private final class FakePi: PiholeTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var live: Set<String> = []
    private var issued = 0
    private var dropNext = false
    private var acceptsPasswordValue = true
    private var rejectsAll = false

    var logins: Int { locked { issued } }

    var dropNextIssuedSession: Bool {
        get { locked { dropNext } }
        set { locked { dropNext = newValue } }
    }

    var acceptsPassword: Bool {
        get { locked { acceptsPasswordValue } }
        set { locked { acceptsPasswordValue = newValue } }
    }

    var rejectsEverySession: Bool {
        get { locked { rejectsAll } }
        set { locked { rejectsAll = newValue } }
    }

    func send(_ request: PiholeRequest) async throws -> PiholeResponse {
        await Task.yield()
        let reply = locked { answer(request) }
        await Task.yield()
        return reply
    }

    private func answer(_ request: PiholeRequest) -> PiholeResponse {
        let sid = request.headers[FTLSessionPolicy.sidHeader]
        switch (request.method, request.path) {
        case ("POST", "/api/auth"):
            guard acceptsPasswordValue else { return json(401, #"{"error":{"key":"unauthorized"}}"#) }
            issued += 1
            let fresh = "sid-\(issued)"
            if dropNext {
                dropNext = false
            } else if !rejectsAll {
                live.insert(fresh)
            }
            return json(200, #"{"session":{"valid":true,"sid":"\#(fresh)","validity":1800}}"#)
        case ("DELETE", "/api/auth"):
            if let sid { live.remove(sid) }
            return json(204, "")
        default:
            guard let sid, live.contains(sid) else { return json(401, #"{"error":{"key":"unauthorized"}}"#) }
            return json(200, #"{"queries":{"total":12,"blocked":3}}"#)
        }
    }

    private func json(_ status: Int, _ text: String) -> PiholeResponse {
        PiholeResponse(status: status, body: Data(text.utf8))
    }

    private func locked<T>(_ work: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return work()
    }
}
