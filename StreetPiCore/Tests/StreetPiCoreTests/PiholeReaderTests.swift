import XCTest
@testable import StreetPiCore

final class PiholeReaderTests: XCTestCase {
    func testHousePinAndAddress() throws {
        XCTAssertTrue(PiholePin.isSHA256Pin(PiholePin.houseSPKI))
        XCTAssertEqual(PiholePin.effective("SHA256:fixture-not-a-real-cert"), PiholePin.houseSPKI)
        XCTAssertTrue(PiholePin.matches(presented: PiholePin.houseSPKI, expected: " \(PiholePin.houseSPKI) "))
        XCTAssertFalse(PiholePin.matches(presented: PiholePin.houseSPKI, expected: String(repeating: "A", count: 44)))
        let endpoint = try XCTUnwrap(PiholeBaseAddress.endpoint(from: PiholeBaseAddress.houseText))
        XCTAssertEqual(endpoint.host, "192.168.1.78")
        XCTAssertEqual(endpoint.port, 443)
        XCTAssertNil(PiholeBaseAddress.endpoint(from: "http://192.168.1.78/api"))
        XCTAssertNil(PiholeBaseAddress.endpoint(from: "https://192.168.1.78:80/api"))
        XCTAssertNil(PiholeBaseAddress.endpoint(from: "https://192.168.1.78/admin"))
        XCTAssertTrue(PiholePin.question.contains("security certificate changed, trust the new one?"))
        XCTAssertFalse(PiholePin.question.localizedCaseInsensitiveContains("not live"))
    }

    func testSHA256KnownAnswers() {
        XCTAssertEqual(hex(SHA256Digest.hash(Data())), emptyHash)
        XCTAssertEqual(hex(SHA256Digest.hash(Data("abc".utf8))), abcHash)
    }

    func testSubjectPublicKeyInfoIsHashed() throws {
        let spki = der(0x30, [0x02, 0x01, 0x01])
        let tbs = der(0x30, der(0x02, [0x01]) + der(0x30, []) + der(0x30, []) + der(0x30, []) + der(0x30, []) + spki)
        let certificate = der(0x30, tbs + der(0x30, []) + der(0x03, [0x00]))
        let extracted = try XCTUnwrap(CertificateValidity.subjectPublicKeyInfo(der: Data(certificate)))
        XCTAssertEqual([UInt8](extracted), spki)
        XCTAssertEqual(PiholePin.sha256Base64(extracted), Data(SHA256Digest.hash(Data(spki))).base64EncodedString())
    }

