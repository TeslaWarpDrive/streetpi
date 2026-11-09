import Foundation
import XCTest
@testable import StreetPiCore

final class AdBlockerAccessTests: XCTestCase {
    private let pin = Data(repeating: 0xFA, count: 32).base64EncodedString()
    private let other = Data(repeating: 0xFB, count: 32).base64EncodedString()

    /// A pin from the home probe must not cover a later clear away-live read.
    func testClearAwayLiveReadIsNotCoveredByTheHomeProbePin() throws {
        let away = try awayLive()
        let start = state(road: away, probePin: pin)
        let next = start.reduce(.boardReported(problem: nil, readPin: nil))
        XCTAssertEqual(next, state(road: away, probePin: pin, homeProbeYields: true))
        XCTAssertNil(next.displayedDNSProblem)
        XCTAssertEqual(next.phase, .ready)
        XCTAssertEqual(next.probePin, pin)
        XCTAssertNil(next.readPin)
        XCTAssertTrue(next.homeProbeYields)
        let home = next.reduce(.roadChanged(.home))
        XCTAssertEqual(home.displayedDNSProblem, .certificateChanged)
        XCTAssertEqual(home.phase, .certificateChanged(pin))
    }

    /// Sign-out still says this phone will ask again, and the watch and refresh do ask.
    func testSignOutAsksAgain() {
        let next = state().reduce(.signOut)
        XCTAssertEqual(next, state(signedOut: true, dnsProblem: .needsSignIn))
        XCTAssertTrue(next.signedOut)
        XCTAssertEqual(next.displayedDNSProblem, .needsSignIn)
        XCTAssertEqual(next.phase, .signedOut)
        XCTAssertNil(next.probePin)
        XCTAssertNil(next.readPin)
        XCTAssertFalse(next.watchRefuses)
        XCTAssertFalse(next.refreshRefuses)
    }

    func testPasswordAndSettingsLeaveTheCertificatePageAlone() throws {
        let fresh = AdBlockerAccess()
        check(
            "a fresh phone has no password",
            fresh, .roadChanged(.home), fresh,
            phase: .noPassword, displayed: nil
        )
        check(
            "saving the password opens a ready phone",
            fresh, .passwordSaved, state(),
            phase: .ready, displayed: nil
        )
        check(
            "settings save clears sign-out and leaves the problem",
            state(signedOut: true, dnsProblem: .needsSignIn),
            .settingsSaved,
            state(dnsProblem: .needsSignIn),
            phase: .blocked(.needsSignIn), displayed: .needsSignIn
        )
        check(
            "saving the password also clears sign-out",
            state(passwordSaved: false, signedOut: true, dnsProblem: .needsSignIn),
            .passwordSaved,
            state(dnsProblem: .needsSignIn),
            phase: .blocked(.needsSignIn), displayed: .needsSignIn
        )
        check(
            "sign-out keeps a probe pin on screen",
            state(road: try awayLive(), probePin: pin),
            .signOut,
            state(road: try awayLive(), signedOut: true, probePin: pin, dnsProblem: .needsSignIn),
            phase: .certificateChanged(pin), displayed: .certificateChanged
        )
    }

