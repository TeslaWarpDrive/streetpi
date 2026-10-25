import XCTest
import StreetPiCore
@testable import StreetPi

final class LivePiholeTransportTests: XCTestCase {
    func testWritesUseTheAPIRootAndKeepTheSessionHeader() async throws {
        let http = QueuedLiveHTTP()
        let base = try XCTUnwrap(URL(string: "https://fixture.test/api"))
        let transport = LivePiholeTransport(http: http, base: base)
        let sid = "fixture-not-a-real-session"
        let body = Data("{\"blocking\":false,\"timer\":30}".utf8)
        let response = try await transport.send(
            PiholeRequest(
                method: "POST",
                path: "/api/dns/blocking",
                headers: [FTLSessionPolicy.sidHeader: sid],
                body: body
            )
        )
        XCTAssertEqual(response.status, 200)
        let call = try XCTUnwrap(http.sent.first)
        XCTAssertEqual(call.method, "POST")
        XCTAssertEqual(call.url.absoluteString, "https://fixture.test/api/dns/blocking")
        XCTAssertEqual(call.headers["Content-Type"], "application/json")
        XCTAssertEqual(call.headers[FTLSessionPolicy.sidHeader], sid)
        XCTAssertEqual(call.body, body)
        XCTAssertNotEqual(call.url.host, "192.168.1.78")

        _ = try await transport.send(
            PiholeRequest(method: "POST", path: "/api/action/gravity", headers: [:], body: Data("{}".utf8))
        )
        XCTAssertEqual(http.sent.last?.url.absoluteString, "https://fixture.test/api/action/gravity")
    }

    func testAnUntrustedPiStaysInPlainWords() async throws {
        let base = try XCTUnwrap(URL(string: "https://fixture.test/api"))
        let transport = LivePiholeTransport(http: FailingLiveHTTP(), base: base)
        do {
            _ = try await transport.send(
                PiholeRequest(method: "GET", path: "/api/dns/blocking", headers: [:], body: nil)
            )
            XCTFail("Expected an untrusted Pi")
        } catch let problem as PiholeProblem {
            XCTAssertEqual(problem, .untrusted)
            XCTAssertTrue(problem.detail.contains("Nothing was changed"))
            XCTAssertFalse(problem.detail.contains("192.168"))
        } catch {
            XCTFail("Unexpected error")
        }
    }

    func testKeychainSessionAdapterDoesNotDescribeTheSession() throws {
        let memory = MemorySecretStore()
        let keychain = KeychainSession(store: memory)
        let adapter = KeychainFTLSession(keychain: keychain)
        let sid = "fixture-not-a-real-session"
        adapter.saveSID(sid)
        XCTAssertEqual(adapter.loadSID(), sid)
        XCTAssertFalse(String(describing: keychain).contains(sid))
        XCTAssertFalse(memory.description.contains(sid))
        adapter.clearSID()
        XCTAssertNil(adapter.loadSID())
    }
}

private final class QueuedLiveHTTP: LiveHTTPSending, @unchecked Sendable {
    struct Call {
        var method: String
        var url: URL
        var headers: [String: String]
        var body: Data?
    }

    private let lock = NSLock()
    private var calls: [Call] = []

    var sent: [Call] {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }

    func get(_ url: URL, headers: [String: String]) async throws -> LiveHTTPResponse {
        remember("GET", url, headers, nil)
    }

    func post(_ url: URL, headers: [String: String], body: Data?) async throws -> LiveHTTPResponse {
        remember("POST", url, headers, body)
    }

    func delete(_ url: URL, headers: [String: String]) async throws -> LiveHTTPResponse {
        remember("DELETE", url, headers, nil)
    }

    private func remember(
        _ method: String,
        _ url: URL,
        _ headers: [String: String],
        _ body: Data?
    ) -> LiveHTTPResponse {
        lock.lock()
        calls.append(Call(method: method, url: url, headers: headers, body: body))
        lock.unlock()
        return LiveHTTPResponse(status: 200, headers: [:], body: Data("{}".utf8))
    }
}

private struct FailingLiveHTTP: LiveHTTPSending {
    func get(_ url: URL, headers: [String: String]) async throws -> LiveHTTPResponse {
        throw LiveHTTPProblem.untrusted
    }

    func post(_ url: URL, headers: [String: String], body: Data?) async throws -> LiveHTTPResponse {
        throw LiveHTTPProblem.untrusted
    }

    func delete(_ url: URL, headers: [String: String]) async throws -> LiveHTTPResponse {
        throw LiveHTTPProblem.untrusted
    }
}
