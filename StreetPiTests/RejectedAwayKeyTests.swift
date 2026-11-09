import Foundation
import StreetPiCore
import SwiftUI
import XCTest
@testable import StreetPi

/// Gives the card a real binding, so a test sees what its save leaves behind.
@MainActor
@Observable
private final class DraftBox {
    var draft: AwayKeyDraft

    init(_ draft: AwayKeyDraft) {
        self.draft = draft
    }
}

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
            assertNoticeShows(root)
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
            assertNoticeHidden(root)
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
        assertNoticeHidden(root)
    }

    func testOnlyHealth200AnswersAndOnly403RejectsKey() async throws {
        for status in [200, 302, 401, 403, 404, 503] {
            let reply = await GatewayProbe().reply(try gateway(), http: ProbeReply(status: status))
            XCTAssertEqual(reply, status == 200 ? .answered : status == 403 ? .rejectedKey : .noAnswer)
        }
    }

    func testForbiddenDuringAwayRefreshReachesTheNotice() async throws {
        try await assertAwayRefresh(RejectedKeyHTTPStub.self, problem: .offline, showsNotice: true)
    }

    func testALaterForbiddenDuringAwayRefreshIsNotABadKey() async throws {
        try await assertAwayRefresh(
            RejectedAfterLoginHTTPStub.self, problem: .refused, showsNotice: false, priorRejection: true
        )
    }

    private func assertAwayRefresh(
        _ protocolClass: URLProtocol.Type,
        problem: PiholeProblem,
        showsNotice: Bool,
        priorRejection: Bool = false
    ) async throws {
        let gateway = try gateway()
        let root = RootView(now: .streetFixtureNow, mode: .awayLive(gateway))
        if priorRejection {
            root.certificateRecovery.gatewayReply = .rejectedKey
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [protocolClass]
        let http = AwayHTTPClient(settings: gateway, configuration: configuration)
        root.certificateRecovery.awayHTTP = http
        let client = PiholeClient(
            transport: AwayPiholeTransport(base: LivePiholeTransport(
                http: http, base: try XCTUnwrap(gateway.piholeBase)
            )),
            password: { "FAKE_password" }
        )
        let secrets = MemorySecretStore()
        try KeychainSession(store: secrets).saveAppPassword("FAKE_password")
        let board = await root.refresh(client, now: .streetFixtureNow, secrets: secrets)
        XCTAssertEqual(board.problem, problem)
        if showsNotice {
            assertNoticeShows(root)
        } else {
            assertNoticeHidden(root)
        }
    }

    func testHomeRefreshForbiddenDoesNotClaimAwayKeyWasRejected() async {
        let root = RootView(now: .streetFixtureNow, mode: .home)
        let client = PiholeClient(
            transport: ScriptedPiholeTransport(steps: [.json(403, "{}")]),
            password: { "FAKE_password" }
        )
        let board = await root.refresh(client, now: .streetFixtureNow, secrets: MemorySecretStore())
        XCTAssertEqual(board.problem, .notSetUp)
        assertNoticeHidden(root)
    }

    func testCleanAwayRefreshClearsTheNotice() async throws {
        let gateway = try gateway()
        let root = RootView(now: .streetFixtureNow, mode: .awayLive(gateway))
        root.certificateRecovery.awayHTTP = AwayHTTPClient(settings: gateway, configuration: .ephemeral)
        root.certificateRecovery.gatewayReply = .rejectedKey
        let client = PiholeClient(
            transport: ScriptedPiholeTransport(steps: AnsweredBoard.cleanDeskSteps),
            password: { "FAKE_password" },
            now: { .streetFixtureNow }
        )
        let secrets = MemorySecretStore()
        try KeychainSession(store: secrets).saveAppPassword("FAKE_password")
        let board = await root.refresh(client, now: .streetFixtureNow, secrets: secrets)
        XCTAssertNil(board.problem)
        assertNoticeHidden(root)
    }

    func testAwayReadThatReachesThePiClearsTheNoticeWhateverTheBoardSays() async throws {
        let gateway = try gateway()
        for reading in try AnsweredBoard.all() {
            let root = RootView(now: .streetFixtureNow, mode: .awayLive(gateway))
            root.certificateRecovery.awayHTTP = AwayHTTPClient(settings: gateway, configuration: .ephemeral)
            root.certificateRecovery.gatewayReply = .rejectedKey
            let board = await root.refresh(reading.client, now: .streetFixtureNow, secrets: reading.secrets)
            XCTAssertEqual(board.problem, reading.problem)
            assertNoticeHidden(root)
        }
    }

    func testHouseReadThatReachesThePiClearsTheNoticeWhateverTheBoardSays() async throws {
        for reading in try AnsweredBoard.all() {
            let root = RootView(now: .streetFixtureNow, mode: .offline)
            root.certificateRecovery.gatewayReply = .rejectedKey
            let board = await root.refresh(reading.client, now: .streetFixtureNow, secrets: reading.secrets)
            XCTAssertEqual(board.problem, reading.problem)
            assertNoticeHidden(root)
        }
    }

    func testAReadThatNeverReachedThePiKeepsTheNotice() async throws {
        let gateway = try gateway()
        let steps: [ScriptedPiholeTransport.Step] = [
            .fail(.offline), .fail(.rateLimited), .json(401, "{}"), .json(302, "{}"), .json(200, "<html></html>"),
        ]
        for step in steps {
            for mode in [ConnectionMode.awayLive(gateway), .offline] {
                let root = RootView(now: .streetFixtureNow, mode: mode)
                if mode != .offline {
                    root.certificateRecovery.awayHTTP = AwayHTTPClient(settings: gateway, configuration: .ephemeral)
                }
                root.certificateRecovery.gatewayReply = .rejectedKey
                let client = PiholeClient(
                    transport: ScriptedPiholeTransport(steps: [step]), password: { "FAKE_password" }
                )
                _ = await root.refresh(client, now: .streetFixtureNow, secrets: MemorySecretStore())
                assertNoticeShows(root)
            }
        }
    }

    func testAForbiddenAwayReadThatLandsAfterLeavingTheRoadIsIgnored() async throws {
        let gateway = try gateway()
        let root = RootView(now: .streetFixtureNow, mode: .awayLive(gateway))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RejectedKeyHTTPStub.self]
        let http = AwayHTTPClient(settings: gateway, configuration: configuration)
        root.certificateRecovery.awayHTTP = http
        let road = LivePiholeTransport(http: http, base: try XCTUnwrap(gateway.piholeBase))
        let client = PiholeClient(
            transport: AfterReplyTransport(base: AwayPiholeTransport(base: road)) { @MainActor _ in
                root.adopt(.home)
            },
            password: { "FAKE_password" }
        )
        _ = await root.refresh(client, now: .streetFixtureNow, secrets: MemorySecretStore())
        assertNoticeHidden(root)
        XCTAssertNil(root.certificateRecovery.awayHTTP)
    }

    func testAHouseReadThatLandsAfterLeavingTheRoadKeepsTheNewRejection() async throws {
        let gateway = try gateway()
        let secrets = MemorySecretStore()
        try KeychainSession(store: secrets).saveAppPassword("FAKE_password")
        for mailbox in [nil, try mailbox()] {
            let root = RootView(now: .streetFixtureNow, mode: .home)
            let fallback = mailbox.map(ConnectionMode.awayMailbox) ?? .offline
            let client = PiholeClient(
                transport: AfterReplyTransport(
                    base: ScriptedPiholeTransport(steps: AnsweredBoard.cleanDeskSteps)
                ) { @MainActor request in
                    // The login reply is already in. The phone leaves while the desk is still loading.
                    guard request.path == "/api/auth" else { return }
                    let mode = await root.probeRoad(
                        gateway: gateway, mailbox: mailbox,
                        home: { PiProbe.Reading(mode: .offline) },
                        gatewayReply: { _ in .rejectedKey }
                    )
                    XCTAssertEqual(mode, fallback)
                    root.adopt(fallback)
                },
                password: { "FAKE_password" },
                now: { .streetFixtureNow }
            )
            let board = await root.refresh(client, now: .streetFixtureNow, secrets: secrets)
            XCTAssertNil(board.problem)
            assertNoticeShows(root)

            let later = PiholeClient(
                transport: ScriptedPiholeTransport(steps: [.json(200, #"{"dns":true}"#)]),
                password: { "FAKE_password" }
            )
            _ = await root.refresh(later, now: .streetFixtureNow, secrets: MemorySecretStore())
            assertNoticeHidden(root)
        }
    }

    func testChangingTheGatewayClearsTheNoticeAndItsClient() throws {
        let gateway = try gateway()
        let root = RootView(now: .streetFixtureNow, mode: .awayLive(gateway))
        root.certificateRecovery.awayHTTP = AwayHTTPClient(settings: gateway, configuration: .ephemeral)
        root.certificateRecovery.gatewayReply = .rejectedKey
        root.gatewayChanged()
        assertNoticeHidden(root)
        XCTAssertNil(root.certificateRecovery.awayHTTP)
    }

    func testSettingsCarriesTheMessageInThePage() {
        XCTAssertTrue(AwayKeyNotice(rejected: true, section: .settings).onPage)
        XCTAssertFalse(AwayKeyNotice(rejected: true, section: .group(.adBlockerAndDNS)).onPage)
        XCTAssertFalse(AwayKeyNotice(rejected: false, section: .settings).onPage)
    }

    func testRejectedKeyShowsOneCard() throws {
        let message = try XCTUnwrap(AwayKeyNotice(rejected: true, section: .settings).text)
        let unreachable = AwayStatus.unreachable.badge(now: .streetFixtureNow)
            .carrying(keyNotice: message, status: .unreachable)
        XCTAssertEqual(unreachable.line, message)
        XCTAssertNil(unreachable.detail)
        XCTAssertEqual(unreachable.spoken, message)

        let reading = AwayStatus.reading(generatedAt: .streetFixtureNow, problem: nil, note: nil)
        let report = reading.badge(now: .streetFixtureNow).carrying(keyNotice: message, status: reading)
        XCTAssertEqual(report.line, reading.badge(now: .streetFixtureNow).line)
        XCTAssertEqual(report.detail, message)
        XCTAssertTrue(report.spoken.hasSuffix(message))
        XCTAssertEqual(reading.badge(now: .streetFixtureNow).tone, .calm)
        XCTAssertEqual(report.tone, .attention)
        XCTAssertEqual(report.symbol, "key.slash")

        let plain = AwayStatus.unreachable.badge(now: .streetFixtureNow)
        XCTAssertEqual(plain.carrying(keyNotice: nil, status: .unreachable), plain)
    }

    func testRejectedKeyNeverSoftensASilentReport() throws {
        let message = try XCTUnwrap(AwayKeyNotice(rejected: true, section: .settings).text)
        let now = Date.streetFixtureNow
        let silent = AwayStatus.reading(generatedAt: now.addingTimeInterval(-86_400), problem: nil, note: nil)
        XCTAssertEqual(silent.badge(now: now).tone, .problem)
        let badge = silent.badge(now: now).carrying(keyNotice: message, status: silent)
        XCTAssertEqual(badge.tone, .problem)
        XCTAssertEqual(badge.symbol, "key.slash")
    }

    func testShortenedCardLeadsWithTheMessageAndSpeaksTheAge() throws {
        let message = try XCTUnwrap(AwayKeyNotice(rejected: true, section: .settings).text)
        let now = Date.streetFixtureNow
        let reading = AwayStatus.reading(generatedAt: now, problem: nil, note: nil)
        let age = reading.badge(now: now)
        let short = age.carrying(keyNotice: message, status: reading, shortened: true)
        XCTAssertEqual(short.line, message)
        XCTAssertNil(short.detail)
        XCTAssertEqual(short.spoken, "\(age.spoken) \(message)")
        XCTAssertFalse(reading.capsBar(keyNotice: message, keyOnPage: false, messageOnly: true))

        let problem = AwayStatus.reading(generatedAt: now, problem: .wrongAddress, note: nil)
        let reported = problem.badge(now: now)
        let shortProblem = reported.carrying(keyNotice: message, status: problem, shortened: true)
        XCTAssertEqual(shortProblem.line, message)
        XCTAssertEqual(shortProblem.detail, reported.detail)

        let noReport = AwayStatus.reading(generatedAt: nil, problem: .wrongAddress, note: nil)
        let first = noReport.badge(now: now)
        let shortFirst = first.carrying(keyNotice: message, status: noReport, shortened: true)
        XCTAssertEqual(shortFirst.line, message)
        XCTAssertEqual(shortFirst.detail, first.line)
    }

    func testShortenedCardKeepsTheWordsThatThePiWentQuiet() throws {
        let message = try XCTUnwrap(AwayKeyNotice(rejected: true, section: .settings).text)
        let now = Date.streetFixtureNow
        let generatedAt = now.addingTimeInterval(-86_400)
        let silent = AwayStatus.reading(generatedAt: generatedAt, problem: nil, note: nil)
        let quiet = silent.badge(now: now)
        XCTAssertTrue(quiet.line.hasPrefix("Pi hasn't reported"))
        let short = quiet.carrying(keyNotice: message, status: silent, shortened: true)
        XCTAssertEqual(short.line, message)
        XCTAssertEqual(short.detail, quiet.line)
        XCTAssertEqual(short.tone, .problem)
        XCTAssertTrue(silent.capsBar(
            keyNotice: message, keyOnPage: false, messageOnly: short.line == message && short.detail == nil
        ))

        let both = AwayStatus.reading(generatedAt: generatedAt, problem: .wrongAddress, note: nil)
        let reported = both.badge(now: now)
        let shortBoth = reported.carrying(keyNotice: message, status: both, shortened: true)
        XCTAssertEqual(shortBoth.detail, "\(reported.line) \(try XCTUnwrap(reported.detail))")
    }

    func testShortenedCardLeavesThePageMessageAlone() throws {
        let message = try XCTUnwrap(AwayKeyNotice(rejected: true, section: .settings).text)
        let reading = AwayStatus.reading(generatedAt: .streetFixtureNow, problem: nil, note: nil)
        let age = reading.badge(now: .streetFixtureNow)
        XCTAssertEqual(age.carrying(keyNotice: message, status: reading, keyOnPage: true, shortened: true), age)
    }

    func testMailboxAgeLineIsTheSameOnEveryTab() throws {
        let reading = AwayStatus.reading(generatedAt: .streetFixtureNow, problem: nil, note: nil)
        let age = reading.badge(now: .streetFixtureNow)
        for section in [AppSection.home, .group(.adBlockerAndDNS), .group(.piHealth), .settings] {
            let notice = AwayKeyNotice(rejected: true, section: section, hasAwayCard: true)
            XCTAssertTrue(reading.showsBar(keyOnPage: notice.onPage))
            let badge = age.carrying(keyNotice: notice.text, status: reading, keyOnPage: notice.onPage)
            XCTAssertEqual(badge.line, age.line)
        }
        let message = try XCTUnwrap(AwayKeyNotice(rejected: true, section: .settings).text)
        XCTAssertEqual(age.carrying(keyNotice: message, status: reading, keyOnPage: true), age)
    }

    func testPageMessageHidesTheBarWhenNoMailboxIsInUse() {
        XCTAssertFalse(AwayStatus.unreachable.showsBar(keyOnPage: true))
        XCTAssertFalse(AwayStatus.notSetUp.showsBar(keyOnPage: true))
        XCTAssertTrue(AwayStatus.unreachable.showsBar(keyOnPage: false))
        XCTAssertTrue(AwayStatus.reading(generatedAt: nil, problem: nil, note: nil).showsBar(keyOnPage: true))
    }

    func testBarIsCappedWheneverAMailboxBarShowsWithARejectedKey() {
        let reading = AwayStatus.reading(generatedAt: .streetFixtureNow, problem: .wrongAddress, note: nil)
        XCTAssertTrue(reading.capsBar(keyNotice: "Rejected", keyOnPage: false))
        XCTAssertTrue(reading.capsBar(keyNotice: "Rejected", keyOnPage: true))
        XCTAssertFalse(reading.capsBar(keyNotice: nil, keyOnPage: false))
        XCTAssertFalse(AwayStatus.unreachable.capsBar(keyNotice: "Rejected", keyOnPage: false))
    }

    func testSettingsDoesNotOfferToOpenSettings() {
        for rejected in [true, false] {
            let status = AwayStatus.reading(generatedAt: nil, problem: .wrongAddress, note: nil)
            let badge = status.badge(now: .streetFixtureNow)
            XCTAssertTrue(badge.offersSetup)
            let notice = AwayKeyNotice(rejected: rejected, section: .settings, hasAwayCard: true)
            let onPage = badge.carrying(
                keyNotice: notice.text, status: status, keyOnPage: notice.onPage, onSettings: true
            )
            XCTAssertFalse(onPage.offersSetup)
            XCTAssertEqual(onPage.line, badge.line)
        }
        let elsewhere = AwayStatus.notSetUp.badge(now: .streetFixtureNow)
        XCTAssertTrue(elsewhere.carrying(keyNotice: nil, status: .notSetUp).offersSetup)
    }

    func testCardSaveNeedsBothFieldsBeforeItReachesTheForm() {
        for (clientID, secret) in [("", "cfast_FAKE_new"), ("new.access", " "), ("", "")] {
            let box = DraftBox(AwayKeyDraft(clientID: clientID, secret: secret))
            let form = AwayGatewayForm(address: "https://gateway.example.test", onSave: { _, _, _ in
                XCTFail("An empty value must not be saved")
                return .saved
            })
            RejectedKeyCard(message: "Rejected", theme: .house, form: form, draft: Bindable(box).draft).save()
            XCTAssertEqual(box.draft.note, AwayGatewaySaveResult.missingCredentials.note)
            XCTAssertEqual(box.draft.clientID, clientID)
            XCTAssertEqual(box.draft.secret, secret)
        }
    }

    func testCardSaveSendsTheAddressAndTypedKeyToTheForm() {
        var received: [String] = []
        let form = AwayGatewayForm(address: "https://gateway.example.test", onSave: { address, clientID, secret in
            received = [address, clientID, secret]
            return .saved
        })
        let box = DraftBox(AwayKeyDraft(clientID: "new.access", secret: "cfast_FAKE_new"))
        RejectedKeyCard(message: "Rejected", theme: .house, form: form, draft: Bindable(box).draft).save()
        XCTAssertEqual(received, ["https://gateway.example.test", "new.access", "cfast_FAKE_new"])
        XCTAssertEqual(box.draft, AwayKeyDraft(saved: true))
    }

    func testDraftWithoutBothValuesNeverReachesTheForm() {
        for (clientID, secret) in [("", "cfast_FAKE_new"), ("new.access", " "), ("", "")] {
            var draft = AwayKeyDraft(clientID: clientID, secret: secret)
            draft.save(with: AwayGatewayForm(onSave: { _, _, _ in
                XCTFail("An empty value must not be saved")
                return .saved
            }))
            XCTAssertEqual(draft.note, AwayGatewaySaveResult.missingCredentials.note)
            XCTAssertEqual(draft.clientID, clientID)
            XCTAssertEqual(draft.secret, secret)
            XCTAssertFalse(draft.saved)
        }
    }

    func testDraftSavesTheFormAddressAndTypedValues() {
        var received: [String] = []
        let form = AwayGatewayForm(address: "https://gateway.example.test", onSave: { address, clientID, secret in
            received = [address, clientID, secret]
            return .saved
        })
        var draft = AwayKeyDraft(clientID: "new.access", secret: "cfast_FAKE_new", note: "Old note")
        draft.save(with: form)
        XCTAssertEqual(received, ["https://gateway.example.test", "new.access", "cfast_FAKE_new"])
        XCTAssertEqual(draft, AwayKeyDraft(saved: true))
    }

    func testFailedSaveKeepsTheTypedValuesAndSaysWhy() {
        for result in [AwayGatewaySaveResult.badAddress, .missingCredentials, .failed] {
            var draft = AwayKeyDraft(clientID: "new.access", secret: "cfast_FAKE_new")
            draft.save(with: AwayGatewayForm(onSave: { _, _, _ in result }))
            XCTAssertEqual(draft.note, result.note)
            XCTAssertEqual(draft.clientID, "new.access")
            XCTAssertEqual(draft.secret, "cfast_FAKE_new")
            XCTAssertFalse(draft.showsConfirmation(notice: nil))
        }
    }

    func testSaveThroughRootStoresTheKeyAndConfirmsAfterTheNoticeClears() throws {
        let store = try oldKeyStore()
        let root = try rejectedRoot()
        var form = root.makeGatewayForm(store: store)
        form.address = "https://gateway.example.test"
        var draft = AwayKeyDraft(clientID: "new.access", secret: "cfast_FAKE_new")
        draft.save(with: form)

        XCTAssertEqual(store.load()?.clientID, "new.access")
        XCTAssertEqual(store.load()?.clientSecret, "cfast_FAKE_new")
        assertNoticeHidden(root)
        XCTAssertNil(root.certificateRecovery.awayHTTP)
        let notice = AwayKeyNotice(rejected: root.awayKeyRejected, section: .settings).text
        XCTAssertTrue(draft.showsConfirmation(notice: notice))
        XCTAssertFalse(draft.showsForm(notice: notice))
    }

    func testRefusedSaveThroughRootKeepsTheNoticeAndTheOldKey() throws {
        let store = try oldKeyStore()
        let root = try rejectedRoot()
        var form = root.makeGatewayForm(store: store)
        form.address = "http://gateway.example.test"
        var draft = AwayKeyDraft(clientID: "new.access", secret: "cfast_FAKE_new")
        draft.save(with: form)

        XCTAssertEqual(draft.note, AwayGatewaySaveResult.badAddress.note)
        XCTAssertEqual(store.load()?.clientID, "old.access")
        assertNoticeShows(root)
        XCTAssertNotNil(root.certificateRecovery.awayHTTP)
    }

    func testProbeClearingTheNoticeLeavesTheTypedKeyOnScreen() async throws {
        let root = RootView(now: .streetFixtureNow)
        root.certificateRecovery.gatewayReply = .rejectedKey
        var draft = AwayKeyDraft(clientID: "new.access", secret: "cfast_FAKE_new")
        _ = await root.probeRoad(
            gateway: try gateway(), mailbox: nil,
            home: { PiProbe.Reading(mode: .offline) },
            gatewayReply: { await GatewayProbe().reply($0, http: ProbeReply(status: nil)) }
        )
        let notice = AwayKeyNotice(rejected: root.awayKeyRejected, section: .settings).text
        XCTAssertNil(notice)
        draft.settle(notice: notice)
        XCTAssertTrue(draft.showsForm(notice: notice))
        XCTAssertEqual(draft.clientID, "new.access")
        XCTAssertEqual(draft.secret, "cfast_FAKE_new")
        XCTAssertFalse(AwayKeyDraft().showsForm(notice: notice))
    }

    func testNewRejectionDropsTheConfirmationForGood() {
        var draft = AwayKeyDraft(saved: true)
        XCTAssertTrue(draft.showsConfirmation(notice: nil))
        XCTAssertFalse(draft.showsConfirmation(notice: "Rejected"))
        draft.settle(notice: "Rejected")
        draft.settle(notice: nil)
        XCTAssertFalse(draft.showsConfirmation(notice: nil))
    }

    func testNoteGoesWithTheFormAndStaysWithHeldText() {
        var empty = AwayKeyDraft(note: AwayGatewaySaveResult.missingCredentials.note)
        empty.settle(notice: "Rejected")
        XCTAssertFalse(empty.note.isEmpty)
        empty.settle(notice: nil)
        XCTAssertEqual(empty.note, "")

        let note = AwayGatewaySaveResult.failed.note
        var typed = AwayKeyDraft(clientID: "new.access", note: note)
        typed.settle(notice: nil)
        XCTAssertEqual(typed.note, note)
    }

    private func oldKeyStore() throws -> AwayGatewayStore {
        let suite = "streetpi.tests.rejected-save"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let store = AwayGatewayStore(store: MemorySecretStore(), defaults: defaults)
        XCTAssertEqual(
            store.save(address: "https://gateway.example.test", clientID: "old.access", secret: "cfast_FAKE_old"),
            .saved
        )
        return store
    }

    private func rejectedRoot() throws -> RootView {
        let gateway = try gateway()
        let root = RootView(now: .streetFixtureNow, mode: .awayLive(gateway))
        root.certificateRecovery.awayHTTP = AwayHTTPClient(settings: gateway, configuration: .ephemeral)
        root.certificateRecovery.gatewayReply = .rejectedKey
        return root
    }

    private func assertNoticeShows(_ root: RootView, line: UInt = #line) {
        let message = "Away key was rejected – replace it in Settings"
        for section in [AppSection.group(.adBlockerAndDNS), .settings] {
            XCTAssertEqual(
                AwayKeyNotice(rejected: root.awayKeyRejected, section: section).text, message, line: line
            )
        }
        XCTAssertNil(AwayKeyNotice(rejected: root.awayKeyRejected, section: .group(.piHealth)).text, line: line)
    }

    private func assertNoticeHidden(_ root: RootView, line: UInt = #line) {
        for section in [AppSection.group(.adBlockerAndDNS), .settings] {
            XCTAssertNil(AwayKeyNotice(rejected: root.awayKeyRejected, section: section).text, line: line)
        }
    }
}

private struct AnsweredBoard {
    var client: PiholeClient
    var secrets: MemorySecretStore
    var problem: PiholeProblem?

    /// Every board a Pi-hole login reply can lead to: not set up, dns off, a failed desk, and a clean read.
    static func all() throws -> [AnsweredBoard] {
        let saved = MemorySecretStore()
        try KeychainSession(store: saved).saveAppPassword("FAKE_password")
        func client(_ steps: [ScriptedPiholeTransport.Step]) -> PiholeClient {
            PiholeClient(
                transport: ScriptedPiholeTransport(steps: steps),
                password: { "FAKE_password" },
                now: { .streetFixtureNow }
            )
        }
        return [
            AnsweredBoard(
                client: client([.json(200, #"{"dns":true}"#)]), secrets: MemorySecretStore(), problem: .notSetUp
            ),
            AnsweredBoard(client: client([.json(200, #"{"dns":false}"#)]), secrets: saved, problem: .dnsOff),
            AnsweredBoard(
                client: client([.json(200, #"{"dns":true}"#), .fail(.refused)]), secrets: saved, problem: .refused
            ),
            AnsweredBoard(client: client(cleanDeskSteps), secrets: saved, problem: nil),
        ]
    }

    static var cleanDeskSteps: [ScriptedPiholeTransport.Step] {
        let stamp = Int(Date.streetFixtureNow.timeIntervalSince1970) - 3_600
        return [
            .json(200, #"{"dns":true,"https_port":443}"#),
            .json(200, #"{"session":{"sid":"FAKE_session","validity":1800}}"#),
            .json(200, #"{"queries":{"total":12,"blocked":3},"clients":{"active":4}}"#),
            .json(200, #"{"blocking":"enabled","timer":null}"#),
            .json(200, #"{"history":[{"timestamp":\#(stamp),"total":10,"blocked":4}]}"#),
            .json(200, #"{"domains":[{"domain":"news.example.test","count":9}]}"#),
            .json(200, #"{"domains":[{"domain":"ads.example.test","count":3}]}"#),
            .json(200, #"{"clients":[{"name":"Living room","count":9}]}"#),
            .json(200, #"{"queries":[]}"#),
            .json(200, #"{"clients":[{"ip":"192.0.2.20","name":"Living room","count":9}]}"#),
            .json(200, #"{"groups":[{"name":"Default","comment":"The house"}]}"#),
            .json(200, #"{"domains":[]}"#),
            .json(200, #"{"domains":[]}"#),
            .json(200, #"{"lists":[]}"#),
            .json(200, #"{"hosts":[]}"#),
            .json(200, #"{"cnameRecords":[]}"#),
            .json(200, #"{"config":{"dns":{"queryLogging":false}}}"#),
        ]
    }
}

/// Lets a test change the road while a read is still on its way back.
private struct AfterReplyTransport: PiholeTransport {
    var base: any PiholeTransport
    var after: @Sendable (PiholeRequest) async -> Void

    func send(_ request: PiholeRequest) async throws -> PiholeResponse {
        let response = try await base.send(request)
        await after(request)
        return response
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

private class RejectedKeyHTTPStub: URLProtocol, @unchecked Sendable {
    class var rejectsLogin: Bool { true }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let url = request.url else { return }
        let status: Int
        let body: String
        switch url.path {
        case "/api/info/login" where !Self.rejectsLogin:
            status = 200
            body = "{\"dns\":true}"
        case "/api/auth":
            status = 200
            body = "{\"session\":{\"sid\":\"FAKE_session\",\"validity\":1800}}"
        default:
            status = 403
            body = "{}"
        }
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)
        else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

private final class RejectedAfterLoginHTTPStub: RejectedKeyHTTPStub, @unchecked Sendable {
    override class var rejectsLogin: Bool { false }
}
