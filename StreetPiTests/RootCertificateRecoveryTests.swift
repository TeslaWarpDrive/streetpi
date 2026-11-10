import Foundation
import StreetPiCore
import XCTest
@testable import StreetPi

@MainActor
final class RootCertificateRecoveryTests: XCTestCase {
    private let fakePin = Data(repeating: 0xFA, count: 32).base64EncodedString()

    private func gateway() throws -> AwayGatewaySettings {
        try XCTUnwrap(AwayGatewaySettings(
            url: "https://gateway.example.test",
            clientID: "FAKE_client.access",
            clientSecret: "cfast_FAKE_not_a_real_secret"
        ))
    }

    private func fallbackRoads() throws -> [ConnectionMode] {
        let mailbox = MailboxSetup(
            address: try XCTUnwrap(MailboxAddress(text: "https://mailbox.example.test")),
            token: try XCTUnwrap(MailboxToken(text: "FAKE_mailbox_token"))
        )
        return [.awayLive(try gateway()), .awayMailbox(mailbox)]
    }

    func testFallbackRoadKeepsItsDeskAfterDecliningCertificate() throws {
        for mode in try fallbackRoads() {
            let root = RootView(now: .streetFixtureNow, mode: mode)
            root.certificateRecovery.reading = PiProbe.Reading(mode: mode, presentedPin: fakePin)
            root.certificateRecovery.dnsProblem = .pinKept
            XCTAssertEqual(root.displayedDNSProblem, .certificateChanged)

            root.keepSavedPin()

            XCTAssertNil(root.displayedDNSProblem)
            XCTAssertNil(root.certificateRecovery.dnsProblem)
            XCTAssertEqual(root.certificateRecovery.declinedPin, fakePin)
            // Mode and desk are @State. Outside a view tree those reads stay at the
            // initial value, so comparing them cannot fail. The desk stays up when
            // this road's reading has no problem. The same pin at home still covers it.
            let later = PiProbe.Reading(mode: mode, presentedPin: fakePin)
            XCTAssertNil(later.problem(declinedPin: root.certificateRecovery.declinedPin))
            XCTAssertEqual(
                PiProbe.Reading(mode: .home, presentedPin: fakePin)
                    .problem(declinedPin: root.certificateRecovery.declinedPin),
                .pinKept
            )
            root.certificateRecovery.reading = later
            XCTAssertNil(root.displayedDNSProblem)
        }
    }

    /// Keep clears the wall. The next poll still reports that certificate, and away live
    /// must leave the prompt down the way the mailbox road already leaves its desk up.
    func testKeepOnAwayLiveLeavesThePromptDownAfterOnePoll() async throws {
        let mode = ConnectionMode.awayLive(try gateway())
        let root = RootView(now: .streetFixtureNow, mode: mode)
        root.certificateRecovery.reading = PiProbe.Reading(mode: mode, presentedPin: fakePin)
        root.certificateRecovery.dnsProblem = .certificateChanged
        XCTAssertEqual(root.displayedDNSProblem, .certificateChanged)

        root.keepSavedPin()

        XCTAssertNil(root.displayedDNSProblem)
        XCTAssertNil(root.certificateRecovery.dnsProblem)
        XCTAssertEqual(root.certificateRecovery.declinedPin, fakePin)

        try await assertKeptPromptStaysDown(root, presented: fakePin, stored: .pinKept)
        try await assertKeptPromptStaysDown(root, presented: nil, stored: .certificateChanged)

        let other = Data(repeating: 0xFB, count: 32).base64EncodedString()
        root.dnsSession.presented = presentedPin(other)
        let board = await root.refresh(
            changedCertificate(), now: .streetFixtureNow, secrets: MemorySecretStore()
        )
        XCTAssertEqual(board.problem, .certificateChanged)
        root.apply(board)
        XCTAssertEqual(root.displayedDNSProblem, .certificateChanged)
        XCTAssertEqual(root.certificateRecovery.dnsProblem, .certificateChanged)
    }

    func testHomePollStillShowsTheKeptPin() async throws {
        let root = RootView(now: .streetFixtureNow)
        root.certificateRecovery.reading = PiProbe.Reading(mode: .home, presentedPin: fakePin)
        root.certificateRecovery.declinedPin = fakePin
        root.dnsSession.presented = presentedPin(fakePin)
        let board = await root.refresh(
            changedCertificate(), now: .streetFixtureNow, secrets: MemorySecretStore()
        )
        XCTAssertEqual(board.problem, .pinKept)
        root.apply(board)
        XCTAssertEqual(root.certificateRecovery.dnsProblem, .pinKept)
        XCTAssertEqual(root.displayedDNSProblem, .pinKept)
    }

