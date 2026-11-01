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
}
