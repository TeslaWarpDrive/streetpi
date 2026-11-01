import Foundation
import XCTest
@testable import StreetPiCore

final class ConnectionModeTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func gateway() throws -> AwayGatewaySettings {
        try XCTUnwrap(AwayGatewaySettings(
            url: "https://gateway.example.test",
            clientID: "test-client.access",
            clientSecret: "cfast_FAKE_not_a_real_secret"
        ))
    }

    private func mailbox() throws -> MailboxSetup {
        MailboxSetup(
            address: try XCTUnwrap(MailboxAddress(text: "https://mailbox.example.test")),
            token: try XCTUnwrap(MailboxToken(text: "fixture-not-a-real-read-token"))
        )
    }

    func testDecisionTable() throws {
        let gateway = try gateway()
        let mailbox = try mailbox()
        let rows: [(Bool, AwayGatewaySettings?, Bool, MailboxSetup?, ConnectionMode)] = [
            (true, gateway, true, mailbox, .home),
            (true, nil, false, nil, .home),
            (false, gateway, true, mailbox, .awayLive(gateway)),
            (false, gateway, true, nil, .awayLive(gateway)),
            (false, gateway, false, mailbox, .awayMailbox(mailbox)),
            (false, nil, false, mailbox, .awayMailbox(mailbox)),
            (false, nil, true, mailbox, .awayMailbox(mailbox)),
            (false, gateway, false, nil, .offline),
            (false, nil, false, nil, .offline),
        ]
        for (pi, saved, answered, box, expected) in rows {
            let mode = ConnectionMode.choose(
                piAnswered: pi,
                gateway: saved,
                gatewayAnswered: answered,
                mailbox: box
            )
            XCTAssertEqual(mode, expected)
        }
    }

    func testTheGatewayIsNotDialedAtHome() async throws {
        let dialed = Flag()
        let prober = ConnectionProber(
            piAnswers: { true },
            gatewayAnswers: { _ in
                dialed.raise()
                return true
            }
        )
        let mode = await prober.mode(gateway: try gateway(), mailbox: nil)
        XCTAssertEqual(mode, .home)
        XCTAssertFalse(dialed.raised)
    }

    func testTheGatewayIsTriedBeforeTheMailbox() async throws {
        let gateway = try gateway()
        let live = ConnectionProber(piAnswers: { false }, gatewayAnswers: { _ in true })
        let liveMode = await live.mode(gateway: gateway, mailbox: try mailbox())
        XCTAssertEqual(liveMode, .awayLive(gateway))
        let quiet = ConnectionProber(piAnswers: { false }, gatewayAnswers: { _ in false })
        let quietMode = await quiet.mode(gateway: gateway, mailbox: try mailbox())
        XCTAssertEqual(quietMode, .awayMailbox(try mailbox()))
    }

    func testTheFirstAnswerIsNeverHeld() {
        var dwell = ConnectionDwell()
        XCTAssertEqual(dwell.settle(.offline, trigger: .launch, now: start), .offline)
    }

    func testAChangeWaitsOutTheDwell() throws {
        var dwell = ConnectionDwell()
        _ = dwell.settle(.home, trigger: .launch, now: start)
        let away = ConnectionMode.awayLive(try gateway())
        XCTAssertEqual(dwell.settle(away, trigger: .foreground, now: start.addingTimeInterval(9)), .home)
        XCTAssertEqual(dwell.secondsLeft(now: start.addingTimeInterval(9)), 1)
        XCTAssertEqual(dwell.settle(away, trigger: .requestFailed, now: start.addingTimeInterval(10)), away)
    }

    func testANewNetworkSkipsTheDwell() throws {
        var dwell = ConnectionDwell()
        _ = dwell.settle(.home, trigger: .launch, now: start)
        let away = ConnectionMode.awayLive(try gateway())
        XCTAssertEqual(dwell.settle(away, trigger: .pathChanged, now: start.addingTimeInterval(1)), away)
        XCTAssertEqual(dwell.settle(.home, trigger: .manual, now: start.addingTimeInterval(2)), .home)
    }

    func testOneReprobeUntilARequestWorks() {
        var dwell = ConnectionDwell()
        _ = dwell.settle(.home, trigger: .launch, now: start)
        XCTAssertTrue(dwell.wantsReprobe())
        XCTAssertFalse(dwell.wantsReprobe())
        dwell.requestSucceeded()
        XCTAssertTrue(dwell.wantsReprobe())
    }

    func testOfflineKeepsLooking() {
        var dwell = ConnectionDwell()
        _ = dwell.settle(.offline, trigger: .launch, now: start)
        XCTAssertTrue(dwell.wantsReprobe())
        XCTAssertTrue(dwell.wantsReprobe())
    }

    func testOnlyTheMailboxHoldsActionsBack() throws {
        let pause = HouseholdAction.pauseAdBlocking(try XCTUnwrap(PauseLength(seconds: 30)))
        XCTAssertTrue(ConnectionMode.home.allows(pause))
        XCTAssertTrue(ConnectionMode.offline.allows(pause))
        XCTAssertTrue(ConnectionMode.awayLive(try gateway()).allows(pause))
        XCTAssertFalse(ConnectionMode.awayMailbox(try mailbox()).allows(pause))
        XCTAssertTrue(ConnectionMode.awayMailbox(try mailbox()).allows(.refresh))
    }

    func testFaceIDStaysOnPauseAndGravity() throws {
        let pause = HouseholdAction.pauseAdBlocking(try XCTUnwrap(PauseLength(seconds: 30)))
        XCTAssertTrue(ActionPolicy.confirmation(for: pause).requiresFaceID)
        XCTAssertTrue(ActionPolicy.confirmation(for: .resumeAdBlocking).requiresFaceID)
        XCTAssertTrue(ActionPolicy.confirmation(for: .updateBlockLists).requiresFaceID)
    }
}

private final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var raised: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func raise() {
        lock.lock()
        value = true
        lock.unlock()
    }
}
