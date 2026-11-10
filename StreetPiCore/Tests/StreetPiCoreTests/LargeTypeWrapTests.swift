import XCTest
@testable import StreetPiCore

final class LargeTypeWrapTests: XCTestCase {
    func testDomainBreaksAfterDots() {
        let wrapped = LargeTypeWrap.allowingWrap("ads.example.test")
        let pieces = wrapped.split(separator: "\u{200B}").map(String.init)
        XCTAssertEqual(pieces.map { LargeTypeWrap.visible($0) }, ["ads.", "example.", "test"])
        guard pieces.count > 1 else { return }
        XCTAssertTrue(pieces[1].hasSuffix("."))
        XCTAssertTrue(pieces[1].contains("\u{2060}"))
        XCTAssertFalse(pieces[1].contains("\u{200B}"))
        XCTAssertFalse(wrapped.contains("-"))
        XCTAssertEqual(LargeTypeWrap.visible(wrapped), "ads.example.test")
    }

    func testRowThatHoldsExampleDoesNotSplitIt() {
        let wrapped = LargeTypeWrap.allowingWrap("ads.example.test") { $0.count <= 10 }
        XCTAssertEqual(
            wrapped.split(separator: "\u{200B}").map { LargeTypeWrap.visible(String($0)) },
            ["ads.", "example.", "test"]
        )
        XCTAssertFalse(wrapped.contains("-"))
    }

    func testAddressBreaksOnSeparators() {
        let wrapped = LargeTypeWrap.allowingWrap("https://192.168.1.78/api")
        XCTAssertEqual(
            wrapped.split(separator: "\u{200B}").map { LargeTypeWrap.visible(String($0)) },
            ["https:", "/", "/", "192.", "168.", "1.", "78/", "api"]
        )
        XCTAssertEqual(LargeTypeWrap.visible(wrapped), "https://192.168.1.78/api")
        XCTAssertFalse(wrapped.contains("-"))
    }

    func testUnknownWidthKeepsALongRunWhole() {
        let token = String(repeating: "ab", count: 32)
        let wrapped = LargeTypeWrap.allowingWrap(token)
        XCTAssertFalse(wrapped.contains("\u{200B}"))
        XCTAssertFalse(wrapped.contains("-"))
        XCTAssertTrue(wrapped.contains("\u{2060}"))
        XCTAssertEqual(LargeTypeWrap.visible(wrapped), token)
        XCTAssertFalse(wrapped.hasPrefix("\u{200B}"))
    }

    func testRunWiderThanTheRowBreaksWithoutAHyphen() {
        let token = "abcdefghijkl"
        let wrapped = LargeTypeWrap.allowingWrap(token) { $0.count <= 10 }
        let pieces = wrapped.split(separator: "\u{200B}").map(String.init)
        XCTAssertEqual(pieces, token.map(String.init))
        XCTAssertFalse(wrapped.contains("-"))
        XCTAssertFalse(wrapped.contains("\u{2060}"))
        XCTAssertEqual(LargeTypeWrap.visible(wrapped), token)
    }

    func testSentenceKeepsWordsWhole() {
        let sentence = "Lookups the Pi has kept."
        let wrapped = LargeTypeWrap.allowingWrap(sentence)
        XCTAssertEqual(LargeTypeWrap.visible(wrapped), sentence)
        XCTAssertFalse(wrapped.contains("Lookup\u{200B}"))
        let kept = wrapped.split(separator: " ").last.map(String.init) ?? ""
        XCTAssertEqual(LargeTypeWrap.visible(kept), "kept.")
        XCTAssertTrue(kept.hasSuffix("\u{200B}"))
        XCTAssertFalse(kept.dropLast().contains("\u{200B}"))
    }

    func testEmptyStaysEmpty() {
        XCTAssertEqual(LargeTypeWrap.allowingWrap(""), "")
    }
}
