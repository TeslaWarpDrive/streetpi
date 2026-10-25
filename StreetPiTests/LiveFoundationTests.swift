import Foundation
import Security
import StreetPiCore
import XCTest
@testable import StreetPi

final class LiveFoundationTests: XCTestCase {
    override func tearDown() {
        FixtureHTTPProtocol.reset()
        super.tearDown()
    }

    func testHouseDefaultsStayInSettings() throws {
        let box = try DefaultsBox()
        defer { box.close() }
        let store = LiveHostStore(defaults: box.defaults)
        XCTAssertEqual(store.piholeText(), "https://192.168.1.78/api")
        XCTAssertEqual(store.netdataText(), "http://192.168.1.78:19999")
        XCTAssertEqual(store.uptimeKumaText(), "http://192.168.1.78:3001")
        XCTAssertEqual(store.pinText(), LiveHouse.spkiSHA256)
        XCTAssertEqual(store.load(), .house)
        let digest = try XCTUnwrap(Data(base64Encoded: LiveHouse.spkiSHA256))
        XCTAssertEqual(digest.count, 32)
        XCTAssertEqual(
            CertificatePinner.changedCertificatePrompt,
            "The ad blocker's security certificate changed, trust the new one?"
        )
    }

    func testSettingsCanReplaceHostsAndPin() throws {
        let box = try DefaultsBox()
        defer { box.close() }
        let store = LiveHostStore(defaults: box.defaults)
        try store.save(
            pihole: "https://10.0.0.8/api",
            netdata: "http://10.0.0.8:19999",
            uptimeKuma: "http://10.0.0.8:3001"
        )
        let pin = Data(repeating: 7, count: 32).base64EncodedString()
        try store.savePin(pin)
        let loaded = store.load()
        XCTAssertEqual(loaded.pihole.absoluteString, "https://10.0.0.8/api")
        XCTAssertEqual(loaded.netdata.absoluteString, "http://10.0.0.8:19999")
        XCTAssertEqual(loaded.uptimeKuma.absoluteString, "http://10.0.0.8:3001")
        XCTAssertEqual(loaded.piholeHost, "10.0.0.8")
        XCTAssertEqual(store.pinText(), pin)
        store.clearPin()
        XCTAssertNil(store.loadPin())
        XCTAssertEqual(store.pinText(), LiveHouse.spkiSHA256)
    }

    func testBadSettingsAreRejected() throws {
        let box = try DefaultsBox()
        defer { box.close() }
        let store = LiveHostStore(defaults: box.defaults)
        XCTAssertThrowsError(
            try store.save(
                pihole: "http://10.0.0.8/api",
                netdata: "http://10.0.0.8:19999",
                uptimeKuma: "http://10.0.0.8:3001"
            )
        ) { error in
            XCTAssertEqual(error as? LiveHostError, .invalidAddress)
        }
        XCTAssertThrowsError(
            try store.save(
                pihole: "https://fixture-user:fixture-password@10.0.0.8/api",
                netdata: "http://10.0.0.8:19999",
                uptimeKuma: "http://10.0.0.8:3001"
            )
        ) { error in
            XCTAssertEqual(error as? LiveHostError, .invalidAddress)
        }
        XCTAssertThrowsError(try store.savePin("not-a-pin")) { error in
            XCTAssertEqual(error as? LiveHostError, .invalidPin)
        }
        box.defaults.set("not a url", forKey: LiveHostStore.piholeKey)
        XCTAssertEqual(store.load().pihole, LiveEndpoints.house.pihole)
    }

    func testPathsJoinOnAFixtureHost() throws {
        let base = try XCTUnwrap(URL(string: "https://fixture.test/api"))
        let login = LivePaths.url(base: base, path: "/info/login")
        XCTAssertEqual(login?.absoluteString, "https://fixture.test/api/info/login")
        let root = try XCTUnwrap(URL(string: "http://fixture.test:19999"))
        let chart = LivePaths.url(base: root, path: "api/v1/data?chart=system.cpu")
        XCTAssertEqual(chart?.absoluteString, "http://fixture.test:19999/api/v1/data?chart=system.cpu")
    }

