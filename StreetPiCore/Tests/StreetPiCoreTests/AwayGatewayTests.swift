import Foundation
import XCTest
@testable import StreetPiCore

final class AwayGatewayTests: XCTestCase {
    private let secret = "cfast_FAKE_not_a_real_secret"

    private func gateway() throws -> AwayGatewaySettings {
        try XCTUnwrap(AwayGatewaySettings(
            url: "https://gateway.example.test/",
            clientID: "test-client.access",
            clientSecret: secret
        ))
    }

    private func url(_ text: String) throws -> URL {
        try XCTUnwrap(URL(string: text))
    }

    func testOnlyAnHTTPSOriginIsAccepted() {
        for address in [
            "http://gateway.example.test",
            "https://user:pass@gateway.example.test",
            "https://gateway.example.test/api",
            "https://gateway.example.test?a=b",
            "gateway.example.test",
            "",
        ] {
            XCTAssertNil(AwayGatewaySettings(url: address, clientID: "id", clientSecret: "key"), address)
        }
    }

    func testCredentialsMustBeWhole() {
        let address = "https://gateway.example.test"
        XCTAssertNil(AwayGatewaySettings(url: address, clientID: "", clientSecret: "key"))
        XCTAssertNil(AwayGatewaySettings(url: address, clientID: "id", clientSecret: "   "))
        XCTAssertNil(AwayGatewaySettings(url: address, clientID: "id", clientSecret: "a\r\nX-Other: b"))
    }

    func testDescriptionsNeverCarryTheCredentials() throws {
        let gateway = try gateway()
        for text in [
            String(describing: gateway),
            String(reflecting: gateway),
            "\(ConnectionMode.awayLive(gateway))",
            "\(Mirror(reflecting: gateway).children.map(\.label))",
        ] {
            XCTAssertFalse(text.contains(secret))
            XCTAssertFalse(text.contains("test-client"))
        }
    }

    func testKeychainDataRoundTrips() throws {
        let gateway = try gateway()
        XCTAssertEqual(AwayGatewaySettings(keychain: try gateway.keychainData()), gateway)
        XCTAssertNil(AwayGatewaySettings(keychain: Data("{}".utf8)))
    }

    func testHeadersGoOnlyToTheGateway() throws {
        let gateway = try gateway()
        let sent = gateway.accessHeaders(for: try url("https://gateway.example.test/api/queries?length=40"))
        XCTAssertEqual(sent["CF-Access-Client-Id"], "test-client.access")
        XCTAssertEqual(sent["CF-Access-Client-Secret"], secret)
        XCTAssertFalse(gateway.accessHeaders(for: try url("https://GATEWAY.example.test/healthz")).isEmpty)
        for other in [
            "https://192.168.1.78/api/info/login",
            "http://192.168.1.78:19999/api/v1/info",
            "https://mailbox.example.test/v1/latest",
            "http://gateway.example.test/healthz",
            "https://gateway.example.test:8443/healthz",
            "https://gateway.example.test.evil.test/healthz",
            "https://evil.test/gateway.example.test",
            "https://user@gateway.example.test/healthz",
        ] {
            XCTAssertTrue(gateway.accessHeaders(for: try url(other)).isEmpty, other)
        }
    }

    func testEachServiceHasItsPlaceBehindTheGateway() throws {
        let gateway = try gateway()
        XCTAssertEqual(gateway.piholeBase?.absoluteString, "https://gateway.example.test")
        XCTAssertEqual(gateway.netdataBase?.absoluteString, "https://gateway.example.test/netdata")
        XCTAssertEqual(gateway.kumaBase?.absoluteString, "https://gateway.example.test/kuma")
        XCTAssertEqual(gateway.healthURL?.absoluteString, "https://gateway.example.test/healthz")
    }

