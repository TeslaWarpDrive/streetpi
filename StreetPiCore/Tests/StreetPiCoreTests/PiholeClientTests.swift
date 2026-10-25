import XCTest
@testable import StreetPiCore

final class PiholeClientTests: XCTestCase {
    func testHouseEndpointIsHTTPSOn443Only() throws {
        let url = PiholeEndpoint.house.url(pathAndQuery: "/api/auth")
        XCTAssertEqual(url?.scheme, "https")
        XCTAssertEqual(url?.host, PiholeEndpoint.house.host)
        XCTAssertTrue(url?.port == nil || url?.port == 443)
        XCTAssertNil(PiholeEndpoint(host: PiholeEndpoint.house.host, port: 80).url(pathAndQuery: "/api/auth"))
        let plain = try XCTUnwrap(URL(string: "http://192.168.1.78/api/auth"))
        let wrongPort = try XCTUnwrap(URL(string: "https://192.168.1.78:80/api/auth"))
        let secure = try XCTUnwrap(URL(string: "https://192.168.1.78/api/auth"))
        XCTAssertFalse(PiholeEndpoint.accepts(plain))
        XCTAssertFalse(PiholeEndpoint.accepts(wrongPort))
        XCTAssertTrue(PiholeEndpoint.accepts(secure))
        XCTAssertFalse(PiholeLiveLink.socketsEnabled)
    }

    func testTrustIsForThisPiOnly() {
        let certificate = PiholeCertificate.houseFixture
        let first = PiholeTrust.decide(presented: certificate, pinnedFingerprint: nil, forHost: certificate.host)
        guard case .needsConsent(let explanation) = first else {
            return XCTFail("Expected a trust step")
        }
        XCTAssertTrue(explanation.contains("pi.hole"))
        XCTAssertTrue(explanation.contains("2055"))
        XCTAssertTrue(explanation.contains("this phone"))
        XCTAssertTrue(explanation.contains("SHA256:fixture-not-a-real-cert"))
        XCTAssertFalse(explanation.contains("192.168"))
        XCTAssertFalse(explanation.localizedCaseInsensitiveContains("password"))
        let trusted = PiholeTrust.decide(
            presented: certificate,
            pinnedFingerprint: certificate.sha256Fingerprint,
            forHost: certificate.host
        )
        XCTAssertEqual(trusted, .trusted)
        var other = certificate
        other.sha256Fingerprint = "SHA256:different"
        let mismatch = PiholeTrust.decide(
            presented: other,
            pinnedFingerprint: certificate.sha256Fingerprint,
            forHost: certificate.host
        )
        guard case .rejected = mismatch else {
            return XCTFail("Expected a rejection")
        }
        var wrongName = certificate
        wrongName.commonName = "example.test"
        guard case .rejected = PiholeTrust.decide(
            presented: wrongName,
            pinnedFingerprint: nil,
            forHost: certificate.host
        ) else {
            return XCTFail("Expected a rejection")
        }
        guard case .rejected = PiholeTrust.decide(
            presented: certificate,
            pinnedFingerprint: nil,
            forHost: "fixture.local"
        ) else {
            return XCTFail("Expected a rejection")
        }
    }

    func testPauseResumeBlockAndAllowBodies() throws {
        let pause = try XCTUnwrap(PiholeWrites.pause(seconds: 300))
        XCTAssertEqual(pause.path, "/api/dns/blocking")
        XCTAssertTrue(pause.body == Data("{\"blocking\":false,\"timer\":300}".utf8))
        XCTAssertNil(PiholeWrites.pause(seconds: 0))
        XCTAssertTrue(PiholeWrites.resume().body == Data("{\"blocking\":true,\"timer\":null}".utf8))
        let block = try XCTUnwrap(PiholeWrites.block(domain: "Ads.Example.Test"))
        XCTAssertEqual(block.path, "/api/domains/deny/exact")
        XCTAssertTrue(block.body == Data("{\"domain\":\"ads.example.test\",\"enabled\":true}".utf8))
        XCTAssertEqual(PiholeWrites.allow(domain: "news.example.test")?.path, "/api/domains/allow/exact")
        XCTAssertNil(PiholeWrites.allow(domain: "not a domain"))
        XCTAssertFalse(String(describing: pause).contains("fixture"))
    }

