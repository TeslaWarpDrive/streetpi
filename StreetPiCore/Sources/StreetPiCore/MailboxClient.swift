import Foundation

/// An https mailbox address with no sign-in, query, or fragment in it.
public struct MailboxAddress: Sendable, Equatable {
    public let text: String

    public init?(text raw: String) {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        guard let parts = URLComponents(string: trimmed),
              parts.scheme?.lowercased() == "https",
              let host = parts.host, !host.isEmpty,
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil
        else { return nil }
        text = trimmed
    }

    func url(path: String) -> URL? {
        URL(string: text + path)
    }
}

/// The read token. Descriptions and mirrors never include it.
public struct MailboxToken: Sendable, Equatable, CustomStringConvertible, CustomDebugStringConvertible,
    CustomReflectable {
    /// Keychain account. The token itself is never stored here.
    public static let account = "mailbox.read-token"

    public let secret: String

    public init?(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace) else { return nil }
        secret = trimmed
    }

    public var description: String { "MailboxToken(redacted)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: []) }
}

/// Everything the app needs to read the mailbox.
public struct MailboxSetup: Sendable, Equatable {
    public var address: MailboxAddress
    public var token: MailboxToken

    public init(address: MailboxAddress, token: MailboxToken) {
        self.address = address
        self.token = token
    }
}

public struct MailboxReply: Sendable, Equatable, CustomStringConvertible {
    public var status: Int
    public var body: Data

    public init(status: Int, body: Data) {
        self.status = status
        self.body = body
    }

    public var description: String {
        "MailboxReply(status: \(status), bytes: \(body.count))"
    }
}

public protocol MailboxTransport: Sendable {
    func get(_ url: URL, token: MailboxToken) async throws -> MailboxReply
}

public enum MailboxProblem: Error, Sendable, Equatable {
    /// No connection, a timeout, or a mailbox error.
    case offline
    /// The mailbox refused the read token.
    case refused
    /// Nothing answers at this address.
    case wrongAddress
    /// A reply this version of the app cannot read.
    case notUnderstood
}

/// Reads the mailbox. A nil snapshot means the Pi has not pushed one yet.
public struct MailboxClient<Transport: MailboxTransport>: Sendable {
    static var latestPath: String { "/v1/latest" }
    static var historyPath: String { "/v1/history?limit=1" }

    public var transport: Transport
    public var setup: MailboxSetup

    public init(transport: Transport, setup: MailboxSetup) {
        self.transport = transport
        self.setup = setup
    }

    public func latest() async throws -> AwaySnapshot? {
        guard let body = try await read(Self.latestPath) else { return nil }
        return try decode(AwaySnapshot.self, from: body)
    }

    public func history() async throws -> AwaySnapshot? {
        guard let body = try await read(Self.historyPath) else { return nil }
        return try decode(AwayHistoryPage.self, from: body).snapshots.first
    }

    private func read(_ path: String) async throws -> Data? {
        guard let url = setup.address.url(path: path) else { throw MailboxProblem.wrongAddress }
        let reply = try await send(url)
        switch reply.status {
        case 200:
            return reply.body
        case 204:
            return nil
        case 401:
            throw MailboxProblem.refused
        case 404:
            throw MailboxProblem.wrongAddress
        default:
            throw MailboxProblem.offline
        }
    }

    private func send(_ url: URL) async throws -> MailboxReply {
        do {
            return try await transport.get(url, token: setup.token)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw MailboxProblem.offline
        }
    }

    private func decode<Value: Decodable>(_ type: Value.Type, from body: Data) throws -> Value {
        do {
            return try JSONDecoder().decode(type, from: body)
        } catch {
            throw MailboxProblem.notUnderstood
        }
    }
}