    func testProbeKeepAndTrust() throws {
        let away = try awayLive()
        let mailbox = try mailboxRoad()
        check(
            "a probe pin covers the home road",
            state(), .probePresented(pin: pin), state(probePin: pin),
            phase: .certificateChanged(pin), displayed: .certificateChanged
        )
        check(
            "a probe with no pin clears the old one",
            state(road: away, probePin: pin, homeProbeYields: true),
            .probePresented(pin: nil),
            state(road: away),
            phase: .ready, displayed: nil
        )
        check(
            "keeping the pin at home shows pin kept",
            state(probePin: pin, readPin: other),
            .keptPin,
            state(probePin: pin, declinedPin: pin, dnsProblem: .pinKept),
            phase: .pinKept, displayed: .pinKept
        )
        check(
            "keeping the pin while offline shows pin kept",
            state(road: .offline, probePin: pin),
            .keptPin,
            state(road: .offline, probePin: pin, declinedPin: pin, dnsProblem: .pinKept),
            phase: .pinKept, displayed: .pinKept
        )
        check(
            "keeping the pin on the away-live road clears a pin problem",
            state(road: away, probePin: pin, dnsProblem: .pinKept),
            .keptPin,
            state(road: away, probePin: pin, declinedPin: pin),
            phase: .ready, displayed: nil
        )
        check(
            "keeping the pin on the away-live road leaves an offline problem",
            state(road: away, probePin: pin, dnsProblem: .offline),
            .keptPin,
            state(road: away, probePin: pin, declinedPin: pin, dnsProblem: .offline),
            phase: .blocked(.offline), displayed: .offline
        )
        check(
            "keeping the pin on the mailbox road clears a certificate problem",
            state(road: mailbox, probePin: pin, dnsProblem: .certificateChanged),
            .keptPin,
            state(road: mailbox, probePin: pin, declinedPin: pin),
            phase: .ready, displayed: nil
        )
        check(
            "trust clears both pins and the latch, and leaves the board problem",
            state(
                signedOut: true, probePin: pin, readPin: other, declinedPin: pin,
                dnsProblem: .certificateChanged, homeProbeYields: true
            ),
            .trustedPin,
            state(dnsProblem: .certificateChanged),
            phase: .certificateChanged(""), displayed: .certificateChanged
        )
    }

    func testBoardReadsStayPutAtHomeAndOffline() throws {
        let away = try awayLive()
        check(
            "a clear read at home does not lift the probe pin",
            state(probePin: pin),
            .boardReported(problem: nil, readPin: nil),
            state(probePin: pin),
            phase: .certificateChanged(pin), displayed: .certificateChanged
        )
        check(
            "a clear read while offline does not lift the probe pin",
            state(road: .offline, probePin: pin),
            .boardReported(problem: nil, readPin: nil),
            state(road: .offline, probePin: pin),
            phase: .certificateChanged(pin), displayed: .certificateChanged
        )
        check(
            "a failed away read does not lift the probe pin",
            state(road: away, probePin: pin),
            .boardReported(problem: .offline, readPin: nil),
            state(road: away, probePin: pin, dnsProblem: .offline),
            phase: .certificateChanged(pin), displayed: .certificateChanged
        )
        check(
            "a certificate read stores the read pin",
            state(road: away),
            .boardReported(problem: .certificateChanged, readPin: pin),
            state(road: away, readPin: pin, dnsProblem: .certificateChanged),
            phase: .certificateChanged(pin), displayed: .certificateChanged
        )
        check(
            "another problem clears the read pin",
            state(road: away, readPin: pin, dnsProblem: .certificateChanged),
            .boardReported(problem: .refused, readPin: other),
            state(road: away, dnsProblem: .refused),
            phase: .blocked(.refused), displayed: .refused
        )
        check(
            "a clear read with no pin is ready",
            state(road: away, dnsProblem: .offline),
            .boardReported(problem: nil, readPin: nil),
            state(road: away),
            phase: .ready, displayed: nil
        )
        check(
            "no password and not set up is no password",
            AdBlockerAccess(),
            .boardReported(problem: .notSetUp, readPin: nil),
            AdBlockerAccess(dnsProblem: .notSetUp),
            phase: .noPassword, displayed: .notSetUp
        )
        check(
            "a saved password and not set up is a blocked page",
            state(),
            .boardReported(problem: .notSetUp, readPin: nil),
            state(dnsProblem: .notSetUp),
            phase: .blocked(.notSetUp), displayed: .notSetUp
        )
    }

