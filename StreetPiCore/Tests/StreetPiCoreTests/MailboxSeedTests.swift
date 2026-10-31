import Foundation
import XCTest
@testable import StreetPiCore

final class MailboxSeedTests: XCTestCase {
    private let token = "fixture-not-a-real-read-token"

    private func plist(_ fields: [String: String]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: fields, format: .xml, options: 0)
    }

    private func makeSeed() throws -> MailboxSeed {
        let data = try plist(["mailboxURL": "https://mailbox.example.test", "readToken": token])
        return try XCTUnwrap(MailboxSeed(plist: data))
    }

    func testReadsTheBundledPlist() throws {
        let seed = try makeSeed()
        XCTAssertEqual(seed.setup.address.text, "https://mailbox.example.test")
        XCTAssertEqual(seed.setup.token.secret, token)
    }

    func testRefusesAPartOrBadPlist() throws {
        XCTAssertNil(MailboxSeed(plist: try plist(["mailboxURL": "https://mailbox.example.test"])))
        XCTAssertNil(MailboxSeed(plist: try plist(["readToken": token])))
        XCTAssertNil(MailboxSeed(plist: try plist(["mailboxURL": "http://mailbox.example.test", "readToken": token])))
        XCTAssertNil(MailboxSeed(plist: try plist(["mailboxURL": "https://mailbox.example.test", "readToken": " "])))
        XCTAssertNil(MailboxSeed(plist: Data("not a plist".utf8)))
    }

    func testDescriptionsHideTheToken() throws {
        var dumped = ""
        dump(try makeSeed(), to: &dumped)
        XCTAssertFalse(String(describing: try makeSeed()).contains(token))
        XCTAssertFalse(dumped.contains(token))
    }

    func testAnEmptyPhoneSeeds() throws {
        let seed = try makeSeed()
        XCTAssertEqual(MailboxSeedStep.next(handled: false, configured: false, seed: seed), .seed(seed.setup))
    }

    func testASavedMailboxWinsAndIsRemembered() throws {
        XCTAssertEqual(MailboxSeedStep.next(handled: false, configured: true, seed: try makeSeed()), .markHandled)
    }

    func testRemovedStaysRemoved() throws {
        XCTAssertEqual(MailboxSeedStep.next(handled: true, configured: false, seed: try makeSeed()), .nothing)
    }

    func testABuildWithNoSeedDoesNothing() {
        XCTAssertEqual(MailboxSeedStep.next(handled: false, configured: false, seed: nil), .nothing)
    }
}
