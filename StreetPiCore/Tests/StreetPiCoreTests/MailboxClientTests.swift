import Foundation
import XCTest
@testable import StreetPiCore

private struct Scripted: MailboxTransport {
    final class Log: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: [(URL, MailboxToken)] = []

        func add(_ url: URL, _ token: MailboxToken) {
            lock.lock()
            stored.append((url, token))
            lock.unlock()
        }

        var urls: [String] {
            lock.lock()
            defer { lock.unlock() }
            return stored.map(\.0.absoluteString)
        }

        var tokens: [MailboxToken] {
            lock.lock()
            defer { lock.unlock() }
            return stored.map(\.1)
        }
    }

    var answer: @Sendable (URL) throws -> MailboxReply
    var log = Log()

    func get(_ url: URL, token: MailboxToken) async throws -> MailboxReply {
        log.add(url, token)
        return try answer(url)
    }
}

final class MailboxClientTests: XCTestCase {
    private let token = "fixture-not-a-real-read-token"

    private func setup() throws -> MailboxSetup {
        MailboxSetup(
            address: try XCTUnwrap(MailboxAddress(text: "https://mailbox.example.test/")),
            token: try XCTUnwrap(MailboxToken(text: token))
        )
    }

    private func fixture(_ name: String) throws -> Data {
        try Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json")))
    }

    private func client(_ transport: Scripted) throws -> MailboxClient<Scripted> {
        MailboxClient(transport: transport, setup: try setup())
    }

    func testAddressesMustBeHTTPS() {
        XCTAssertEqual(MailboxAddress(text: " https://mailbox.example.test/ ")?.text, "https://mailbox.example.test")
        XCTAssertNil(MailboxAddress(text: "http://mailbox.example.test"))
        XCTAssertNil(MailboxAddress(text: "mailbox.example.test"))
        XCTAssertNil(MailboxAddress(text: "https://user:pass@mailbox.example.test"))
        XCTAssertNil(MailboxAddress(text: "https://mailbox.example.test?token=x"))
        XCTAssertNil(MailboxAddress(text: ""))
    }

    func testTokensAreTrimmedAndRefuseSpaces() {
        XCTAssertEqual(MailboxToken(text: " abc\n")?.secret, "abc")
        XCTAssertNil(MailboxToken(text: "   "))
        XCTAssertNil(MailboxToken(text: "a b"))
    }

    func testTokenDescriptionsRedact() throws {
        let token = try XCTUnwrap(MailboxToken(text: self.token))
        var dumped = ""
        dump(token, to: &dumped)
        for text in [String(describing: token), String(reflecting: token), dumped] {
            XCTAssertFalse(text.contains(self.token))
        }
    }

    func testReadsTheNewestReportWithTheToken() async throws {
        let body = try fixture("away-live")
        let transport = Scripted { _ in MailboxReply(status: 200, body: body) }
        let snapshot = try await client(transport).latest()
        XCTAssertEqual(snapshot?.kind, .live)
        XCTAssertEqual(transport.log.urls, ["https://mailbox.example.test/v1/latest"])
        XCTAssertEqual(transport.log.tokens.first?.secret, token)
    }

    func testAsksForOneHistoryRow() async throws {
        let row = try XCTUnwrap(String(data: fixture("away-history"), encoding: .utf8))
        let body = Data("{\"snapshots\":[\(row)]}".utf8)
        let transport = Scripted { _ in MailboxReply(status: 200, body: body) }
        let snapshot = try await client(transport).history()
        XCTAssertEqual(snapshot?.kind, .history)
        XCTAssertEqual(transport.log.urls, ["https://mailbox.example.test/v1/history?limit=1"])
    }

    func testAnEmptyHistoryIsNil() async throws {
        let transport = Scripted { _ in MailboxReply(status: 200, body: Data("{\"snapshots\":[]}".utf8)) }
        let snapshot = try await client(transport).history()
        XCTAssertNil(snapshot)
    }

    func testNoContentMeansNoReportYet() async throws {
        let transport = Scripted { _ in MailboxReply(status: 204, body: Data()) }
        let snapshot = try await client(transport).latest()
        XCTAssertNil(snapshot)
    }

    func testMapsStatusesToProblems() async throws {
        let cases: [(Int, MailboxProblem)] = [
            (401, .refused), (404, .wrongAddress), (500, .offline), (530, .offline),
        ]
        for (status, problem) in cases {
            let transport = Scripted { _ in MailboxReply(status: status, body: Data()) }
            do {
                _ = try await client(transport).latest()
                XCTFail("Expected \(problem)")
            } catch {
                XCTAssertEqual(error as? MailboxProblem, problem)
            }
        }
    }

    func testAnUnreadableReportIsNotUnderstood() async throws {
        let transport = Scripted { _ in MailboxReply(status: 200, body: Data("{\"schema\":2}".utf8)) }
        do {
            _ = try await client(transport).latest()
            XCTFail("Expected a problem")
        } catch {
            XCTAssertEqual(error as? MailboxProblem, .notUnderstood)
        }
    }

    func testATransportFailureIsOffline() async throws {
        let transport = Scripted { _ in throw URLError(.timedOut) }
        do {
            _ = try await client(transport).latest()
            XCTFail("Expected a problem")
        } catch {
            XCTAssertEqual(error as? MailboxProblem, .offline)
        }
    }

    func testCancellationStaysCancellation() async throws {
        let transport = Scripted { _ in throw CancellationError() }
        do {
            _ = try await client(transport).latest()
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testRepliesDescribeOnlyTheirSize() {
        let reply = MailboxReply(status: 200, body: Data("secret-shaped".utf8))
        XCTAssertEqual(String(describing: reply), "MailboxReply(status: 200, bytes: 13)")
    }
}
