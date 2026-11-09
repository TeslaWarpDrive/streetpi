import XCTest
@testable import StreetPiCore

final class LargeTypeWrapTests: XCTestCase {
    func testDomainBreaksAfterDots() {
        let wrapped = LargeTypeWrap.allowingWrap("ads.example.test")
        XCTAssertEqual(wrapped, "ads.\u{200B}example.\u{200B}test")
        XCTAssertFalse(wrapped.contains("-"))
        XCTAssertEqual(LargeTypeWrap.visible(wrapped), "ads.example.test")
    }

    func testAddressBreaksOnSeparators() {
        let wrapped = LargeTypeWrap.allowingWrap("https://192.168.1.78/api")
        XCTAssertEqual(
            wrapped,
            "https:\u{200B}/\u{200B}/\u{200B}192.\u{200B}168.\u{200B}1.\u{200B}78/\u{200B}api"
        )
        XCTAssertEqual(LargeTypeWrap.visible(wrapped), "https://192.168.1.78/api")
    }

    func testLongTokenBreaksWithoutAHyphen() {
        let token = String(repeating: "ab", count: 32)
        let wrapped = LargeTypeWrap.allowingWrap(token)
        XCTAssertFalse(wrapped.contains("-"))
        XCTAssertTrue(wrapped.contains("\u{200B}"))
        XCTAssertEqual(LargeTypeWrap.visible(wrapped), token)
        XCTAssertFalse(wrapped.hasPrefix("\u{200B}"))
    }

    func testSentenceKeepsWordsWhole() {
        let sentence = "Lookups the Pi has kept."
        let wrapped = LargeTypeWrap.allowingWrap(sentence)
        XCTAssertTrue(wrapped.contains("Lookups"))
        XCTAssertFalse(wrapped.contains("Lookup\u{200B}"))
        XCTAssertFalse(wrapped.contains("kept\u{200B}"))
        XCTAssertEqual(LargeTypeWrap.visible(wrapped), sentence)
    }

    func testEmptyStaysEmpty() {
        XCTAssertEqual(LargeTypeWrap.allowingWrap(""), "")
    }
}
