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
            house.save(address: "https://gateway.example.test", replacing: true, stamp: 1, onSave: save),
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
            tab.save(address: "https://gateway.example.test", replacing: true, stamp: 2, onSave: save),
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
            address: "https://moved.example.test", replacing: false, stamp: 2, onSave: save
        )
        XCTAssertEqual(outcome, .wrote(.saved))
        XCTAssertEqual(address, "https://moved.example.test")
    }
}
