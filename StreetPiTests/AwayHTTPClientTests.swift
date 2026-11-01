import StreetPiCore
import XCTest
@testable import StreetPi

/// Fails the gravity POST with a real URLError and answers everything else, so no socket opens.
private final class CutGravityStub: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cut = URLError.Code.networkConnectionLost
    nonisolated(unsafe) private static var summaries: [String] = []

    static func reset(cut code: URLError.Code, summaries replies: [String]) {
        lock.lock()
        cut = code
        summaries = replies
        lock.unlock()
    }

    private static func nextSummary() -> String {
        lock.lock()
        defer { lock.unlock() }
        return summaries.isEmpty ? "{}" : summaries.removeFirst()
    }

    private static var code: URLError.Code {
        lock.lock()
        defer { lock.unlock() }
        return cut
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let url = request.url else { return }
        switch url.path {
        case "/api/action/gravity":
            client?.urlProtocol(self, didFailWithError: URLError(Self.code))
        case "/api/auth":
            reply("{\"session\":{\"sid\":\"fixture-not-a-real-session\",\"validity\":1800}}", url: url)
        default:
            reply(Self.nextSummary(), url: url)
        }
    }

    private func reply(_ text: String, url: URL) {
        guard let response = HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil
        ) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(text.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

final class AwayHTTPClientTests: XCTestCase {
    private func summary(_ stamp: Int, _ domains: Int) -> String {
        "{\"gravity\":{\"last_update\":\(stamp),\"domains_being_blocked\":\(domains)}}"
    }

    private func flow() throws -> AwayGravityFlow {
        let gateway = try XCTUnwrap(AwayGatewaySettings(
            url: "https://gateway.example.test",
            clientID: "test-client.access",
            clientSecret: "cfast_FAKE_not_a_real_secret"
        ))
        let configuration = LiveHTTPClient.sessionConfiguration()
        configuration.protocolClasses = [CutGravityStub.self]
        let http = AwayHTTPClient(settings: gateway, configuration: configuration)
        let base = try XCTUnwrap(gateway.piholeBase)
        let client = PiholeClient(
            transport: AwayPiholeTransport(base: LivePiholeTransport(http: http, base: base)),
            password: { "fixture-password" }
        )
        return AwayGravityFlow(client: client, sleep: { _ in }, onStep: { _ in })
    }

    func testACutGravityRequestChecksBack() async throws {
        for code in [URLError.Code.networkConnectionLost, .secureConnectionFailed] {
            CutGravityStub.reset(cut: code, summaries: [summary(100, 5), summary(200, 7)])
            let receipt = try await flow().run()
            XCTAssertEqual(receipt.title, "Block lists updated.", "\(code)")
            XCTAssertTrue(receipt.detail.contains("7"), "\(code)")
            XCTAssertNotNil(receipt.listsUpdatedAt, "\(code)")
        }
    }
}
