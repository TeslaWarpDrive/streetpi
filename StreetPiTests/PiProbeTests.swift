import Foundation
import StreetPiCore
import XCTest
@testable import StreetPi

final class PiProbeTests: XCTestCase {
    private let fakePin = Data(repeating: 0xFA, count: 32).base64EncodedString()

    private func gateway() throws -> AwayGatewaySettings {
        try XCTUnwrap(AwayGatewaySettings(
            url: "https://gateway.example.test",
            clientID: "FAKE_client.access",
            clientSecret: "cfast_FAKE_not_a_real_secret"
        ))
    }

    private func mailbox() throws -> MailboxSetup {
        MailboxSetup(
            address: try XCTUnwrap(MailboxAddress(text: "https://mailbox.example.test")),
            token: try XCTUnwrap(MailboxToken(text: "FAKE_mailbox_token"))
        )
    }

    func testChangedCertificateKeepsGatewayAndShowsPrompt() async throws {
        let gateway = try gateway()
        let presented = PresentedPinBox()
        presented.record(fakePin)
        let transport = ScriptedPiholeTransport(steps: [.fail(.certificateChanged)])
        let reading = await PiProbe.connection(
            transport: transport, presented: presented, gateway: gateway, mailbox: try mailbox(),
            gatewayAnswers: { _ in true }
        )
        XCTAssertEqual(reading.mode, .awayLive(gateway))
        XCTAssertEqual(reading.presentedPin, fakePin)
        XCTAssertEqual(reading.problem(declinedPin: nil), .certificateChanged)
        XCTAssertNil(reading.problem(declinedPin: fakePin))
        XCTAssertEqual(transport.sent, [PiholeRequest(
            method: "GET", path: "/api/info/login", headers: [:], body: nil
        )])
    }

    func testChangedCertificateKeepsMailboxAndShowsPrompt() async throws {
        let mailbox = try mailbox()
        let presented = PresentedPinBox()
        presented.record(fakePin)
        let reading = await PiProbe.connection(
            transport: ScriptedPiholeTransport(steps: [.fail(.certificateChanged)]),
            presented: presented, gateway: try gateway(), mailbox: mailbox,
            gatewayAnswers: { _ in false }
        )
        XCTAssertEqual(reading.mode, .awayMailbox(mailbox))
        XCTAssertEqual(reading.problem(declinedPin: nil), .certificateChanged)
    }

    func testAcceptedCertificateReturnsHomeOnNextProbe() async throws {
        let transport = ScriptedPiholeTransport(steps: [.json(401, "{}")])
        let reading = await PiProbe.connection(
            transport: transport, presented: PresentedPinBox(), gateway: try gateway(), mailbox: try mailbox(),
            gatewayAnswers: { _ in
                XCTFail("A pinned home reply must not contact the gateway")
                return true
            }
        )
        var dwell = ConnectionDwell()
        let now = Date(timeIntervalSince1970: 1_000_000)
        _ = dwell.settle(.awayLive(try gateway()), trigger: .launch, now: now)
        XCTAssertEqual(dwell.settle(reading.mode, trigger: .settingsChanged, now: now), .home)
        XCTAssertNil(reading.presentedPin)
        XCTAssertNil(reading.problem(declinedPin: nil))
    }

    func testUnreachablePiDoesNotInventACertificatePrompt() async throws {
        let reading = await PiProbe.connection(
            transport: ScriptedPiholeTransport(steps: [.fail(.offline)]),
            presented: PresentedPinBox(), gateway: try gateway(), mailbox: nil,
            gatewayAnswers: { _ in true }
        )
        XCTAssertEqual(reading.mode, .awayLive(try gateway()))
        XCTAssertNil(reading.problem(declinedPin: nil))
    }

    func testAFailedPinDoesNotLetAnotherAnswerCountAsHome() async throws {
        let gateway = try gateway()
        let mailbox = try mailbox()
        let transport = ChartsWouldAnswer()
        let away = await PiProbe.connection(
            transport: transport, presented: PresentedPinBox(), gateway: gateway, mailbox: mailbox,
            gatewayAnswers: { _ in true }
        )
        XCTAssertEqual(away.mode, .awayLive(gateway))
        XCTAssertNil(away.presentedPin)
        XCTAssertEqual(transport.paths, ["/api/info/login"])

        let fallback = ChartsWouldAnswer()
        let mailboxRoad = await PiProbe.connection(
            transport: fallback, presented: PresentedPinBox(), gateway: gateway, mailbox: mailbox,
            gatewayAnswers: { _ in false }
        )
        XCTAssertEqual(mailboxRoad.mode, .awayMailbox(mailbox))
        XCTAssertEqual(fallback.paths, ["/api/info/login"])
    }

    func testClosedReaderKeepsTheMailbox() throws {
        let mailbox = try mailbox()
        let reading = PiProbe.closedReader(gateway: try gateway(), mailbox: mailbox)
        XCTAssertEqual(reading.mode, .awayMailbox(mailbox))
        XCTAssertNil(reading.presentedPin)
    }

    func testClosedReaderWithoutAMailboxStaysOffline() throws {
        XCTAssertEqual(PiProbe.closedReader(gateway: try gateway(), mailbox: nil).mode, .offline)
        XCTAssertEqual(PiProbe.closedReader(gateway: nil, mailbox: nil).mode, .offline)
    }

    func testDevelopmentReaderOffUsesTheClosedReader() async throws {
        try XCTSkipIf(
            LiveReaderGate.opensSockets,
            "An open reader would look at the network. This case is the closed switch."
        )
        let mailbox = try mailbox()
        let reading = await PiProbe().connection(gateway: try gateway(), mailbox: mailbox)
        XCTAssertEqual(reading, PiProbe.closedReader(gateway: try gateway(), mailbox: mailbox))
    }
}

/// The pin login fails. Any other path would answer, and must not count as home.
private final class ChartsWouldAnswer: PiholeTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var seen: [String] = []

    var paths: [String] {
        lock.lock()
        defer { lock.unlock() }
        return seen
    }

    func send(_ request: PiholeRequest) async throws -> PiholeResponse {
        lock.lock()
        seen.append(request.path)
        lock.unlock()
        if request.path == "/api/info/login" { throw PiholeProblem.untrusted }
        return PiholeResponse(status: 200, body: Data("{\"version\":\"fixture\"}".utf8))
    }
}