    func testOneSessionIsReusedAndRefreshedOn401() async throws {
        let transport = ScriptedPiholeTransport(steps: [
            .json(200, #"{"session":{"sid":"sid-a","validity":1800}}"#),
            .json(401, "{}"),
            .json(200, #"{"session":{"sid":"sid-b","validity":1800}}"#),
            .json(200, #"{"queries":{"total":12,"blocked":3}}"#),
            .json(200, #"{"queries":{"total":12,"blocked":3}}"#),
        ])
        let client = PiholeClient(transport: transport, password: { Self.fixturePassword }, now: { .streetFixtureNow })
        let summary = try await client.summary()
        XCTAssertEqual(summary.queriesToday, 12)
        XCTAssertEqual(summary.blockedToday, 3)
        _ = try await client.summary()
        let trace = transport.sent.map { "\($0.method) \($0.path)" }.joined(separator: " | ")
        let expected = [
            "POST /api/auth",
            "GET /api/stats/summary",
            "POST /api/auth",
            "GET /api/stats/summary",
            "GET /api/stats/summary",
        ].joined(separator: " | ")
        XCTAssertEqual(trace, expected)
        let auths = transport.sent.filter { $0.method == "POST" && $0.path == "/api/auth" }
        let gets = transport.sent.filter { $0.method == "GET" }
        XCTAssertEqual(auths.count, 2)
        XCTAssertEqual(gets.count, 3)
        XCTAssertTrue(gets.last?.headers[FTLSessionPolicy.sidHeader] == "sid-b")
        let described = auths.map { String(describing: $0) }.joined(separator: " ")
        XCTAssertFalse(described.contains("fixture"))
        let body = try XCTUnwrap(auths.first?.body)
        let decoded = try JSONDecoder().decode(AuthRequest.self, from: body)
        XCTAssertTrue(decoded.password == Self.fixturePassword)
        XCTAssertEqual(String(describing: decoded), "AuthRequest(password: redacted)")
        XCTAssertEqual(FTLSessionPolicy.maximumSessions, 16)
        XCTAssertEqual(FTLSessionPolicy.validitySeconds, 1_800)
        XCTAssertEqual(FTLSessionPolicy.sidHeader, "X-FTL-SID")
    }

    func testSessionExpiresAndBackgroundSignsOut() async throws {
        let clock = Clock(date: .streetFixtureNow)
        let transport = ScriptedPiholeTransport(steps: [
            .json(200, #"{"session":{"sid":"sid-a","validity":1800}}"#),
            .json(200, #"{"blocking":"enabled","timer":null}"#),
            .json(200, #"{"session":{"sid":"sid-b","validity":1800}}"#),
            .json(200, #"{"blocking":"disabled","timer":30}"#),
            .json(204, "{}"),
        ])
        let client = PiholeClient(transport: transport, password: { Self.fixturePassword }, now: { clock.date })
        let first = try await client.blocking()
        XCTAssertTrue(first.enabled)
        clock.date = Date.streetFixtureNow.addingTimeInterval(1_801)
        let second = try await client.blocking()
        XCTAssertFalse(second.enabled)
        XCTAssertEqual(second.pause, .thirtySeconds)
        await client.appDidEnterBackground()
        let delete = transport.sent.last
        XCTAssertEqual(delete?.method, "DELETE")
        XCTAssertEqual(delete?.path, "/api/auth")
        XCTAssertTrue(delete?.headers[FTLSessionPolicy.sidHeader] == "sid-b")
        let auths = transport.sent.filter { $0.path == "/api/auth" && $0.method == "POST" }
        XCTAssertEqual(auths.count, 2)
    }

    func testForbiddenAndOfflineStayPlain() async {
        let refused = ScriptedPiholeTransport(steps: [
            .json(200, #"{"session":{"sid":"sid-a","validity":1800}}"#),
            .json(403, #"{"error":{"key":"forbidden"}}"#),
        ])
        let client = PiholeClient(transport: refused, password: { Self.fixturePassword }, now: { .streetFixtureNow })
        do {
            _ = try await client.pause(seconds: 30)
            XCTFail("Expected a refusal")
        } catch let problem as PiholeProblem {
            XCTAssertEqual(problem, .refused)
            XCTAssertFalse(problem.detail.contains("403"))
            XCTAssertFalse(problem.detail.localizedCaseInsensitiveContains("sudo"))
            XCTAssertTrue(problem.detail.contains("Nothing was changed"))
        } catch {
            XCTFail("Unexpected error")
        }
        let offline = ScriptedPiholeTransport(steps: [.fail(.offline)])
        let offlineClient = PiholeClient(
            transport: offline,
            password: { Self.fixturePassword },
            now: { .streetFixtureNow }
        )
        do {
            _ = try await offlineClient.resume()
            XCTFail("Expected offline")
        } catch let problem as PiholeProblem {
            XCTAssertEqual(problem, .offline)
            XCTAssertTrue(problem.title.contains("not answering"))
        } catch {
            XCTFail("Unexpected error")
        }
    }

    func testCertificateNotAfterIsReadFromTheBytes() {
        let validity = der(0x30, der(0x17, ascii("250101000000Z")) + der(0x18, ascii("20551231235959Z")))
        let version = der(0xA0, der(0x02, [0x02]))
        let tbs = der(0x30, version + der(0x02, [0x01]) + der(0x30, []) + der(0x30, []) + validity)
        let certificate = der(0x30, tbs + der(0x30, []) + der(0x03, [0x00]))
        let date = CertificateValidity.notAfter(der: Data(certificate))
        var calendar = Calendar(identifier: .gregorian)
        if let zone = TimeZone(secondsFromGMT: 0) {
            calendar.timeZone = zone
        }
        XCTAssertEqual(calendar.component(.year, from: date ?? .distantPast), 2_055)
        XCTAssertEqual(calendar.component(.month, from: date ?? .distantPast), 12)
        XCTAssertEqual(calendar.component(.day, from: date ?? .distantPast), 31)
        XCTAssertNil(CertificateValidity.notAfter(der: Data([0x00])))
    }

    func testReadsDecodeRealShapes() throws {
        let ending = Date.streetFixtureNow
        let stamp = Int(ending.timeIntervalSince1970 - 86_400 + 3_605)
        let history = Data(
            #"{"history":[{"timestamp":\#(stamp),"total":10,"blocked":4}]}"#.utf8
        )
        let day = try PiholeDecode.history(from: history, ending: ending)
        XCTAssertEqual(day[1].blocked, 4)
        XCTAssertEqual(day[1].allowed, 6)
        XCTAssertEqual(day[0].allowed, 0)
        let queryJSON = """
        {"queries":[{"id":1,"time":1792421880,"domain":"ads.example.test",\
        "status":"GRAVITY","client":{"name":"Living room"}}]}
        """
        let queries = try PiholeDecode.queries(from: Data(queryJSON.utf8))
        XCTAssertEqual(queries.first?.outcome, .blocked)
        XCTAssertEqual(queries.first?.client, "Living room")
        let hosts = try PiholeDecode.hosts(from: Data(
            #"{"hosts":["192.0.2.20 printer.fixture.local"]}"#.utf8
        ))
        XCTAssertEqual(hosts.first?.name, "printer.fixture.local")
        XCTAssertFalse(hosts.first?.detail.contains("192.168") ?? true)
        let cnames = try PiholeDecode.cnames(from: Data(
            #"{"cnameRecords":["camera.fixture.local,printer.fixture.local"]}"#.utf8
        ))
        XCTAssertEqual(cnames.first?.name, "camera.fixture.local")
        XCTAssertEqual(cnames.first?.detail, "printer.fixture.local")
        let listJSON = """
        {"lists":[{"address":"https://fixture.local/block.txt","comment":"House block list","enabled":true}]}
        """
        let lists = try PiholeDecode.lists(from: Data(listJSON.utf8))
        XCTAssertEqual(lists.first?.host, "fixture.local")
        XCTAssertEqual(lists.first?.statusWord, "On")
    }

    private static let fixturePassword = "fixture-not-a-real-password"
}

private func der(_ tag: UInt8, _ body: [UInt8]) -> [UInt8] {
    [tag, UInt8(body.count)] + body
}

private func ascii(_ text: String) -> [UInt8] {
    Array(text.utf8)
}

private final class Clock: @unchecked Sendable {
    var date: Date

    init(date: Date) {
        self.date = date
    }
}