    func testGetPostAndDeleteUseTheMock() async throws {
        FixtureHTTPProtocol.reset()
        let client = makeClient()
        let url = try XCTUnwrap(URL(string: "https://fixture.test/probe"))
        FixtureHTTPProtocol.reply = FixtureReply(status: 200, headers: ["X-Mark": "ok"], body: Data("ready".utf8))
        let fetched = try await client.get(url, headers: ["Accept": "application/json"])
        XCTAssertEqual(fetched.status, 200)
        XCTAssertEqual(fetched.headers["X-Mark"], "ok")
        XCTAssertEqual(fetched.body, Data("ready".utf8))
        XCTAssertFalse(fetched.description.contains("ready"))

        let postedBody = Data("{\"note\":\"fixture\"}".utf8)
        FixtureHTTPProtocol.reply = FixtureReply(status: 201, headers: [:], body: Data())
        let posted = try await client.post(url, headers: ["Content-Type": "application/json"], body: postedBody)
        XCTAssertEqual(posted.status, 201)

        FixtureHTTPProtocol.reply = FixtureReply(status: 204, headers: [:], body: Data())
        let removed = try await client.delete(url, headers: ["X-FTL-SID": "fixture-not-a-real-session"])
        XCTAssertEqual(removed.status, 204)
        XCTAssertFalse(removed.description.contains("fixture-not-a-real-session"))

        let seen = FixtureHTTPProtocol.requests()
        XCTAssertEqual(seen.map(\.method), ["GET", "POST", "DELETE"])
        XCTAssertEqual(seen.map(\.host), ["fixture.test", "fixture.test", "fixture.test"])
        XCTAssertEqual(seen[0].headers["Accept"], "application/json")
        XCTAssertEqual(seen[1].headers["Content-Type"], "application/json")
        XCTAssertEqual(seen[1].body, postedBody)
        XCTAssertEqual(seen[2].headers["X-FTL-SID"], "fixture-not-a-real-session")
        XCTAssertTrue(seen.allSatisfy { $0.host != "192.168.1.78" })
    }

    func testAPasswordInTheAddressIsRefused() async throws {
        FixtureHTTPProtocol.reset()
        let client = makeClient()
        let url = try XCTUnwrap(URL(string: "https://fixture-user:fixture-password@fixture.test/api"))
        do {
            _ = try await client.get(url)
            XCTFail("An address with a password must be refused")
        } catch LiveHTTPProblem.badAddress {
            XCTAssertTrue(FixtureHTTPProtocol.requests().isEmpty)
        } catch {
            XCTFail("Unexpected refusal")
        }
    }

    func testCreatingTheClientDoesNotSend() throws {
        FixtureHTTPProtocol.reset()
        let box = try DefaultsBox()
        defer { box.close() }
        let configuration = LiveHTTPClient.sessionConfiguration()
        configuration.protocolClasses = [FixtureHTTPProtocol.self]
        let client = LiveHTTPClient(store: LiveHostStore(defaults: box.defaults), configuration: configuration)
        XCTAssertEqual(client.pinner.trustedHost(), LiveHouse.host)
        XCTAssertEqual(client.pinner.trustedPin(), LiveHouse.spkiSHA256)
        XCTAssertTrue(FixtureHTTPProtocol.requests().isEmpty)
        client.apply(LiveHostStore(defaults: box.defaults))
        XCTAssertTrue(FixtureHTTPProtocol.requests().isEmpty)
    }

    func testPinMatchesGeneratedCertificatesAndCanChange() throws {
        let p384 = try FixtureCertificate.make(FixtureCertificate.p384Der)
        let p256 = try FixtureCertificate.make(FixtureCertificate.p256Der)
        XCTAssertEqual(CertificatePinner.spkiSHA256Base64(of: p384), FixtureCertificate.p384Pin)
        XCTAssertEqual(CertificatePinner.spkiSHA256Base64(of: p256), FixtureCertificate.p256Pin)

        let pinner = CertificatePinner(spkiSHA256Base64: FixtureCertificate.p384Pin, host: "192.168.1.78")
        XCTAssertTrue(pinner.accepts(certificate: p384, host: "192.168.1.78."))
        XCTAssertFalse(pinner.accepts(certificate: p256, host: "192.168.1.78"))
        XCTAssertFalse(pinner.accepts(certificate: p384, host: "10.0.0.9"))

        pinner.replacePin(Data(repeating: 0, count: 32).base64EncodedString())
        XCTAssertFalse(pinner.accepts(certificate: p384, host: "192.168.1.78"))
        pinner.replacePin("sha256/\(FixtureCertificate.p384Pin)")
        XCTAssertTrue(pinner.accepts(certificate: p384, host: "192.168.1.78"))
        pinner.replaceHost("Fixture.Test")
        pinner.replacePin(FixtureCertificate.p256Pin)
        XCTAssertTrue(pinner.accepts(certificate: p256, host: "fixture.test"))
    }

