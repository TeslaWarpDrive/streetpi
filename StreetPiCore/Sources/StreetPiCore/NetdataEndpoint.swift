import Foundation

public struct AgentHTTPResult: Sendable, Equatable {
    public var status: Int
    public var body: Data
    public var redirected: Bool

    public init(status: Int, body: Data, redirected: Bool = false) {
        self.status = status
        self.body = body
        self.redirected = redirected
    }
}

public enum NetdataProblem: Error, Sendable, Equatable {
    case offline
    case notUnderstood
}

/// Local Netdata agent. No login and no Netdata Cloud host.
public struct NetdataEndpoint: Sendable, Equatable {
    public var host: String
    public var port: Int

    public init(host: String, port: Int) {
        self.host = host
        self.port = port
    }

    public static let house = NetdataEndpoint(host: "192.168.1.78", port: 19999)

    public func url(pathAndQuery: String) -> URL? {
        guard port == 19999 else { return nil }
        guard let base = URL(string: "http://\(host):\(port)") else { return nil }
        return Self.joining(base: base, pathAndQuery: pathAndQuery)
    }

    /// Joins a settings base with a local API path. A cloud host or a redirect target is refused.
    public static func joining(base: URL, pathAndQuery: String) -> URL? {
        guard let host = base.host, isLocalAgentHost(host) else { return nil }
        guard let scheme = base.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        guard pathAndQuery.hasPrefix("/api/v1/") || pathAndQuery.hasPrefix("/api/v3/") else { return nil }
        guard !pathAndQuery.contains("://") else { return nil }
        guard var parts = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return nil }
        let pieces = pathAndQuery.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        parts.scheme = scheme
        parts.path = String(pieces[0])
        parts.query = pieces.count > 1 ? String(pieces[1]) : nil
        parts.fragment = nil
        parts.user = nil
        parts.password = nil
        return parts.url
    }

    public static func isLocalAgentHost(_ host: String) -> Bool {
        let name = host.lowercased()
        if name.contains("netdata.cloud") || name.contains("my-netdata.io") {
            return false
        }
        if name == "localhost" || name == "fixture.local" || name.hasSuffix(".local") {
            return true
        }
        let parts = name.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4, parts.allSatisfy({ (0...255).contains($0) }) else { return false }
        if parts[0] == 10 || parts[0] == 127 { return true }
        if parts[0] == 192 && parts[1] == 168 { return true }
        if parts[0] == 172 && (16...31).contains(parts[1]) { return true }
        return false
    }
}

public enum NetdataHistoryAPI {
    public static let chartsPath = "/api/v1/charts"
    public static let alarmsPath = "/api/v1/alarms"

    public static func dataPath(chart: String) -> String? {
        guard let encoded = queryToken(chart) else { return nil }
        return "/api/v1/data?chart=\(encoded)&after=-86400&points=24&group=average&format=json&options=seconds,jsonwrap"
    }

    public static func dataPathV3(context: String) -> String? {
        guard let encoded = queryToken(context) else { return nil }
        return "/api/v3/data?contexts=\(encoded)&after=-86400&points=24&format=json&options=jsonwrap"
    }

    private static func queryToken(_ value: String) -> String? {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+/?#")
        return value.addingPercentEncoding(withAllowedCharacters: allowed)
    }
}
