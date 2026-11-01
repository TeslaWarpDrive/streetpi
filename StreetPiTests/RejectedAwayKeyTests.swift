import Foundation
import StreetPiCore
import XCTest
@testable import StreetPi

@MainActor
final class RejectedAwayKeyTests: XCTestCase {
    private func gateway() throws -> AwayGatewaySettings {
        try XCTUnwrap(AwayGatewaySettings(
            url: "https://gateway.example.test", clientID: "FAKE_client.access",
            clientSecret: "cfast_FAKE_not_a_real_secret"
        ))
    }

    private func mailbox() throws -> MailboxSetup {
        MailboxSetup(
            address: try XCTUnwrap(MailboxAddress(text: "https://mailbox.example.test")),
            token: try XCTUnwrap(MailboxToken(text: "FAKE_mailbox_token"))
        )
    }

    func testHealthForbiddenShowsRejectionWithAndWithoutMailbox() async throws {
        for mailbox in [nil, try mailbox()] {
            let root = RootView(now: .streetFixtureNow)
            let mode = await root.probeRoad(
                gateway: try gateway(), mailbox: mailbox,
                home: { PiProbe.Reading(mode: .offline) },
                gatewayReply: { await GatewayProbe().reply($0, http: ProbeReply(status: 403)) }
            )
            XCTAssertEqual(mode, mailbox.map(ConnectionMode.awayMailbox) ?? .offline)
            XCTAssertTrue(root.awayKeyRejected)
            XCTAssertEqual(AwayKeyNotice.message, "Away key was rejected – replace it in Settings")
        }
    }

    func testNoAnswerKeepsOfflineAndMailboxWithoutRejection() async throws {
        for mailbox in [nil, try mailbox()] {
            let root = RootView(now: .streetFixtureNow)
            root.certificateRecovery.gatewayReply = .rejectedKey
            let mode = await root.probeRoad(
                gateway: try gateway(), mailbox: mailbox,
                home: { PiProbe.Reading(mode: .offline) },
                gatewayReply: { await GatewayProbe().reply($0, http: ProbeReply(status: nil)) }
            )
            XCTAssertEqual(mode, mailbox.map(ConnectionMode.awayMailbox) ?? .offline)
            XCTAssertFalse(root.awayKeyRejected)
        }
    }

    func testHomeSkipsGatewayAndClearsOldRejection() async throws {
        let root = RootView(now: .streetFixtureNow)
        root.certificateRecovery.gatewayReply = .rejectedKey
        let mode = await root.probeRoad(
            gateway: try gateway(), mailbox: try mailbox(),
            home: { PiProbe.Reading(mode: .home) },
            gatewayReply: { _ in
                XCTFail("Home must not probe the gateway")
                return .rejectedKey
            }
        )
        XCTAssertEqual(mode, .home)
        XCTAssertFalse(root.awayKeyRejected)
    }

    func testOnlyHealth200AnswersAndOnly403RejectsKey() async throws {
        for status in [200, 302, 401, 403, 404, 503] {
            let reply = await GatewayProbe().reply(try gateway(), http: ProbeReply(status: status))
            XCTAssertEqual(reply, status == 200 ? .answered : status == 403 ? .rejectedKey : .noAnswer)
        }
    }

    func testForbiddenDuringAwayRefreshReachesTheNotice() async throws {
        let gateway = try gateway()
        let root = RootView(now: .streetFixtureNow, mode: .awayLive(gateway))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RejectedKeyHTTPStub.self]
        let http = AwayHTTPClient(settings: gateway, configuration: configuration)
        root.certificateRecovery.awayHTTP = http
        let client = PiholeClient(
            transport: AwayPiholeTransport(base: LivePiholeTransport(
                http: http, base: try XCTUnwrap(gateway.piholeBase)
            )),
            password: { "FAKE_password" }
        )
        _ = await root.refresh(client, now: .streetFixtureNow)
        XCTAssertTrue(root.awayKeyRejected)
        XCTAssertEqual(root.certificateRecovery.gatewayReply, .rejectedKey)
    }

    func testHomeRefreshForbiddenDoesNotClaimAwayKeyWasRejected() async {
        let root = RootView(now: .streetFixtureNow, mode: .home)
        let client = PiholeClient(
            transport: ScriptedPiholeTransport(steps: [.json(403, "{}")]),
            password: { "FAKE_password" }
        )
        let board = await root.refresh(client, now: .streetFixtureNow)
        XCTAssertEqual(board.problem, .notSetUp)
        XCTAssertFalse(root.awayKeyRejected)
    }
}

private struct ProbeReply: LiveHTTPSending {
    var status: Int?

    func get(_ url: URL, headers: [String: String]) async throws -> LiveHTTPResponse {
        guard let status else { throw LiveHTTPProblem.unreachable }
        return LiveHTTPResponse(status: status, headers: [:], body: Data())
    }

    func post(_ url: URL, headers: [String: String], body: Data?) async throws -> LiveHTTPResponse {
        throw LiveHTTPProblem.unreachable
    }

    func delete(_ url: URL, headers: [String: String]) async throws -> LiveHTTPResponse {
        throw LiveHTTPProblem.unreachable
    }
}

private final class RejectedKeyHTTPStub: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 403, httpVersion: nil, headerFields: nil)
        else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}
