import StreetPiCore
import XCTest
@testable import StreetPi

/// Stands in for the network, so the real URLSession stack runs and no socket opens.
private final class GatewayStub: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var seen: [URLRequest] = []
    nonisolated(unsafe) private static var redirectTarget: URL?

    static func reset(redirectingTo target: URL? = nil) {
        lock.lock()
        seen = []
        redirectTarget = target
        lock.unlock()
    }

    static var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return seen
    }

    private static func take(_ request: URLRequest) -> URL? {
        lock.lock()
        defer { lock.unlock() }
        seen.append(request)
        return redirectTarget
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let url = request.url else { return }
        let target = Self.take(request)
        let status = target == nil ? 200 : 302
        let fields = target.map { ["Location": $0.absoluteString] } ?? [:]
        guard let response = HTTPURLResponse(
            url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: fields
        ) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

final class AwayLiveTests: XCTestCase {
    private let suite = "streetpi.tests.away-gateway"
    private let secret = "cfast_FAKE_not_a_real_secret"
    private var defaults = UserDefaults()

    override func setUpWithError() throws {
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        GatewayStub.reset()
    }

    private func gateway() throws -> AwayGatewaySettings {
        try XCTUnwrap(AwayGatewaySettings(
            url: "https://gateway.example.test",
            clientID: "test-client.access",
            clientSecret: secret
        ))
    }

    private func stubbed() -> URLSessionConfiguration {
        let configuration = LiveHTTPClient.sessionConfiguration()
        configuration.protocolClasses = [GatewayStub.self]
        return configuration
    }

    private func client() throws -> AwayHTTPClient {
        AwayHTTPClient(settings: try gateway(), configuration: stubbed())
    }

    private func url(_ text: String) throws -> URL {
        try XCTUnwrap(URL(string: text))
    }

    func testTheGatewayGetsTheAccessHeaders() async throws {
        let reply = try await client().get(try url("https://gateway.example.test/healthz"), headers: [:])
        XCTAssertEqual(reply.status, 200)
        let sent = try XCTUnwrap(GatewayStub.requests.first)
        XCTAssertEqual(sent.value(forHTTPHeaderField: "CF-Access-Client-Id"), "test-client.access")
        XCTAssertEqual(sent.value(forHTTPHeaderField: "CF-Access-Client-Secret"), secret)
    }

    func testTheAwayClientRefusesEveryOtherHost() async throws {
        let http = try client()
        for other in ["https://192.168.1.78/api/info/login", "https://mailbox.example.test/v1/latest"] {
            do {
                _ = try await http.get(try url(other), headers: [:])
                XCTFail("Expected a refusal for \(other)")
            } catch {
                XCTAssertEqual(error as? LiveHTTPProblem, .badAddress)
            }
        }
        XCTAssertTrue(GatewayStub.requests.isEmpty)
    }

    func testTheSessionRefusesARedirect() throws {
        let http = try client()
        let refusal = try XCTUnwrap(http.trustDelegate as? RedirectRefusal)
        let target = try url("https://elsewhere.example.test/steal")
        let from = try url("https://gateway.example.test/api/queries")
        let response = try XCTUnwrap(HTTPURLResponse(
            url: from, statusCode: 302, httpVersion: "HTTP/1.1", headerFields: ["Location": target.absoluteString]
        ))
        let answered = expectation(description: "The redirect is answered")
        refusal.urlSession(
            URLSession.shared,
            task: URLSession.shared.dataTask(with: from),
            willPerformHTTPRedirection: response,
            newRequest: URLRequest(url: target)
        ) { next in
            XCTAssertNil(next)
            answered.fulfill()
        }
        wait(for: [answered], timeout: 1)
    }

    func testARedirectStopsAtTheCaller() async throws {
        GatewayStub.reset(redirectingTo: try url("https://elsewhere.example.test/steal"))
        let reply = try await client().get(try url("https://gateway.example.test/api/queries"), headers: [:])
        XCTAssertEqual(reply.status, 302)
        XCTAssertEqual(GatewayStub.requests.map(\.url?.host), ["gateway.example.test"])
        let road = try XCTUnwrap(LiveEndpoints.away(try gateway()))
        let transport = LivePiholeTransport(http: try client(), base: road.pihole)
        do {
            _ = try await transport.send(PiholeRequest(method: "GET", path: "/api/queries", headers: [:], body: nil))
            XCTFail("Expected the redirect to be refused")
        } catch {
            XCTAssertEqual(error as? PiholeProblem, .notUnderstood)
        }
    }

    func testTheHomeClientNeverHoldsTheHeaders() async throws {
        let home = LiveHTTPClient(pinner: CertificatePinner(host: "fixture.test"), configuration: stubbed())
        _ = try await home.get(try url("https://fixture.test/api/info/login"), headers: [:])
        let sent = try XCTUnwrap(GatewayStub.requests.first)
        XCTAssertNil(sent.value(forHTTPHeaderField: "CF-Access-Client-Id"))
        XCTAssertNil(sent.value(forHTTPHeaderField: "CF-Access-Client-Secret"))
    }

    func testThePinStaysOnTheHomeNetwork() throws {
        XCTAssertFalse(try client().trustDelegate is CertificatePinner)
        XCTAssertTrue(try client().trustDelegate is RedirectRefusal)
        XCTAssertEqual(LiveHTTPClient(store: LiveHostStore(defaults: defaults)).pinner.trustedHost(), LiveHouse.host)
    }

    func testAwayEndpointsAndPaths() throws {
        let road = try XCTUnwrap(LiveEndpoints.away(try gateway()))
        XCTAssertEqual(
            LivePiholeTransport.endpoint(base: road.pihole, pathAndQuery: "/api/queries?length=40")?.absoluteString,
            "https://gateway.example.test/api/queries?length=40"
        )
        XCTAssertEqual(
            LivePaths.url(base: road.netdata, path: "/api/v1/info")?.absoluteString,
            "https://gateway.example.test/netdata/api/v1/info"
        )
        XCTAssertEqual(
            LivePaths.url(base: road.uptimeKuma, path: "/api/status-page/house")?.absoluteString,
            "https://gateway.example.test/kuma/api/status-page/house"
        )
    }

    func testNetdataReadsThroughTheGateway() async throws {
        let road = try XCTUnwrap(LiveEndpoints.away(try gateway()))
        let transport = NetdataLiveTransport(client: try client(), base: road.netdata, isAway: true)
        _ = try await transport.get("/api/v1/info")
        XCTAssertEqual(GatewayStub.requests.first?.url?.path, "/netdata/api/v1/info")
    }

    func testTheSeedFillsTheKeychainOnce() throws {
        let data = Data("""
        {"version":2,"gateway":{"url":"https://gateway.example.test/",
        "clientId":"test-client.access","clientSecret":"cfast_FAKE_not_a_real_secret"}}
        """.utf8)
        let seed = try ProvisionSeed.decode(data)
        let settings = try XCTUnwrap(AwayGatewaySettings.from(seed: seed.gateway))
        let secrets = MemorySecretStore()
        let store = AwayGatewayStore(store: secrets, defaults: defaults)
        store.seedIfNeeded(from: nil)
        XCTAssertNil(store.load())
        store.seedIfNeeded(from: settings)
        XCTAssertEqual(store.load(), settings)
        XCTAssertEqual(store.addressText(), "https://gateway.example.test")
        XCTAssertNotNil(try secrets.load(for: AwayGatewaySettings.account))
        // Another provisioned build must not silently replace the saved token.
        store.seedIfNeeded(from: AwayGatewaySettings(
            url: "https://replacement.example.test", clientID: "other.access", clientSecret: "FAKE_rotated"
        ))
        XCTAssertEqual(store.load(), settings)
        XCTAssertFalse(defaults.dictionaryRepresentation().description.contains(secret))
        XCTAssertFalse(defaults.dictionaryRepresentation().description.contains(settings.clientID))
    }

    func testOnlyGravityGetsTheLongTimeout() async throws {
        let reads = AwayHTTPClient.piholeConfiguration()
        XCTAssertEqual(reads.timeoutIntervalForResource, 30)
        let gravity = AwayHTTPClient.gravityConfiguration(reads)
        XCTAssertEqual(gravity.timeoutIntervalForResource, 310)
        let http = try client()
        _ = try await http.post(try url("https://gateway.example.test/api/action/gravity"), headers: [:], body: nil)
        _ = try await http.get(try url("https://gateway.example.test/api/stats/summary"), headers: [:])
        XCTAssertEqual(GatewayStub.requests.map(\.timeoutInterval), [310, 20])
    }

    func testATypedGatewayIsKept() throws {
        let store = AwayGatewayStore(store: MemorySecretStore(), defaults: defaults)
        XCTAssertEqual(
            store.save(address: "https://typed.example.test", clientID: "typed.access", secret: "cfast_FAKE_typed"),
            .saved
        )
        store.seedIfNeeded(from: try gateway())
        XCTAssertEqual(store.addressText(), "https://typed.example.test")
    }

    func testRemovingASeededGatewaySticks() throws {
        let store = AwayGatewayStore(store: MemorySecretStore(), defaults: defaults)
        store.seedIfNeeded(from: try gateway())
        XCTAssertEqual(store.remove(), .saved)
        store.seedIfNeeded(from: try gateway())
        XCTAssertNil(store.load())
    }

    func testAnEmptyFormKeepsTheSavedCredentials() throws {
        let store = AwayGatewayStore(store: MemorySecretStore(), defaults: defaults)
        XCTAssertEqual(store.save(address: "https://a.example.test", clientID: "", secret: ""), .missingCredentials)
        store.seedIfNeeded(from: try gateway())
        XCTAssertEqual(store.save(address: "https://b.example.test", clientID: "", secret: ""), .saved)
        XCTAssertEqual(store.load()?.clientSecret, secret)
        XCTAssertEqual(store.save(address: "http://b.example.test", clientID: "", secret: ""), .badAddress)
    }

    func testTheKeyStampMovesOnlyWhenTheKeyChanges() throws {
        let store = AwayGatewayStore(store: MemorySecretStore(), defaults: defaults)
        XCTAssertEqual(store.stamp, 0)
        XCTAssertEqual(
            store.save(address: "http://gateway.example.test", clientID: "one.access", secret: secret),
            .badAddress
        )
        XCTAssertEqual(store.stamp, 0)
        XCTAssertEqual(
            store.save(address: "https://gateway.example.test", clientID: "one.access", secret: secret),
            .saved
        )
        XCTAssertEqual(store.stamp, 1)
        XCTAssertEqual(store.save(address: "https://gateway.example.test:8443", clientID: "", secret: ""), .saved)
        XCTAssertEqual(store.stamp, 1)
        XCTAssertEqual(store.load()?.clientID, "one.access")
        XCTAssertEqual(
            store.save(address: "https://gateway.example.test:8443", clientID: "two.access", secret: secret),
            .saved
        )
        XCTAssertEqual(store.stamp, 2)
        XCTAssertEqual(store.remove(), .saved)
        XCTAssertEqual(store.stamp, 3)
        XCTAssertNil(store.load())
    }

    func testTheSwitchTurnsTheRoadOff() throws {
        let store = AwayGatewayStore(store: MemorySecretStore(), defaults: defaults)
        store.seedIfNeeded(from: try gateway())
        XCTAssertTrue(store.enabled)
        XCTAssertNotNil(store.active())
        store.setEnabled(false)
        XCTAssertNil(store.active())
        XCTAssertNotNil(store.load())
    }
}