    /// Keep remembers the pin. The next poll can fail as "this phone does not trust the Pi yet."
    /// That failure still comes back from the read, and applying it must leave the pin and the desk.
    /// `desk` is @State, so outside a view tree the read stays at the initial value. `apply` writes
    /// the problem in the same step as the desk, and that problem is what these checks hold still.
    func testKeepLeavesTheDeskWhenThePhoneDoesNotTrustThePi() async throws {
        for mode in try fallbackRoads() {
            let root = RootView(now: .streetFixtureNow, mode: mode)
            root.certificateRecovery.reading = PiProbe.Reading(mode: mode, presentedPin: fakePin)
            root.certificateRecovery.dnsProblem = .certificateChanged
            root.keepSavedPin()
            XCTAssertEqual(root.certificateRecovery.declinedPin, fakePin)
            XCTAssertNil(root.certificateRecovery.dnsProblem)

            let board = await root.refresh(
                untrustedPi(), now: .streetFixtureNow, secrets: MemorySecretStore()
            )
            XCTAssertEqual(board.problem, .untrusted)
            XCTAssertEqual(board.desk.spokenLine, PiholeProblem.untrusted.title)
            root.apply(board)
            XCTAssertNil(root.certificateRecovery.dnsProblem)
            XCTAssertNil(root.displayedDNSProblem)
            XCTAssertEqual(root.certificateRecovery.declinedPin, fakePin)
        }
    }

    func testHomeKeepLeavesThePinWhenThePhoneDoesNotTrustThePi() async throws {
        let root = RootView(now: .streetFixtureNow)
        root.certificateRecovery.reading = PiProbe.Reading(mode: .home, presentedPin: fakePin)
        root.keepSavedPin()
        XCTAssertEqual(root.certificateRecovery.dnsProblem, .pinKept)
        XCTAssertEqual(root.displayedDNSProblem, .pinKept)

        let board = await root.refresh(
            untrustedPi(), now: .streetFixtureNow, secrets: MemorySecretStore()
        )
        XCTAssertEqual(board.problem, .untrusted)
        root.apply(board)
        XCTAssertEqual(root.certificateRecovery.dnsProblem, .pinKept)
        XCTAssertEqual(root.displayedDNSProblem, .pinKept)
        XCTAssertEqual(root.certificateRecovery.declinedPin, fakePin)
    }

    func testUntrustedPollStillShowsBeforeKeep() async throws {
        let root = RootView(now: .streetFixtureNow, mode: .awayLive(try gateway()))
        let board = await root.refresh(
            untrustedPi(), now: .streetFixtureNow, secrets: MemorySecretStore()
        )
        XCTAssertEqual(board.problem, .untrusted)
        root.apply(board)
        XCTAssertEqual(root.certificateRecovery.dnsProblem, .untrusted)
        XCTAssertEqual(root.displayedDNSProblem, .untrusted)
        XCTAssertNil(root.certificateRecovery.declinedPin)
    }

    func testDeclinePreservesAnUnrelatedGatewayProblem() throws {
        let mode = ConnectionMode.awayLive(try gateway())
        let root = RootView(now: .streetFixtureNow, mode: mode)
        root.certificateRecovery.reading = PiProbe.Reading(mode: mode, presentedPin: fakePin)
        root.certificateRecovery.dnsProblem = .offline

        root.keepSavedPin()

        XCTAssertEqual(root.displayedDNSProblem, .offline)
        XCTAssertEqual(root.certificateRecovery.dnsProblem, .offline)
    }

    func testKeepingThePinAtHomeStillShowsPinKept() {
        let root = RootView(now: .streetFixtureNow)
        root.certificateRecovery.reading = PiProbe.Reading(mode: .home, presentedPin: fakePin)
        root.keepSavedPin()
        XCTAssertEqual(root.displayedDNSProblem, .pinKept)
    }