    func testKeychainSessionNeverDescribesTheSecrets() throws {
        let memory = MemorySecretStore()
        let session = KeychainSession(store: memory)
        XCTAssertFalse(try session.hasAppPassword())
        XCTAssertFalse(try session.hasSessionID())
        XCTAssertThrowsError(try session.saveAppPassword(""))
        XCTAssertThrowsError(try session.saveSessionID(""))
        let password = "fixture-not-a-real-password"
        let sessionID = "fixture-not-a-real-session"
        try session.saveAppPassword(password)
        try session.saveSessionID(sessionID)
        XCTAssertEqual(try session.loadAppPassword(), password)
        XCTAssertEqual(try session.loadSessionID(), sessionID)
        XCTAssertTrue(try session.hasAppPassword())
        XCTAssertTrue(try session.hasSessionID())
        let texts = [String(describing: session), String(reflecting: session), memory.description]
        for text in texts {
            XCTAssertFalse(text.contains(password))
            XCTAssertFalse(text.contains(sessionID))
            XCTAssertFalse(text.contains("fixture"))
        }
        XCTAssertEqual(String(describing: session), "KeychainSession")
        try session.deleteAppPassword()
        try session.deleteSessionID()
        XCTAssertNil(try session.loadAppPassword())
        XCTAssertNil(try session.loadSessionID())
        XCTAssertEqual(memory.description, "MemorySecretStore(accounts: 0)")
    }
}

private struct FixtureReply {
    var status: Int
    var headers: [String: String]
    var body: Data
}

private struct SeenRequest: Equatable {
    var method: String
    var host: String
    var headers: [String: String]
    var body: Data
}

private final class FixtureHTTPProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var reply = FixtureReply(status: 204, headers: [:], body: Data())
    nonisolated(unsafe) static var seen: [SeenRequest] = []
    private static let lock = NSLock()

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let reply = Self.reply
        let seen = SeenRequest(
            method: request.httpMethod ?? "",
            host: request.url?.host ?? "",
            headers: request.allHTTPHeaderFields ?? [:],
            body: Self.body(of: request)
        )
        Self.lock.lock()
        Self.seen.append(seen)
        Self.lock.unlock()
        guard let client else { return }
        if seen.host == "192.168.1.78" {
            client.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
            return
        }
        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: reply.status,
                httpVersion: "HTTP/1.1",
                headerFields: reply.headers
              )
        else {
            client.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client.urlProtocol(self, didLoad: reply.body)
        client.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func requests() -> [SeenRequest] {
        lock.lock()
        defer { lock.unlock() }
        return seen
    }

    static func reset() {
        lock.lock()
        seen = []
        reply = FixtureReply(status: 204, headers: [:], body: Data())
        lock.unlock()
    }

    private static func body(of request: URLRequest) -> Data {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var collected = Data()
        let capacity = 256
        var buffer = [UInt8](repeating: 0, count: capacity)
        var reads = 0
        while stream.hasBytesAvailable, reads < 64 {
            reads += 1
            let count = buffer.withUnsafeMutableBytes { raw -> Int in
                guard let base = raw.baseAddress else { return 0 }
                return stream.read(base.assumingMemoryBound(to: UInt8.self), maxLength: capacity)
            }
            if count <= 0 { break }
            collected.append(buffer, count: count)
        }
        return collected
    }
}

