import XCTest
@testable import StreetPiCore

final class AwayKeyDraftTests: XCTestCase {
    func testShowsFormWhenThereIsANoticeOrTypedText() {
        XCTAssertFalse(AwayKeyDraft().showsForm(notice: nil))
        XCTAssertTrue(AwayKeyDraft().showsForm(notice: "Rejected"))
        XCTAssertTrue(AwayKeyDraft(clientID: "new.access").showsForm(notice: nil))
        XCTAssertTrue(AwayKeyDraft(secret: "cfast_FAKE_new").showsForm(notice: nil))
        XCTAssertFalse(AwayKeyDraft(note: "Old note").showsForm(notice: nil))
    }

    func testConfirmationShowsOnlyAfterASaveWithTheFormGone() {
        XCTAssertTrue(AwayKeyDraft(saved: true).showsConfirmation(notice: nil))
        XCTAssertFalse(AwayKeyDraft(saved: true).showsConfirmation(notice: "Rejected"))
        XCTAssertFalse(AwayKeyDraft(clientID: "new.access", saved: true).showsConfirmation(notice: nil))
        XCTAssertFalse(AwayKeyDraft().showsConfirmation(notice: nil))
    }

    func testSettleClearsSavedOnANewNoticeAndDoesNotBringItBack() {
        var draft = AwayKeyDraft(saved: true)
        XCTAssertTrue(draft.showsConfirmation(notice: nil))
        XCTAssertFalse(draft.showsConfirmation(notice: "Rejected"))
        draft.settle(notice: "Rejected")
        draft.settle(notice: nil)
        XCTAssertFalse(draft.saved)
        XCTAssertFalse(draft.showsConfirmation(notice: nil))
    }

    func testSettleLeavesTypedTextWhenTheNoticeClears() {
        var draft = AwayKeyDraft(clientID: "new.access", secret: "cfast_FAKE_new")
        draft.settle(notice: nil)
        XCTAssertTrue(draft.showsForm(notice: nil))
        XCTAssertEqual(draft.clientID, "new.access")
        XCTAssertEqual(draft.secret, "cfast_FAKE_new")
        XCTAssertFalse(AwayKeyDraft().showsForm(notice: nil))
    }

    func testSettleDropsANoteOnlyWhenTheFormIsGone() {
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

    func testSettleLeavesTypedTextBesideASavedFlag() {
        var draft = AwayKeyDraft(clientID: "new.access", secret: "cfast_FAKE_new", saved: true)
        draft.settle(notice: nil)
        XCTAssertTrue(draft.saved)
        XCTAssertEqual(draft.clientID, "new.access")
        XCTAssertEqual(draft.secret, "cfast_FAKE_new")
        XCTAssertTrue(draft.showsForm(notice: nil))
        XCTAssertFalse(draft.showsConfirmation(notice: nil))
    }

    func testSaveWithoutBothValuesNeverReachesTheForm() {
        let pairs = [("", "cfast_FAKE_new"), ("new.access", " "), (" ", "cfast_FAKE_new"), ("", "")]
        for (clientID, secret) in pairs {
            var draft = AwayKeyDraft(clientID: clientID, secret: secret)
            draft.save(address: "https://gateway.example.test") { _, _, _ in
                XCTFail("An empty value must not be saved")
                return .saved
            }
            XCTAssertEqual(draft.note, AwayGatewaySaveResult.missingCredentials.note)
            XCTAssertEqual(draft.clientID, clientID)
            XCTAssertEqual(draft.secret, secret)
            XCTAssertFalse(draft.saved)
        }
    }

    func testSaveSendsTheAddressAndTypedValues() {
        var received: [String] = []
        var draft = AwayKeyDraft(clientID: "new.access", secret: "cfast_FAKE_new", note: "Old note")
        draft.save(address: "https://gateway.example.test") { address, clientID, secret in
            received = [address, clientID, secret]
            return .saved
        }
        XCTAssertEqual(received, ["https://gateway.example.test", "new.access", "cfast_FAKE_new"])
        XCTAssertEqual(draft, AwayKeyDraft(saved: true))
    }

    func testSaveCatchesTheBasisUpBeforeTheNextPair() {
        var stamp = 1
        var card = AwayKeyDraft()
        card.acknowledge(stamp: stamp)
        card.clientID = "first.access"
        card.secret = "first-copy"
        card.noteTyping(stamp: stamp)
        let save: (String, String, String) -> AwayGatewaySaveResult = { _, _, _ in
            stamp += 1
            return .saved
        }
        card.save(address: "https://gateway.example.test", stamp: { stamp }, onSave: save)
        XCTAssertEqual(card.copy.basis, stamp)
        XCTAssertEqual(card.clientID, "")
        XCTAssertEqual(card.secret, "")

        card.clientID = "second.access"
        card.secret = "second-copy"
        card.noteTyping(stamp: stamp)
        XCTAssertEqual(card.copy.basisClientID, "second.access")
        XCTAssertEqual(card.copy.basisSecret, "second-copy")
        stamp += 1
        card.acknowledge(stamp: stamp)
        XCTAssertEqual(
            card.copy.decision(clientID: card.clientID, secret: card.secret, stamp: stamp),
            .keepSaved
        )
    }

    func testFailedSaveKeepsTheTypedValuesAndSaysWhy() {
        for result in [AwayGatewaySaveResult.badAddress, .missingCredentials, .failed] {
            var draft = AwayKeyDraft(clientID: "new.access", secret: "cfast_FAKE_new")
            draft.save(address: "https://gateway.example.test") { _, _, _ in result }
            XCTAssertEqual(draft.note, result.note)
            XCTAssertEqual(draft.clientID, "new.access")
            XCTAssertEqual(draft.secret, "cfast_FAKE_new")
            XCTAssertFalse(draft.saved)
            XCTAssertFalse(draft.showsConfirmation(notice: nil))
        }
    }
}
