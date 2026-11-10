import XCTest
@testable import StreetPiCore

/// House Settings and the Settings tab each keep a client id and secret in the away section.
/// The pair typed earlier must not replace a key the other screen has since stored.
final class AwaySectionDraftTests: XCTestCase {
    func testTheAwaySectionDoesNotSaveAnOlderPair() {
        var stored = (clientID: "", secret: "")
        var writes = 0
        let save: (String, String, String) -> AwayGatewaySaveResult = { _, clientID, secret in
            writes += 1
            stored = (clientID, secret)
            return .saved
        }

        var house = AwaySectionDraft()
        house.acknowledge(stamp: 1)
        house.clientID = "working.access"
        house.secret = "working-copy"
        house.noteTyping(stamp: 1)
        XCTAssertEqual(
            house.save(address: "https://gateway.example.test", replacing: true, stamp: { 1 }, onSave: save),
            .wrote(.saved)
        )
        XCTAssertEqual(writes, 1)
        XCTAssertEqual(stored.clientID, "working.access")
        XCTAssertEqual(stored.secret, "working-copy")

        var tab = AwaySectionDraft()
        tab.acknowledge(stamp: 1)
        tab.clientID = "older.access"
        tab.secret = "older-copy"
        tab.noteTyping(stamp: 1)
        XCTAssertEqual(
            tab.save(address: "https://gateway.example.test", replacing: true, stamp: { 2 }, onSave: save),
            .kept
        )
        XCTAssertEqual(writes, 1)
        XCTAssertEqual(tab.clientID, "older.access")
        XCTAssertEqual(tab.secret, "older-copy")
        XCTAssertEqual(stored.clientID, "working.access")
        XCTAssertEqual(stored.secret, "working-copy")
    }

    func testAnEmptyAwaySectionStillSavesTheAddress() {
        var tab = AwaySectionDraft()
        tab.acknowledge(stamp: 1)
        var address = ""
        let save: (String, String, String) -> AwayGatewaySaveResult = { savedAddress, clientID, secret in
            address = savedAddress
            XCTAssertEqual(clientID, "")
            XCTAssertEqual(secret, "")
            return .saved
        }
        let outcome = tab.save(
            address: "https://moved.example.test", replacing: false, stamp: { 2 }, onSave: save
        )
        XCTAssertEqual(outcome, .wrote(.saved))
        XCTAssertEqual(address, "https://moved.example.test")
    }

    func testAPairTypedAfterThisSectionsSaveDoesNotReplaceANewerKey() {
        var stamp = 1
        var stored = (clientID: "", secret: "")
        var writes = 0
        let save: (String, String, String) -> AwayGatewaySaveResult = { _, clientID, secret in
            writes += 1
            stored = (clientID, secret)
            if clientID.isEmpty == false || secret.isEmpty == false {
                stamp += 1
            }
            return .saved
        }

        var section = AwaySectionDraft()
        section.acknowledge(stamp: stamp)
        section.clientID = "first.access"
        section.secret = "first-copy"
        section.noteTyping(stamp: stamp)
        XCTAssertEqual(
            section.save(
                address: "https://gateway.example.test", replacing: true, stamp: { stamp }, onSave: save
            ),
            .wrote(.saved)
        )
        XCTAssertEqual(section.clientID, "")
        XCTAssertEqual(section.secret, "")

        section.clientID = "second.access"
        section.secret = "second-copy"
        section.noteTyping(stamp: stamp)
        stamp += 1
        let newer = (clientID: "other.access", secret: "other-copy")
        stored = newer
        section.acknowledge(stamp: stamp)
        XCTAssertEqual(
            section.save(
                address: "https://gateway.example.test", replacing: true, stamp: { stamp }, onSave: save
            ),
            .kept
        )
        XCTAssertEqual(writes, 1)
        XCTAssertEqual(section.clientID, "second.access")
        XCTAssertEqual(section.secret, "second-copy")
        XCTAssertEqual(stored.clientID, newer.clientID)
        XCTAssertEqual(stored.secret, newer.secret)
    }
}
