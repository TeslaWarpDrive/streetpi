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
        XCTAssertEqual(seed.mailbox?.address.text, "https://mailbox.example.test")
        XCTAssertEqual(seed.mailbox?.token.secret, token)
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
        XCTAssertEqual(
            MailboxSeedStep.next(handled: false, configured: false, seed: seed),
            .seed(try XCTUnwrap(seed.mailbox))
        )
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

    private func decode(_ text: String) throws -> ProvisionSeed {
        try ProvisionSeed.decode(Data(text.utf8))
    }

    func testVersionOneJSONStillDecodes() throws {
        let seed = try decode("""
        {"version":1,"mailboxURL":"https://mailbox.example.test","readToken":"test-read-FAKE","future":true}
        """)
        XCTAssertEqual(seed.mailbox?.token.secret, "test-read-FAKE")
        XCTAssertNil(seed.gateway)
    }

    func testVersionTwoOptionalGroupsAndUnknownFields() throws {
        let mailbox = #""mailbox":{"url":"https://mailbox.example.test","readToken":"test-read-FAKE","future":1}"#
        let gateway = #"""
        "gateway":{"url":"https://gateway.example.test","clientId":"test-client.access",
        "clientSecret":"cfast_FAKE","future":1}
        """#
        for fields in [mailbox, gateway, mailbox + "," + gateway] {
            let seed = try decode(#"{"version":2,"future":true,"# + fields + "}")
            XCTAssertEqual(seed.mailbox != nil, fields.contains("mailbox"))
            XCTAssertEqual(seed.gateway != nil, fields.contains("gateway"))
            if let gateway = seed.gateway {
                XCTAssertEqual(gateway.url.absoluteString, "https://gateway.example.test")
                XCTAssertEqual(gateway.clientID, "test-client.access")
                XCTAssertEqual(gateway.clientSecret, "cfast_FAKE")
                var dumped = ""
                dump(seed, to: &dumped)
                XCTAssertFalse(dumped.contains("cfast_FAKE"))
                XCTAssertFalse(dumped.contains("test-client.access"))
                XCTAssertFalse(String(reflecting: gateway).contains("cfast_FAKE"))
            }
        }
    }

    func testRefusesInvalidVersionTwoWithoutLeakingInput() {
        let invalid = [
            #"{"version":3,"mailbox":{"url":"https://mailbox.example.test","readToken":"test-read-FAKE"}}"#,
            #"{"version":2}"#,
            #"""
            {"version":2,"gateway":{"url":"http://gateway.example.test",
            "clientId":"test-client.access","clientSecret":"cfast_FAKE"}}
            """#,
            #"""
            {"version":2,"gateway":{"url":"https://gateway.example.test","clientId":" ",
            "clientSecret":"cfast_FAKE"}}
            """#,
            #"""
            {"version":2,"gateway":{"url":"https://gateway.example.test",
            "clientId":"test-client.access","clientSecret":""}}
            """#,
            #"{"version":2,"gateway":{"url":"https://gateway.example.test","clientId":"test-client.access"}}"#,
            #"{"version":2,"mailbox":{"url":"http://mailbox.example.test","readToken":"test-read-FAKE"}}"#,
            #"{"version":2,"mailbox":false,"cfast_FAKE":1}"#,
            "cfast_FAKE"
        ]
        for text in invalid {
            XCTAssertThrowsError(try decode(text)) { error in
                XCTAssertEqual(String(describing: error), "invalidSeed")
            }
        }
    }

    func testGatewayOnlyDoesNotMarkMailboxHandled() throws {
        let seed = try decode("""
        {"version":2,
        "gateway":{"url":"https://gateway.example.test",
        "clientId":"test-client.access",
        "clientSecret":"cfast_FAKE"}}
        """)
        XCTAssertEqual(MailboxSeedStep.next(handled: false, configured: false, seed: seed), .nothing)
    }
}
