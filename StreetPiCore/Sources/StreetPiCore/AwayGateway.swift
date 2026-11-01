import Foundation

/// The house's front door away from home. The client secret lives only in the Keychain.
/// Descriptions and mirrors never include the client id or the secret.
public struct AwayGatewaySettings: Sendable, Equatable, CustomStringConvertible, CustomDebugStringConvertible,
    CustomReflectable {
    /// Keychain account. The settings themselves are never stored here.
    public static let account = "away.gateway"
    public static let clientIDHeader = "CF-Access-Client-Id"
    public static let clientSecretHeader = "CF-Access-Client-Secret"
    /// The gateway lets through this one status page.
    public static let statusSlug = "house"

    private struct Wire: Codable {
        var url: String
        var clientID: String
        var clientSecret: String
    }

    /// The origin, with no path and no trailing slash.
    public let origin: String
    public let clientID: String
    public let clientSecret: String

    /// An https origin with no sign-in, path, query, or fragment, and credentials with no spaces.
    public init?(url text: String, clientID: String, clientSecret: String) {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        guard let parts = URLComponents(string: trimmed),
              parts.scheme?.lowercased() == "https",
              let host = parts.host, !host.isEmpty,
              parts.user == nil, parts.password == nil,
              parts.path.isEmpty, parts.query == nil, parts.fragment == nil,
              let id = Self.credential(clientID),
              let secret = Self.credential(clientSecret)
        else { return nil }
        origin = trimmed
        self.clientID = id
        self.clientSecret = secret
    }

    public init?(keychain data: Data) {
        guard let wire = try? JSONDecoder().decode(Wire.self, from: data) else { return nil }
        self.init(url: wire.url, clientID: wire.clientID, clientSecret: wire.clientSecret)
    }

    public func keychainData() throws -> Data {
        try JSONEncoder().encode(Wire(url: origin, clientID: clientID, clientSecret: clientSecret))
    }

    public var description: String { "AwayGatewaySettings(redacted)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: []) }

    public var healthURL: URL? { URL(string: origin + "/healthz") }
    /// Pi-hole paths already start with `/api`, so its base is the origin.
    public var piholeBase: URL? { URL(string: origin) }
    public var netdataBase: URL? { URL(string: origin + "/netdata") }
    public var kumaBase: URL? { URL(string: origin + "/kuma") }

    /// True only for https on this exact host and port.
    public func isGateway(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", url.user == nil, url.password == nil,
              let host = url.host?.lowercased(),
              let parts = URLComponents(string: origin),
              let gatewayHost = parts.host?.lowercased()
        else { return false }
        return host == gatewayHost && (url.port ?? 443) == (parts.port ?? 443)
    }

    /// The Access headers for a request. Any other host gets none.
    public func accessHeaders(for url: URL) -> [String: String] {
        guard isGateway(url) else { return [:] }
        return [Self.clientIDHeader: clientID, Self.clientSecretHeader: clientSecret]
    }

    private static func credential(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace) else { return nil }
        return trimmed
    }
}

/// What a gateway reply means before Pi-hole's own answer is read.
public enum AwayGatewayReply {
    /// A 429 is the edge rate limit. A 5xx from the edge means the house is out of reach for now.
    /// Pi-hole's own status codes, and Netdata's and Kuma's, pass through untouched.
    public static func problem(status: Int) -> PiholeProblem? {
        switch status {
        case 429:
            .rateLimited
        case 502, 503, 504, 520...530:
            .offline
        default:
            nil
        }
    }
}

/// Pi-hole through the gateway. The wrapped transport does the sending.
public struct AwayPiholeTransport: PiholeTransport {
    private let base: any PiholeTransport

    public init(base: any PiholeTransport) {
        self.base = base
    }

    public func send(_ request: PiholeRequest) async throws -> PiholeResponse {
        let response = try await base.send(request)
        if let problem = AwayGatewayReply.problem(status: response.status) {
            throw problem
        }
        return response
    }
}