    func testTheStatusPageKeepsSchemeAndPrefixAway() throws {
        let base = try XCTUnwrap(try gateway().kumaBase)
        let endpoint = try XCTUnwrap(StatusPageEndpoint.make(base: base, slug: "house"))
        XCTAssertEqual(
            endpoint.url(path: try XCTUnwrap(endpoint.pagePath))?.absoluteString,
            "https://gateway.example.test/kuma/api/status-page/house"
        )
        XCTAssertEqual(
            StatusPageEndpoint.house.url(path: "/api/status-page/house")?.absoluteString,
            "http://192.168.1.78:3001/api/status-page/house"
        )
    }

    func testEdgeRepliesBecomeProblemsAndPiRepliesPassThrough() async throws {
        XCTAssertEqual(AwayGatewayReply.problem(status: 429), .rateLimited)
        for status in [502, 503, 504, 520, 524, 530] {
            XCTAssertEqual(AwayGatewayReply.problem(status: status), .offline)
        }
        for status in [200, 400, 401, 403, 404, 409, 500] {
            XCTAssertNil(AwayGatewayReply.problem(status: status))
        }
        let quiet = AwayPiholeTransport(base: ScriptedPiholeTransport(steps: [.json(404, "{}")]))
        let reply = try await quiet.send(PiholeRequest(method: "GET", path: "/api/x", headers: [:], body: nil))
        XCTAssertEqual(reply.status, 404)
    }

    /// Every call the app can make, written the way the gateway sees it.
    private var appCalls: Set<String> {
        var calls = Set(DNSAPI.routes.map { "\($0.method) \($0.path)" })
        calls.formUnion(NetdataAPI.routes.map { "\($0.method) /netdata\($0.path)" })
        calls.insert("\(StatusPageAPI.route.method) /kuma\(StatusPageAPI.route.path)")
        calls.insert("\(StatusPageAPI.heartbeatRoute.method) /kuma\(StatusPageAPI.heartbeatRoute.path)")
        calls.insert("GET /healthz")
        return calls
    }

    func testAppCallsMatchTheGatewayAllowlist() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let file = root.appendingPathComponent("gateway/allowlist.json")
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw XCTSkip("gateway/allowlist.json has not merged yet, so parity is not checked in this run.")
        }
        struct Entry: Decodable {
            var method: String
            var path: String
        }
        let entries = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: file))
        let allowed = Set(entries.map { "\($0.method) \($0.path)" })
        XCTAssertEqual(appCalls.subtracting(allowed).sorted(), [], "The gateway refuses these.")
        XCTAssertEqual(allowed.subtracting(appCalls).sorted(), [], "The app never calls these.")
    }
}

final class AwayGravityTests: XCTestCase {
    private static let signedIn = ScriptedPiholeTransport.Step.json(
        200,
        "{\"session\":{\"sid\":\"fixture-not-a-real-session\",\"validity\":1800}}"
    )

    private func summary(_ stamp: Int, _ domains: Int) -> ScriptedPiholeTransport.Step {
        .json(200, "{\"gravity\":{\"last_update\":\(stamp),\"domains_being_blocked\":\(domains)}}")
    }

    private func run(_ steps: [ScriptedPiholeTransport.Step]) async throws -> (ActionReceipt, GravityLog) {
        let log = GravityLog()
        let transport = AwayPiholeTransport(base: ScriptedPiholeTransport(steps: [Self.signedIn] + steps))
        let client = PiholeClient(transport: transport, password: { "fixture-password" })
        let flow = AwayGravityFlow(
            client: client,
            now: { log.now },
            sleep: { log.slept($0) },
            onStep: { log.stepped($0) }
        )
        return (try await flow.run(), log)
    }

    func testA524MeansCheckBack() async throws {
        let (receipt, log) = try await run([
            summary(100, 5), .json(524, ""), summary(100, 5), summary(200, 7),
        ])
        XCTAssertEqual(receipt.title, "Block lists updated.")
        XCTAssertTrue(receipt.detail.contains("7"))
        XCTAssertNotNil(receipt.listsUpdatedAt)
        XCTAssertEqual(log.sleeps, [15, 15])
        XCTAssertEqual(log.steps.first, .updating)
    }

