import StreetPiCore
import XCTest
@testable import StreetPi

/// House Settings and the Settings tab each keep an away-key draft. The one that still has the older
/// copy must not replace the key the other screen just saved.
final class SettingsCopyTests: XCTestCase {
    func testTheOtherScreenDoesNotSaveAnOlderKey() {
        let gate = StampGate(stamp: 1)
        var house = AwayKeyDraft()
        house.acknowledge(stamp: gate.stamp)
        house.clientID = "working.access"
        house.secret = "working-copy"
        house.noteTyping(stamp: gate.stamp)
        house.save(with: gate.form())
        XCTAssertEqual(gate.writes, 1)
        XCTAssertTrue(house.saved)
        XCTAssertEqual(gate.clientID, "working.access")
        XCTAssertEqual(gate.secret, "working-copy")

        var tab = AwayKeyDraft()
        tab.acknowledge(stamp: 1)
        tab.clientID = "older.access"
        tab.secret = "older-copy"
        tab.noteTyping(stamp: 1)
        tab.acknowledge(stamp: gate.stamp)
        tab.save(with: gate.form())
        XCTAssertEqual(gate.writes, 1)
        XCTAssertFalse(tab.saved)
        XCTAssertEqual(tab.note, SettingsDraftSave.keptKeyNote)
        XCTAssertEqual(tab.clientID, "older.access")
        XCTAssertEqual(gate.secret, "working-copy")
    }

    func testAnEditAfterTheOtherSaveStillSaves() {
        let gate = StampGate(stamp: 2)
        var tab = AwayKeyDraft()
        tab.acknowledge(stamp: 1)
        tab.clientID = "older.access"
        tab.secret = "older-copy"
        tab.noteTyping(stamp: 1)
        tab.clientID = "fresh.access"
        tab.noteTyping(stamp: gate.stamp)
        tab.save(with: gate.form())
        XCTAssertEqual(gate.writes, 1)
        XCTAssertTrue(tab.saved)
        XCTAssertEqual(gate.clientID, "fresh.access")
        XCTAssertEqual(gate.secret, "older-copy")
    }
}

private final class StampGate {
    var stamp: Int
    var clientID = ""
    var secret = ""
    var writes = 0

    init(stamp: Int) {
        self.stamp = stamp
    }

    func form() -> AwayGatewayForm {
        AwayGatewayForm(
            address: "https://gateway.example.test",
            onSave: { _, clientID, secret in
                self.writes += 1
                self.clientID = clientID
                self.secret = secret
                self.stamp += 1
                return .saved
            },
            savedStamp: { self.stamp }
        )
    }
}
