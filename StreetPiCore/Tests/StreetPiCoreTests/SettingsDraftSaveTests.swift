import XCTest
@testable import StreetPiCore

final class SettingsDraftSaveTests: XCTestCase {
    private struct Row {
        var name: String
        var basis: String
        var current: String
        var draftIsCopy: Bool
        var decision: SettingsDraftSave.Decision
    }

    /// House Settings and the Settings tab each hold a copy. This is the copy that has not moved.
    private let olderCopy = Row(
        name: "an older copy leaves a newer save",
        basis: "pin-before",
        current: "pin-after",
        draftIsCopy: true,
        decision: .keepSaved
    )

    private let preserved: [Row] = [
        Row(
            name: "the same copy saves again",
            basis: "pin-before",
            current: "pin-before",
            draftIsCopy: true,
            decision: .write
        ),
        Row(
            name: "an edit saves when the stored value has not moved",
            basis: "pin-before",
            current: "pin-before",
            draftIsCopy: false,
            decision: .write
        ),
        Row(
            name: "an edit still saves after another save",
            basis: "pin-before",
            current: "pin-after",
            draftIsCopy: false,
            decision: .write
        )
    ]

    func testPreservedCopiesStillWrite() {
        for row in preserved {
            XCTAssertEqual(
                SettingsDraftSave.decide(
                    basis: row.basis,
                    current: row.current,
                    draftIsCopy: row.draftIsCopy
                ),
                row.decision,
                row.name
            )
        }
        XCTAssertEqual(
            SettingsDraftSave.pin(seen: "pin-before", draft: "pin-before", saved: "pin-before"),
            "pin-before"
        )
        XCTAssertEqual(
            SettingsDraftSave.pin(seen: " pin-before ", draft: "pin-before", saved: "pin-before"),
            "pin-before"
        )
        XCTAssertEqual(
            SettingsDraftSave.pin(seen: "pin-before", draft: " pin-edited ", saved: "pin-before"),
            "pin-edited"
        )
        XCTAssertEqual(
            SettingsDraftSave.pin(seen: "pin-before", draft: "pin-typed", saved: "pin-after"),
            "pin-typed"
        )

        var screen = AwayKeyCopy()
        screen.appeared(clientID: "", secret: "", stamp: 4)
        screen.typed(clientID: "fresh-key", secret: "fresh-copy", stamp: 4)
        XCTAssertEqual(screen.decision(clientID: "fresh-key", secret: "fresh-copy", stamp: 4), .write)
        let fresh = screen.kept(
            clientID: "fresh-key", secret: "fresh-copy", stamp: 4,
            savedClientID: "previous-key", savedSecret: "previous-copy"
        )
        XCTAssertEqual(fresh.clientID, "fresh-key")
        XCTAssertEqual(fresh.secret, "fresh-copy")

        var edited = AwayKeyCopy()
        edited.appeared(clientID: "", secret: "", stamp: 1)
        edited.typed(clientID: "older-key", secret: "older-copy", stamp: 1)
        edited.typed(clientID: "older-key-edited", secret: "older-copy", stamp: 2)
        XCTAssertEqual(
            edited.decision(clientID: "older-key-edited", secret: "older-copy", stamp: 2),
            .write
        )
        let rewritten = edited.kept(
            clientID: "older-key-edited", secret: "older-copy", stamp: 2,
            savedClientID: "working-key", savedSecret: "working-copy"
        )
        XCTAssertEqual(rewritten.clientID, "older-key-edited")
        XCTAssertEqual(rewritten.secret, "older-copy")

        var caughtUp = AwayKeyCopy()
        caughtUp.appeared(clientID: "", secret: "", stamp: 1)
        caughtUp.appeared(clientID: "", secret: "", stamp: 2)
        caughtUp.typed(clientID: "replacement", secret: "replacement-copy", stamp: 2)
        XCTAssertEqual(
            caughtUp.decision(clientID: "replacement", secret: "replacement-copy", stamp: 2),
            .write
        )
    }

    func testTheOlderCopyRow() {
        XCTAssertEqual(
            SettingsDraftSave.decide(
                basis: olderCopy.basis,
                current: olderCopy.current,
                draftIsCopy: olderCopy.draftIsCopy
            ),
            olderCopy.decision,
            olderCopy.name
        )
        let pin = SettingsDraftSave.pin(
            seen: olderCopy.basis,
            draft: " \(olderCopy.basis)\n",
            saved: olderCopy.current
        )
        XCTAssertEqual(pin, expectedPin(olderCopy))

        var house = AwayKeyCopy()
        var tab = AwayKeyCopy()
        house.appeared(clientID: "", secret: "", stamp: 1)
        tab.appeared(clientID: "", secret: "", stamp: 1)
        tab.typed(clientID: "older-key", secret: "older-copy", stamp: 1)
        house.typed(clientID: "working-key", secret: "working-copy", stamp: 1)
        XCTAssertEqual(house.decision(clientID: "working-key", secret: "working-copy", stamp: 1), .write)
        tab.appeared(clientID: "older-key", secret: "older-copy", stamp: 2)
        XCTAssertEqual(
            tab.decision(clientID: "older-key", secret: "older-copy", stamp: 2),
            olderCopy.decision
        )
        let kept = tab.kept(
            clientID: "older-key", secret: "older-copy", stamp: 2,
            savedClientID: "working-key", savedSecret: "working-copy"
        )
        if olderCopy.decision == .keepSaved {
            XCTAssertEqual(kept.clientID, "working-key")
            XCTAssertEqual(kept.secret, "working-copy")
        } else {
            XCTAssertEqual(kept.clientID, "older-key")
            XCTAssertEqual(kept.secret, "older-copy")
        }
    }

    func testKeptNotesStayPlain() {
        for note in [SettingsDraftSave.keptPinNote, SettingsDraftSave.keptKeyNote] {
            XCTAssertFalse(note.isEmpty)
            XCTAssertFalse(note.contains("http"))
            XCTAssertFalse(note.localizedCaseInsensitiveContains("password"))
        }
    }

    private func expectedPin(_ row: Row) -> String {
        row.decision == .keepSaved ? row.current : row.basis
    }
}