    func testTrustSavesPinAndNextProbeReturnsHomeInsideDwell() async throws {
        let suite = "RootCertificateRecoveryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let hosts = LiveHostStore(defaults: defaults)
        let now = Date.streetFixtureNow
        for mode in try fallbackRoads() {
            let root = RootView(now: now, mode: mode)
            root.certificateRecovery.reading = PiProbe.Reading(mode: mode, presentedPin: fakePin)
            root.certificateRecovery.declinedPin = fakePin
            root.certificateRecovery.trigger = .foreground
            let retry = root.certificateRecovery.retry
            var dwell = ConnectionDwell()
            _ = dwell.settle(mode, trigger: .launch, now: now)

            root.trustPresentedPin(hosts: hosts)

            XCTAssertEqual(hosts.loadPin(), fakePin)
            XCTAssertEqual(root.liveClient.pinner.trustedPin(), fakePin)
            XCTAssertNil(root.certificateRecovery.reading.presentedPin)
            XCTAssertNil(root.certificateRecovery.declinedPin)
            XCTAssertEqual(root.certificateRecovery.retry, retry + 1)
            XCTAssertEqual(root.certificateRecovery.trigger, .settingsChanged)
            let transport = ScriptedPiholeTransport(steps: [.json(401, "{}")])
            let probed = await root.probeMode {
                await PiProbe.connection(
                    transport: transport, presented: PresentedPinBox(), gateway: nil, mailbox: nil,
                    gatewayAnswers: { _ in
                        XCTFail("A pinned home reply must not contact the gateway")
                        return false
                    }
                )
            }
            XCTAssertEqual(
                dwell.settle(try XCTUnwrap(probed), trigger: root.certificateRecovery.trigger,
                             now: now.addingTimeInterval(1)),
                .home
            )
            XCTAssertNil(root.displayedDNSProblem)
        }
    }

    func testProbeStartedBeforeTrustCannotRestorePrompt() async throws {
        let suite = "RootCertificateRecoveryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let mode = ConnectionMode.awayLive(try gateway())
        let root = RootView(now: .streetFixtureNow, mode: mode)
        let stale = PiProbe.Reading(mode: mode, presentedPin: fakePin)
        root.certificateRecovery.reading = stale
        let pending = PendingCertificateProbe()
        let probe = Task { await root.probeMode { await pending.reading() } }
        await pending.waitUntilStarted()

        root.trustPresentedPin(hosts: LiveHostStore(defaults: defaults))
        await pending.finish(with: stale)
        let returned = await probe.value

        XCTAssertNil(returned)
        XCTAssertNil(root.certificateRecovery.reading.presentedPin)
        XCTAssertNil(root.displayedDNSProblem)
        XCTAssertEqual(root.certificateRecovery.trigger, .settingsChanged)
    }
}

extension RootCertificateRecoveryTests {
    private func changedCertificate() -> PiholeClient {
        PiholeClient(
            transport: ScriptedPiholeTransport(steps: [.fail(.certificateChanged)]),
            password: { "FAKE_password" }
        )
    }

    private func untrustedPi() -> PiholeClient {
        PiholeClient(
            transport: ScriptedPiholeTransport(steps: [.fail(.untrusted)]),
            password: { "FAKE_password" }
        )
    }

    private func presentedPin(_ pin: String) -> PresentedPinBox {
        let box = PresentedPinBox()
        box.record(pin)
        return box
    }

    private func assertKeptPromptStaysDown(
        _ root: RootView, presented: String?, stored: PiholeProblem
    ) async throws {
        if let presented {
            root.dnsSession.presented = self.presentedPin(presented)
        } else {
            root.dnsSession.presented = nil
        }
        let board = await root.refresh(
            changedCertificate(), now: .streetFixtureNow, secrets: MemorySecretStore()
        )
        XCTAssertEqual(board.problem, stored)
        root.apply(board)
        XCTAssertNil(root.displayedDNSProblem)
        XCTAssertNil(root.certificateRecovery.dnsProblem)
        XCTAssertEqual(root.certificateRecovery.declinedPin, fakePin)
    }
}

private actor PendingCertificateProbe {
    private var result: CheckedContinuation<PiProbe.Reading, Never>?
    private var started: CheckedContinuation<Void, Never>?

    func reading() async -> PiProbe.Reading {
        await withCheckedContinuation { continuation in
            result = continuation
            started?.resume()
            started = nil
        }
    }

    func waitUntilStarted() async {
        guard result == nil else { return }
        await withCheckedContinuation { started = $0 }
    }

    func finish(with reading: PiProbe.Reading) {
        result?.resume(returning: reading)
        result = nil
    }
}