    func testMailboxHidesTheBoardProblem() throws {
        let mailbox = try mailboxRoad()
        check(
            "the mailbox hides an offline board",
            state(road: mailbox),
            .boardReported(problem: .offline, readPin: nil),
            state(road: mailbox, dnsProblem: .offline),
            phase: .ready, displayed: nil
        )
        check(
            "the mailbox does not hide a probe pin",
            state(road: mailbox, probePin: pin, dnsProblem: .offline),
            .roadChanged(mailbox),
            state(road: mailbox, probePin: pin, dnsProblem: .offline),
            phase: .certificateChanged(pin), displayed: .certificateChanged
        )
        check(
            "a road change keeps the board problem",
            state(dnsProblem: .offline),
            .roadChanged(try awayLive()),
            state(road: try awayLive(), dnsProblem: .offline),
            phase: .blocked(.offline), displayed: .offline
        )
    }

    func testTheCertificatePageFollowsTheRoad() throws {
        let away = try awayLive()
        let yielded = state(road: away, probePin: pin, homeProbeYields: true)
        check(
            "a yielded pin stays off the away-live road",
            yielded, .roadChanged(away), yielded,
            phase: .ready, displayed: nil
        )
        check(
            "home shows that same pin again",
            yielded, .roadChanged(.home),
            state(probePin: pin, homeProbeYields: true),
            phase: .certificateChanged(pin), displayed: .certificateChanged
        )
        check(
            "offline shows that same pin again",
            yielded, .roadChanged(.offline),
            state(road: .offline, probePin: pin, homeProbeYields: true),
            phase: .certificateChanged(pin), displayed: .certificateChanged
        )
        check(
            "a kept pin at home still says pin kept",
            state(probePin: pin, declinedPin: pin, homeProbeYields: true),
            .roadChanged(.home),
            state(probePin: pin, declinedPin: pin, homeProbeYields: true),
            phase: .pinKept, displayed: .pinKept
        )
    }

    private func state(
        road: ConnectionMode = .home,
        passwordSaved: Bool = true,
        signedOut: Bool = false,
        probePin: String? = nil,
        readPin: String? = nil,
        declinedPin: String? = nil,
        dnsProblem: PiholeProblem? = nil,
        homeProbeYields: Bool = false
    ) -> AdBlockerAccess {
        AdBlockerAccess(
            passwordSaved: passwordSaved,
            signedOut: signedOut,
            probePin: probePin,
            readPin: readPin,
            declinedPin: declinedPin,
            dnsProblem: dnsProblem,
            road: road,
            homeProbeYields: homeProbeYields
        )
    }

    private func check(
        _ name: String,
        _ start: AdBlockerAccess,
        _ event: AdBlockerAccess.Event,
        _ expected: AdBlockerAccess,
        phase: AdBlockerAccess.Phase,
        displayed: PiholeProblem?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let next = start.reduce(event)
        XCTAssertEqual(next, expected, name, file: file, line: line)
        XCTAssertEqual(next.phase, phase, name, file: file, line: line)
        XCTAssertEqual(next.displayedDNSProblem, displayed, name, file: file, line: line)
        XCTAssertEqual(next.signedOut, expected.signedOut, name, file: file, line: line)
        XCTAssertEqual(next.probePin, expected.probePin, name, file: file, line: line)
        XCTAssertEqual(next.readPin, expected.readPin, name, file: file, line: line)
    }

    private func awayLive() throws -> ConnectionMode {
        .awayLive(try XCTUnwrap(AwayGatewaySettings(
            url: "https://gateway.example.test",
            clientID: "FAKE_client.access",
            clientSecret: "cfast_FAKE_not_a_real_secret"
        )))
    }

    private func mailboxRoad() throws -> ConnectionMode {
        .awayMailbox(MailboxSetup(
            address: try XCTUnwrap(MailboxAddress(text: "https://mailbox.example.test")),
            token: try XCTUnwrap(MailboxToken(text: "FAKE_mailbox_token"))
        ))
    }
}