    func testACutConnectionMeansCheckBack() async throws {
        let (receipt, log) = try await run([summary(100, 5), .fail(.offline), summary(200, 9)])
        XCTAssertTrue(receipt.detail.contains("9"))
        XCTAssertEqual(log.sleeps, [15])
    }

    func testAMissedCheckKeepsChecking() async throws {
        let (receipt, log) = try await run([
            summary(100, 5), .json(524, ""), .fail(.offline), .json(530, ""), summary(200, 9),
        ])
        XCTAssertTrue(receipt.detail.contains("9"))
        XCTAssertEqual(log.sleeps, [15, 15, 15])
    }

    func testA200StillWaitsForTheSummary() async throws {
        let (receipt, log) = try await run([
            summary(100, 5), .json(200, ""), summary(100, 5), summary(200, 42),
        ])
        XCTAssertTrue(receipt.detail.contains("42"))
        XCTAssertEqual(log.sleeps, [15, 15])
    }

    func testAFailedRunIsStillAFailure() async {
        do {
            _ = try await run([summary(100, 5), .json(200, "Gravity failed")])
            XCTFail("Expected a failure")
        } catch {
            XCTAssertEqual(error as? PiholeProblem, .gravityFailed)
        }
    }

    func testTenMinutesEndsInStillUpdating() async throws {
        let quiet = Array(repeating: summary(100, 5), count: 50)
        let (receipt, log) = try await run([summary(100, 5), .json(524, "")] + quiet)
        XCTAssertEqual(receipt.title, AwayCopy.gravityStillTitle)
        XCTAssertNil(receipt.listsUpdatedAt)
        XCTAssertEqual(log.sleeps.reduce(0, +), AwayGravityFlow.capSeconds - AwayGravityFlow.pollSeconds)
    }

    func testTheFinalLookCanConfirmCompletionBeforeGivingUp() async throws {
        let log = GravityLog()
        let script = ScriptedPiholeTransport(steps: [
            Self.signedIn, summary(100, 5), .json(524, ""), summary(100, 5), summary(200, 42),
        ])
        let transport = GravityTimingTransport(base: script, onStart: { log.slept(570) })
        let receipt = try await flow(transport, log: log).run()
        XCTAssertNotNil(receipt.listsUpdatedAt)
        XCTAssertTrue(receipt.detail.contains("42"))
        XCTAssertEqual(log.now.timeIntervalSince1970, 1_000_585)
    }

    func testTimeSpentInARequestCountsAgainstTheDeadline() async throws {
        let log = GravityLog()
        let script = ScriptedPiholeTransport(steps: [
            Self.signedIn, summary(100, 5), .json(200, ""), summary(200, 42),
        ])
        let transport = GravityTimingTransport(base: script, onStart: { log.slept(601) })
        let receipt = try await flow(transport, log: log).run()
        XCTAssertEqual(receipt.title, AwayCopy.gravityStillTitle)
        XCTAssertNil(receipt.listsUpdatedAt)
        XCTAssertEqual(script.sent.filter { $0.path == "/api/stats/summary" }.count, 1)
    }

    func testAPollAcrossTheDeadlineIsCancelled() async throws {
        let script = ScriptedPiholeTransport(steps: [
            Self.signedIn, summary(100, 5), .json(524, ""),
        ])
        let transport = HangingGravityPoll(base: script)
        let client = PiholeClient(transport: transport, password: { "fixture-password" })
        let receipt = try await AwayGravityFlow(
            client: client, timeLimit: 0.1, sleep: { _ in }, onStep: { _ in }
        ).run()
        XCTAssertEqual(receipt.title, AwayCopy.gravityStillTitle)
        XCTAssertNil(receipt.listsUpdatedAt)
        let cancelled = await transport.wasCancelled
        XCTAssertTrue(cancelled)
    }