private func makeClient() -> LiveHTTPClient {
    let configuration = LiveHTTPClient.sessionConfiguration()
    configuration.protocolClasses = [FixtureHTTPProtocol.self]
    configuration.timeoutIntervalForRequest = 2
    configuration.timeoutIntervalForResource = 2
    return LiveHTTPClient(pinner: CertificatePinner(host: "fixture.test"), configuration: configuration)
}

private struct DefaultsBox {
    let name: String
    let defaults: UserDefaults

    init() throws {
        name = "streetpi.live.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: name) else {
            throw LiveHostError.invalidAddress
        }
        self.defaults = defaults
        defaults.removePersistentDomain(forName: name)
    }

    func close() {
        defaults.removePersistentDomain(forName: name)
    }
}

private enum FixtureCertificate {
    static let p384Pin = "Tp3B3VKE4YQWt6jae2dJuAiGx9DR2507jR/VsN4LAtE="
    static let p256Pin = "vovbqBpzXGt+3mYmZua6Ajys9jopuOAEh+wmvM9nQIo="
    static let p384Der = [
        "MIIBtTCCATygAwIBAgIUAxtgL+LZbo2u96DVnRR1d5W4zOswCgYIKoZIzj0EAwIw",
        "EjEQMA4GA1UEAwwHcGkuaG9sZTAeFw0yNjEwMjUwNzI0NDRaFw0yNjEwMjYwNzI0",
        "NDRaMBIxEDAOBgNVBAMMB3BpLmhvbGUwdjAQBgcqhkjOPQIBBgUrgQQAIgNiAAT3",
        "w6qZ+izGFtYX2zfK2cmmUmgJuUROtkkaL2n54E7iK6tYCWgGzdh81ijD/GvZ4cCs",
        "/TOQzv7Zd5yfCGP2hE1l2ioQu4F5QOq7LYNC06CDJN3X96xSXw6NIjnwGU1PfP2j",
        "UzBRMB0GA1UdDgQWBBQGx4DDOhwAB4vzpEUoq09R/4upVDAfBgNVHSMEGDAWgBQG",
        "x4DDOhwAB4vzpEUoq09R/4upVDAPBgNVHRMBAf8EBTADAQH/MAoGCCqGSM49BAMC",
        "A2cAMGQCMB8M/7hlpDbCbiN/FvfywJXOrNUqY3fyDpgOBtYHb/npcvrnYohwxWOU",
        "un9rDrN5twIwP2uJEgTWokuKQT8Im6HISTGfMcs6bkeddGxG+EGqnh+sY4ZH6YmG",
        "BB4c53cR0EfW",
    ].joined()
    static let p256Der = [
        "MIIBgzCCASmgAwIBAgIUVpE3RlAcs4gqXsyhQr4VlkrP3lowCgYIKoZIzj0EAwIw",
        "FzEVMBMGA1UEAwwMZml4dHVyZS50ZXN0MB4XDTI2MTAyNTA3Mjc1NVoXDTI2MTAy",
        "NjA3Mjc1NVowFzEVMBMGA1UEAwwMZml4dHVyZS50ZXN0MFkwEwYHKoZIzj0CAQYI",
        "KoZIzj0DAQcDQgAEQZL30DZ9JgJI81uqbSYgvk+6pOCA0yihMO/ta5vKnCRH8Fwk",
        "HyJYZwIPSpfv35lB7Xa+lFHFNREHhKUqCFdR1aNTMFEwHQYDVR0OBBYEFNRFj9PR",
        "m8CgVG6494QMo3W/PJq9MB8GA1UdIwQYMBaAFNRFj9PRm8CgVG6494QMo3W/PJq9",
        "MA8GA1UdEwEB/wQFMAMBAf8wCgYIKoZIzj0EAwIDSAAwRQIgMzzD7HipYF8hfbLK",
        "IgmoR+ci1vZLDxK7/KR86cgHWesCIQCkznPLiyo02eQbZD7v/4Ci5xEcGIKD6qKH",
        "tLi4RuxSqw==",
    ].joined()

    static func make(_ base64: String) throws -> SecCertificate {
        let der = try XCTUnwrap(Data(base64Encoded: base64))
        return try XCTUnwrap(SecCertificateCreateWithData(nil, der as CFData))
    }
}