    func testProbeDoesNotSendASession() async throws {
        let transport = ScriptedPiholeTransport(steps: [
            .json(200, #"{"dns":true,"https_port":443}"#),
        ])
        let client = PiholeClient(transport: transport, password: { "fixture-not-a-real-password" })
        let state = try await client.reachability()
        XCTAssertEqual(state, .answering)
        let request = try XCTUnwrap(transport.sent.first)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/api/info/login")
        XCTAssertTrue(request.headers.isEmpty)
        XCTAssertFalse(String(describing: request).contains("fixture-not-a-real-password"))
    }

    func testProbeDistinguishesSetupFromSilence() async {
        let off = ScriptedPiholeTransport(steps: [.json(200, #"{"dns":false,"https_port":443}"#)])
        let offClient = PiholeClient(transport: off, password: { "" })
        let state = try? await offClient.reachability()
        XCTAssertEqual(state, .dnsOff)

        let missing = ScriptedPiholeTransport(steps: [.json(404, #"{"error":"missing"}"#)])
        let missingClient = PiholeClient(transport: missing, password: { "" })
        do {
            _ = try await missingClient.reachability()
            XCTFail("Expected not set up")
        } catch let problem as PiholeProblem {
            XCTAssertEqual(problem, .notSetUp)
            XCTAssertFalse(problem.title.localizedCaseInsensitiveContains("not live"))
            XCTAssertFalse(problem.detail.localizedCaseInsensitiveContains("everything"))
        } catch {
            XCTFail("Unexpected error")
        }
    }

    func testDeskUsesLastDayCountsAndNeverWrites() async throws {
        let transport = ScriptedPiholeTransport(steps: deskSteps)
        let client = PiholeClient(
            transport: transport,
            password: { "fixture-not-a-real-password" },
            now: { .streetFixtureNow }
        )
        let load = try await client.loadDesk(now: .streetFixtureNow)
        XCTAssertEqual(load.total, 12)
        XCTAssertEqual(load.blocked, 3)
        XCTAssertTrue(load.blockingEnabled)
        XCTAssertEqual(AdBlockerVoice.percentText(blocked: 3, total: 12), "25%")
        XCTAssertEqual(load.desk.blockingLine, "Blocked 25% of lookups in the last 24 hours.")
        XCTAssertEqual(load.desk.domains.map(\.name), ["ads.example.test", "news.example.test"])
        XCTAssertEqual(load.desk.queries.first?.domain, "ads.example.test")
        XCTAssertTrue(load.desk.services.isEmpty)
        XCTAssertFalse(load.desk.textLogFileEnabled)
        XCTAssertTrue(load.desk.listsUpdateKnown)
        let board = AdBlockerHome.ready(load, now: .streetFixtureNow)
        XCTAssertEqual(board.tile.percentText, "25%")
        XCTAssertEqual(board.tile.window, "Last 24 hours")
        XCTAssertEqual(board.status.headline, board.tile.line)
        XCTAssertNotEqual(board.status.headline, "Everything's good.")
        XCTAssertFalse(board.status.headline.localizedCaseInsensitiveContains("not live"))
        let paths = transport.sent.map(\.path)
        XCTAssertEqual(transport.sent.first?.path, "/api/auth")
        XCTAssertTrue(paths.contains { $0.hasPrefix("/api/history?from=") })
        XCTAssertTrue(paths.contains("/api/stats/top_domains?blocked=true&count=10"))
        XCTAssertTrue(paths.contains("/api/queries?length=50"))
        XCTAssertFalse(paths.contains { $0.contains("gravity") || $0.contains("restart") })
        let writes = transport.sent.filter { $0.method != "GET" }
        XCTAssertEqual(writes.map(\.path), ["/api/auth"])
        let described = transport.sent.map { String(describing: $0) }.joined(separator: " ")
        XCTAssertFalse(described.contains("fixture-not-a-real-password"))
        XCTAssertFalse(described.contains("sid-a"))
        let quiet = AdBlockerHome.offline(now: .streetFixtureNow)
        XCTAssertEqual(quiet.status.headline, "The ad blocker is not answering.")
        XCTAssertNotEqual(quiet.status.headline, "Everything's good.")
        let setup = AdBlockerHome.notSetUp(now: .streetFixtureNow)
        XCTAssertEqual(setup.status.headline, "The ad blocker is not set up.")
        XCTAssertFalse(setup.desk.blockingLine.localizedCaseInsensitiveContains("everything"))
    }

    func testDescriptionsLeaveOutTheSession() {
        let request = PiholeRequest(
            method: "GET",
            path: "/api/stats/summary",
            headers: [FTLSessionPolicy.sidHeader: "sid-secret"],
            body: Data("{\"password\":\"fixture-not-a-real-password\"}".utf8)
        )
        let text = String(describing: request)
        XCTAssertFalse(text.contains("sid-secret"))
        XCTAssertFalse(text.contains("fixture-not-a-real-password"))
    }

    private var deskSteps: [ScriptedPiholeTransport.Step] {
        let stamp = Int(Date.streetFixtureNow.timeIntervalSince1970) - 3_600
        return [
            .json(200, #"{"session":{"sid":"sid-a","validity":1800}}"#),
            .json(200, """
            {"queries":{"total":12,"blocked":3},"clients":{"active":4},\
            "gravity":{"last_update":1792000000}}
            """),
            .json(200, #"{"blocking":"enabled","timer":null}"#),
            .json(200, #"{"history":[{"timestamp":\#(stamp),"total":10,"blocked":4}]}"#),
            .json(200, #"{"domains":[{"domain":"news.example.test","count":9}]}"#),
            .json(200, #"{"domains":[{"domain":"ads.example.test","count":3}]}"#),
            .json(200, #"{"clients":[{"name":"Living room","count":9}]}"#),
            .json(200, """
            {"queries":[{"id":7,"time":1792421800,"domain":"ads.example.test",\
            "status":"GRAVITY","client":{"name":"Living room"}}]}
            """),
            .json(200, #"{"clients":[{"name":"Living room","comment":"Default"}]}"#),
            .json(200, #"{"groups":[{"name":"Default","comment":"The house"}]}"#),
            .json(200, #"{"domains":[{"domain":"ads.example.test","enabled":true}]}"#),
            .json(200, #"{"domains":[{"domain":"news.example.test","enabled":true}]}"#),
            .json(200, """
            {"lists":[{"address":"https://fixture.local/block.txt",\
            "comment":"House block list","enabled":true}]}
            """),
            .json(200, #"{"hosts":["192.0.2.20 printer.fixture.local"]}"#),
            .json(200, #"{"cnameRecords":["camera.fixture.local,printer.fixture.local"]}"#),
            .json(200, #"{"config":{"dns":{"queryLogging":false}}}"#),
        ]
    }

    private func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    private let emptyHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    private let abcHash = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
}

private func der(_ tag: UInt8, _ body: [UInt8]) -> [UInt8] {
    [tag, UInt8(body.count)] + body
}