    private func flow(_ transport: any PiholeTransport, log: GravityLog) -> AwayGravityFlow {
        AwayGravityFlow(
            client: PiholeClient(transport: AwayPiholeTransport(base: transport), password: { "fixture-password" }),
            now: { log.now }, sleep: { log.slept($0) }, onStep: { log.stepped($0) }
        )
    }

    func testARateLimitedStartBacksOffAndRetries() async throws {
        let (receipt, log) = try await run([
            summary(100, 5), .json(429, ""), .json(429, ""), .json(524, ""), summary(200, 7),
        ])
        XCTAssertTrue(receipt.detail.contains("7"))
        XCTAssertEqual(log.sleeps, [15, 30, 15])
        XCTAssertTrue(log.steps.contains(.busyRetrying))
    }

    func testARateLimitedCheckBacksOff() async throws {
        let (receipt, log) = try await run([
            summary(100, 5), .json(524, ""), .json(429, ""), summary(200, 7),
        ])
        XCTAssertTrue(receipt.detail.contains("7"))
        XCTAssertEqual(log.sleeps, [15, 30])
    }

    func testBackoffIsCapped() {
        XCTAssertEqual((0...5).map(AwayGravityFlow.backoffSeconds), [15, 30, 60, 60, 60, 60])
    }

    func testHomeIsUnchanged() async throws {
        let transport = ScriptedPiholeTransport(steps: [Self.signedIn, .json(524, "")])
        let client = PiholeClient(transport: transport, password: { "fixture-password" })
        do {
            _ = try await PiholeActions.perform(.updateBlockLists, client: client, now: Date())
            XCTFail("Expected the 524 to be a failure at home")
        } catch {
            XCTAssertEqual(error as? PiholeProblem, .notUnderstood)
        }
        XCTAssertEqual(transport.sent.map(\.path), ["/api/auth", "/api/action/gravity"])
    }
}

private final class GravityLog: @unchecked Sendable {
    private let lock = NSLock()
    private var clock = Date(timeIntervalSince1970: 1_000_000)
    private var sleptSeconds: [Int] = []
    private var seenSteps: [AwayGravityStep] = []

    var now: Date {
        lock.lock()
        defer { lock.unlock() }
        return clock
    }

    var sleeps: [Int] {
        lock.lock()
        defer { lock.unlock() }
        return sleptSeconds
    }

    var steps: [AwayGravityStep] {
        lock.lock()
        defer { lock.unlock() }
        return seenSteps
    }

    func slept(_ seconds: Int) {
        lock.lock()
        sleptSeconds.append(seconds)
        clock.addTimeInterval(TimeInterval(seconds))
        lock.unlock()
    }

    func stepped(_ step: AwayGravityStep) {
        lock.lock()
        seenSteps.append(step)
        lock.unlock()
    }
}

private struct GravityTimingTransport: PiholeTransport {
    var base: ScriptedPiholeTransport
    var onStart: @Sendable () -> Void

    func send(_ request: PiholeRequest) async throws -> PiholeResponse {
        if request.path == "/api/action/gravity" { onStart() }
        return try await base.send(request)
    }
}

private actor HangingGravityPoll: PiholeTransport {
    let base: ScriptedPiholeTransport
    var summaries = 0
    private(set) var wasCancelled = false

    init(base: ScriptedPiholeTransport) { self.base = base }

    func send(_ request: PiholeRequest) async throws -> PiholeResponse {
        if request.path == "/api/stats/summary" {
            summaries += 1
            if summaries > 1 {
                do {
                    try await Task.sleep(for: .seconds(30))
                } catch {
                    wasCancelled = true
                    throw error
                }
            }
        }
        return try await AwayPiholeTransport(base: base).send(request)
    }
}
