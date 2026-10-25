import XCTest
@testable import StreetPiCore

final class PiholeActionTests: XCTestCase {
    func testWritesShareOneSession() async throws {
        let transport = ScriptedPiholeTransport(steps: [
            .json(200, #"{"session":{"sid":"sid-a","validity":1800}}"#),
            .json(200, #"{"blocking":"disabled","timer":30}"#),
            .json(200, #"{"blocking":"disabled","timer":300}"#),
            .json(200, #"{"blocking":"disabled","timer":1800}"#),
            .json(200, #"{"blocking":"disabled","timer":720}"#),
            .json(200, #"{"blocking":"enabled","timer":null}"#),
            .json(200, #"{"domains":[{"domain":"ads.example.test"}]}"#),
            .json(200, #"{"processed":{"success":[{"item":"news.example.test"}],"errors":[]}}"#),
            ScriptedPiholeTransport.Step(status: 200, body: gravityBody),
        ])
        let client = makeClient(transport)
        let pause30 = try await send(.pauseAdBlocking(.thirtySeconds), client: client)
        let pause5 = try await send(.pauseAdBlocking(.fiveMinutes), client: client)
        let pause30m = try await send(.pauseAdBlocking(.thirtyMinutes), client: client)
        let custom = try XCTUnwrap(PauseLength(seconds: 12 * 60))
        let pauseCustom = try await send(.pauseAdBlocking(custom), client: client)
        let resume = try await send(.resumeAdBlocking, client: client)
        let blocked = try await send(.blockDomain(named: "Ads.Example.Test"), client: client)
        let allowed = try await send(.allowDomain(named: "news.example.test"), client: client)
        let gravity = try await send(.updateBlockLists, client: client)

        XCTAssertEqual(pause30.blocking?.pause, .thirtySeconds)
        XCTAssertTrue(pause30.detail.contains("30 seconds"))
        XCTAssertEqual(pause5.blocking?.pause, .fiveMinutes)
        XCTAssertEqual(pause30m.blocking?.pause, .thirtyMinutes)
        XCTAssertTrue(pauseCustom.detail.contains("12 minutes"))
        XCTAssertEqual(resume.blocking?.enabled, true)
        XCTAssertEqual(resume.title, "Ad blocking is on.")
        XCTAssertEqual(blocked.domainName, "ads.example.test")
        XCTAssertEqual(blocked.domainDetail, "Blocked")
        XCTAssertEqual(allowed.domainName, "news.example.test")
        XCTAssertTrue(gravity.detail.contains("4321"))
        XCTAssertEqual(gravity.listsUpdatedAt, .streetFixtureNow)

        XCTAssertEqual(transport.sent[1].body, Data("{\"blocking\":false,\"timer\":30}".utf8))
        XCTAssertEqual(transport.sent[2].body, Data("{\"blocking\":false,\"timer\":300}".utf8))
        XCTAssertEqual(transport.sent[3].body, Data("{\"blocking\":false,\"timer\":1800}".utf8))
        XCTAssertEqual(transport.sent[4].body, Data("{\"blocking\":false,\"timer\":720}".utf8))
        XCTAssertEqual(transport.sent[5].body, Data("{\"blocking\":true,\"timer\":null}".utf8))
        let paths = transport.sent.map { "\($0.method) \($0.path)" }
        XCTAssertEqual(paths, [
            "POST /api/auth",
            "POST /api/dns/blocking",
            "POST /api/dns/blocking",
            "POST /api/dns/blocking",
            "POST /api/dns/blocking",
            "POST /api/dns/blocking",
            "POST /api/domains/deny/exact",
            "POST /api/domains/allow/exact",
            "POST /api/action/gravity",
        ])
        let writes = transport.sent.filter { $0.path != "/api/auth" }
        XCTAssertTrue(writes.allSatisfy { $0.headers[FTLSessionPolicy.sidHeader] == "sid-a" })
        XCTAssertEqual(transport.sent.filter { $0.path == "/api/auth" }.count, 1)
        let described = transport.sent.map { String(describing: $0) }.joined(separator: "\n")
        XCTAssertFalse(described.contains(Self.fixturePassword))
        XCTAssertFalse(described.contains("sid-a"))
        let spoken = [pause30, pause5, resume, blocked, allowed, gravity].map { "\($0.title) \($0.detail)" }.joined()
        XCTAssertFalse(spoken.contains(Self.fixturePassword))
        XCTAssertFalse(spoken.contains("sid-a"))
        XCTAssertFalse(spoken.contains("192.168"))
    }

    func testTheDeskFollowsThePiAnswer() async throws {
        let transport = ScriptedPiholeTransport(steps: [
            .json(200, #"{"session":{"sid":"sid-a","validity":1800}}"#),
            .json(200, #"{"blocking":"disabled","timer":30.0}"#),
        ])
        let client = makeClient(transport)
        let receipt = try await send(.pauseAdBlocking(.fiveMinutes), client: client)
        let desk = DNSDesk.houseFixture.adopting(receipt)
        XCTAssertEqual(desk.blocking.pause, .thirtySeconds)
        XCTAssertNotEqual(desk.blocking.pause, .fiveMinutes)
        let asked = DNSDesk.houseFixture.applying(.pauseAdBlocking(.fiveMinutes))
        XCTAssertEqual(asked.blocking.pause, .fiveMinutes)
        XCTAssertNotEqual(desk, asked)
    }

    func testFailuresStayInPlainWords() async {
        let refused = ScriptedPiholeTransport(steps: [
            .json(200, #"{"session":{"sid":"sid-a","validity":1800}}"#),
            .json(403, #"{"error":{"key":"forbidden"}}"#),
        ])
        let client = makeClient(refused)
        let before = DNSDesk.houseFixture
        do {
            _ = try await send(.pauseAdBlocking(.thirtySeconds), client: client)
            XCTFail("Expected a refusal")
        } catch let problem as PiholeProblem {
            XCTAssertEqual(problem, .refused)
            XCTAssertTrue(problem.detail.contains("Nothing was changed"))
            XCTAssertFalse(problem.detail.contains("403"))
            XCTAssertEqual(before, DNSDesk.houseFixture)
        } catch {
            XCTFail("Unexpected error")
        }

        let busy = ScriptedPiholeTransport(steps: [
            .json(200, #"{"session":{"sid":"sid-a","validity":1800}}"#),
            .json(409, #"{"error":{"key":"gravity_running"}}"#),
        ])
        let busyClient = makeClient(busy)
        do {
            _ = try await send(.updateBlockLists, client: busyClient)
            XCTFail("Expected a busy Pi")
        } catch let problem as PiholeProblem {
            XCTAssertEqual(problem, .busy)
            XCTAssertTrue(problem.title.contains("already running"))
            XCTAssertFalse(problem.detail.contains("409"))
        } catch {
            XCTFail("Unexpected error")
        }
    }

    func testGravityFailureIsPlain() async {
        let transport = ScriptedPiholeTransport(steps: [
            .json(200, #"{"session":{"sid":"sid-a","validity":1800}}"#),
            ScriptedPiholeTransport.Step(status: 200, body: Data("Gravity failed\n".utf8)),
        ])
        let client = makeClient(transport)
        do {
            _ = try await send(.updateBlockLists, client: client)
            XCTFail("Expected gravity to fail")
        } catch let problem as PiholeProblem {
            XCTAssertEqual(problem, .gravityFailed)
            XCTAssertTrue(problem.detail.contains("Nothing else was changed"))
            XCTAssertFalse(problem.detail.contains("Gravity failed"))
        } catch {
            XCTFail("Unexpected error")
        }
        let gravity = PiholeWrites.gravity()
        XCTAssertEqual(gravity.path, "/api/action/gravity")
        XCTAssertEqual(gravity.body, Data("{}".utf8))
        XCTAssertEqual(gravity.timeout, 300)
        XCTAssertFalse(String(describing: gravity).contains("{}"))
    }

    func testABadNameIsNotSent() async {
        let transport = ScriptedPiholeTransport(steps: [])
        let client = makeClient(transport)
        do {
            _ = try await client.block(domain: "not a domain")
            XCTFail("Expected a bad name")
        } catch let problem as PiholeProblem {
            XCTAssertEqual(problem, .invalidDomain)
        } catch {
            XCTFail("Unexpected error")
        }
        XCTAssertTrue(transport.sent.isEmpty)
        XCTAssertFalse(PiholeActionRoute.callsTheAPI(.refresh))
        XCTAssertFalse(PiholeActionRoute.callsTheAPI(.signOutOfAdBlocker))
        XCTAssertTrue(PiholeActionRoute.callsTheAPI(.updateBlockLists))
        XCTAssertTrue(PiholeActionRoute.callsTheAPI(.pauseAdBlocking(.thirtySeconds)))
    }

    func testASecondClientReusesTheStoredSession() async throws {
        let store = MemorySIDStore()
        let transport = ScriptedPiholeTransport(steps: [
            .json(200, #"{"session":{"sid":"sid-a","validity":1800}}"#),
            .json(200, #"{"blocking":"disabled","timer":30}"#),
            .json(200, #"{"blocking":"enabled","timer":null}"#),
            .json(204, "{}"),
        ])
        let first = PiholeClient(
            transport: transport,
            password: { Self.fixturePassword },
            now: { .streetFixtureNow },
            sessions: store
        )
        _ = try await first.pause(seconds: 30)
        let second = PiholeClient(
            transport: transport,
            password: { Self.fixturePassword },
            now: { .streetFixtureNow },
            sessions: store
        )
        _ = try await second.resume()
        XCTAssertEqual(store.loadSID(), "sid-a")
        XCTAssertEqual(transport.sent.map(\.path), ["/api/auth", "/api/dns/blocking", "/api/dns/blocking"])
        XCTAssertEqual(transport.sent[2].headers[FTLSessionPolicy.sidHeader], "sid-a")
        await second.signOut()
        XCTAssertNil(store.loadSID())
        XCTAssertEqual(transport.sent.last?.method, "DELETE")
        let described = transport.sent.map { String(describing: $0) }.joined(separator: " ")
        XCTAssertFalse(described.contains("sid-a"))
        XCTAssertFalse(described.contains(Self.fixturePassword))
    }

    func testAPIPathsDropTheRepeatedRoot() {
        XCTAssertEqual(PiholeAPIPath.underAPIRoot("/api/dns/blocking"), "dns/blocking")
        XCTAssertEqual(PiholeAPIPath.underAPIRoot("/api/action/gravity"), "action/gravity")
        XCTAssertEqual(PiholeAPIPath.underAPIRoot("/api/domains/allow/exact"), "domains/allow/exact")
        XCTAssertFalse(PiholeAPIPath.underAPIRoot("/api/dns/blocking").contains("192.168"))
    }

    func testColoredGravityStillReadsTheCount() throws {
        let raw = Data("\u{1B}[32m[i] Number of gravity domains: 1,234\u{1B}[0m\n".utf8)
        let report = try PiholeDecode.gravity(from: raw)
        XCTAssertEqual(report.domainCount, 1_234)
        XCTAssertEqual(report.detail, "The Pi is now using 1234 domains on the block lists.")
        XCTAssertFalse(report.detail.contains("["))
    }

    private static let fixturePassword = "fixture-not-a-real-password"

    private func makeClient(_ transport: ScriptedPiholeTransport) -> PiholeClient {
        PiholeClient(transport: transport, password: { Self.fixturePassword }, now: { .streetFixtureNow })
    }

    private func send(_ action: HouseholdAction, client: PiholeClient) async throws -> ActionReceipt {
        try await PiholeActions.perform(action, client: client, now: .streetFixtureNow)
    }

    private var gravityBody: Data {
        Data("  [i] Number of gravity domains: 4321 (4321 unique domains)\n".utf8)
    }
}

private final class MemorySIDStore: FTLSessionStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var value: String?

    func loadSID() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func saveSID(_ sid: String) {
        lock.lock()
        value = sid
        lock.unlock()
    }

    func clearSID() {
        lock.lock()
        value = nil
        lock.unlock()
    }
}
