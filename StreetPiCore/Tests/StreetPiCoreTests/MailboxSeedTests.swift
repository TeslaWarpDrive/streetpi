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

    func testGatewayOriginAndCredentialValidation() throws {
        for origin in ["https://gateway.example.test", "https://gateway.example.test/",
                       "https://gateway.example.test:8443"] {
            let gateway = try XCTUnwrap(decodeGateway(url: origin).gateway)
            XCTAssertEqual(gateway.clientID, "test-client.access")
            XCTAssertEqual(gateway.clientSecret, "cfast_FAKE")
        }
        let trimmed = try XCTUnwrap(decodeGateway(
            clientID: " \n test-client.access\t", clientSecret: "\tcfast_FAKE\r\n"
        ).gateway)
        XCTAssertEqual(trimmed.clientID, "test-client.access")
        XCTAssertEqual(trimmed.clientSecret, "cfast_FAKE")
        for origin in ["https://gateway.example.test/foo", "https://gateway.example.test//",
                       "https://gateway.example.test/%2F", "https://gateway.example.test:notaport",
                       "https://gateway.example.test:65536", "https://gateway.example.test:0",
                       "https://user@gateway.example.test", "https://@gateway.example.test",
                       "https://gateway.example.test?", "https://gateway.example.test#"] {
            XCTAssertThrowsError(try decodeGateway(url: origin))
        }
        for credential in ["test client", "test\nclient", "test\rclient", "test\tclient"] {
            XCTAssertThrowsError(try decodeGateway(clientID: credential))
            XCTAssertThrowsError(try decodeGateway(clientSecret: credential))
        }
    }

    func testMailboxPortValidationMatchesSealer() throws {
        for url in ["https://mailbox.example.test:notaport", "https://mailbox.example.test:65536",
                    "https://mailbox.example.test:0"] {
            let fields: [String: Any] = [
                "version": 2, "mailbox": ["url": url, "readToken": "test-read-FAKE"]
            ]
            XCTAssertThrowsError(try ProvisionSeed.decode(JSONSerialization.data(withJSONObject: fields)))
        }
        let seed = try decode("""
        {"version":2,"mailbox":{"url":"https://mailbox.example.test:8443/v1","readToken":"test-read-FAKE"}}
        """)
        XCTAssertEqual(seed.mailbox?.address.text, "https://mailbox.example.test:8443/v1")
    }

    private func decodeGateway(
        url: String = "https://gateway.example.test",
        clientID: String = "test-client.access",
        clientSecret: String = "cfast_FAKE"
    ) throws -> ProvisionSeed {
        // Include a valid mailbox: malformed gateway input must fail before CI ships either group.
        let fields: [String: Any] = [
            "version": 2,
            "mailbox": ["url": "https://mailbox.example.test", "readToken": "test-read-FAKE"],
            "gateway": ["url": url, "clientId": clientID, "clientSecret": clientSecret]
        ]
        return try ProvisionSeed.decode(JSONSerialization.data(withJSONObject: fields))
    }

}
