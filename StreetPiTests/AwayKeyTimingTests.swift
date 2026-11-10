import Foundation
import StreetPiCore
import SwiftUI
import XCTest
@testable import StreetPi

/// A refused key has to survive until refresh, including one that arrived on Netdata or Kuma.
@MainActor
final class AwayKeyTimingTests: XCTestCase {
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

    private func answeredClient() -> PiholeClient {
        PiholeClient(
            transport: ScriptedPiholeTransport(steps: [.json(200, #"{"dns":true}"#)]),
            password: { "" }
        )
    }

    func testA403ThatArrivedBeforeRefreshStillRaisesTheNotice() async throws {
        let gateway = try gateway()
        let root = RootView(now: .streetFixtureNow, mode: .awayLive(gateway))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RejectedKeyHTTPStub.self]
        let http = AwayHTTPClient(settings: gateway, configuration: configuration)
        root.certificateRecovery.awayHTTP = http
        let health = try XCTUnwrap(gateway.healthURL)
        let response = try await http.get(health, headers: [:])
        XCTAssertEqual(response.status, 403)

        let board = await root.refresh(answeredClient(), now: .streetFixtureNow, secrets: MemorySecretStore())
        XCTAssertEqual(board.problem, .offline)
        assertNoticeShows(root)
    }

    func testAPiholeForbiddenBeforeRefreshDoesNotBecomeTheKey() async throws {
        let gateway = try gateway()
        let root = RootView(now: .streetFixtureNow, mode: .awayLive(gateway))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RejectedKeyHTTPStub.self]
        let http = AwayHTTPClient(settings: gateway, configuration: configuration)
        root.certificateRecovery.awayHTTP = http
        let summary = try XCTUnwrap(URL(string: "https://gateway.example.test/api/stats/summary"))
        let response = try await http.get(summary, headers: [:])
        XCTAssertEqual(response.status, 403)

        let board = await root.refresh(answeredClient(), now: .streetFixtureNow, secrets: MemorySecretStore())
        XCTAssertEqual(board.problem, .notSetUp)
        assertNoticeHidden(root)
    }

    func testANetdataOrKuma403BeforeRefreshRaisesTheNotice() async throws {
        let gateway = try gateway()
        let latch = AwayKeyLatch()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RejectedKeyHTTPStub.self]
        let meters = AwayHTTPClient(settings: gateway, configuration: configuration, rejection: latch)
        for path in ["/netdata/api/v1/info", "/kuma/api/status-page/house"] {
            let root = RootView(now: .streetFixtureNow, mode: .awayLive(gateway))
            let http = AwayHTTPClient(settings: gateway, configuration: .ephemeral, rejection: latch)
            root.certificateRecovery.awayHTTP = http
            let url = try XCTUnwrap(URL(string: "https://gateway.example.test" + path))
            let response = try await meters.get(url, headers: [:])
            XCTAssertEqual(response.status, 403, path)
            let board = await root.refresh(answeredClient(), now: .streetFixtureNow, secrets: MemorySecretStore())
            XCTAssertEqual(board.problem, .offline, path)
            assertNoticeShows(root)
        }
    }

    func testALaterPihole200KeepsTheLiveRoadWhenHealthForbids() async throws {
        let gateway = try gateway()
        for mailbox in [nil, try mailbox()] {
            let root = RootView(now: .streetFixtureNow)
            let mode = await root.probeRoad(
                gateway: gateway, mailbox: mailbox,
                home: { PiProbe.Reading(mode: .offline) },
                gatewayReply: { await GatewayProbe().reply($0, http: SplitProbe(health: 403, login: 200)) }
            )
            XCTAssertEqual(mode, .awayLive(gateway))
            assertNoticeHidden(root)
        }
    }

    func testAHealth200DoesNotKeepTheLiveRoadWhenPiholeDoesNotAnswer() async throws {
        let gateway = try gateway()
        let mailbox = try mailbox()
        let root = RootView(now: .streetFixtureNow)
        let mode = await root.probeRoad(
            gateway: gateway, mailbox: mailbox,
            home: { PiProbe.Reading(mode: .offline) },
            gatewayReply: { await GatewayProbe().reply($0, http: SplitProbe(health: 200, login: nil)) }
        )
        XCTAssertEqual(mode, .awayMailbox(mailbox))
        assertNoticeHidden(root)
    }

    func testALaterPihole403LeavesTheLiveRoadAndShowsTheNotice() async throws {
        let gateway = try gateway()
        let mailbox = try mailbox()
        let root = RootView(now: .streetFixtureNow)
        let mode = await root.probeRoad(
            gateway: gateway, mailbox: mailbox,
            home: { PiProbe.Reading(mode: .offline) },
            gatewayReply: { await GatewayProbe().reply($0, http: SplitProbe(health: 200, login: 403)) }
        )
        XCTAssertEqual(mode, .awayMailbox(mailbox))
        assertNoticeShows(root)
    }

    private func assertNoticeShows(_ root: RootView, line: UInt = #line) {
        let message = "Away key was rejected – replace it in Settings"
        XCTAssertEqual(
            AwayKeyNotice(rejected: root.awayKeyRejected, section: .settings).text, message, line: line
        )
    }

    private func assertNoticeHidden(_ root: RootView, line: UInt = #line) {
        XCTAssertNil(AwayKeyNotice(rejected: root.awayKeyRejected, section: .settings).text, line: line)
    }
}

/// Health and the login probe can return different statuses. The login probe is the later call.
private struct SplitProbe: LiveHTTPSending {
    var health: Int?
    var login: Int?

    func get(_ url: URL, headers: [String: String]) async throws -> LiveHTTPResponse {
        let status = url.path == "/api/info/login" ? login : health
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
