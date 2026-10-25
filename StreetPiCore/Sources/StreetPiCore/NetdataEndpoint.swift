import Foundation

public struct NetdataReply: Sendable, Equatable {
    public var status: Int
    public var body: Data

    public init(status: Int, body: Data) {
        self.status = status
        self.body = body
    }
}

public protocol NetdataTransport: Sendable {
    func get(_ path: String) async throws -> NetdataReply
}

public enum NetdataProblem: Error, Sendable, Equatable {
    case offline
    case redirected
    case notUnderstood

    public var sentence: String {
        switch self {
        case .offline, .redirected:
            HouseReadingCopy.unreachableTitle
        case .notUnderstood:
            HouseReadingCopy.unreadableTitle
        }
    }
}

/// The charts agent on the home network. HTTP, no login, never Netdata Cloud.
public struct NetdataEndpoint: Sendable, Equatable, Codable {
    public var host: String
    public var port: Int

    public init(host: String, port: Int) {
        self.host = host
        self.port = port
    }

    public static let houseDefault = NetdataEndpoint(host: "192.168.1.78", port: 19999)

    public var display: String {
        port == 19999 ? host : "\(host):\(port)"
    }

    public var isLocalAgent: Bool {
        let name = host.lowercased()
        if name.isEmpty || name.contains(" ") || name.contains("/") || name.contains("@") {
            return false
        }
        if name.contains("netdata.cloud") || name.contains("my-netdata.io") {
            return false
        }
        return true
    }

    public func url(for path: String) -> URL? {
        guard isLocalAgent, path.hasPrefix("/") else { return nil }
        guard let url = URL(string: "http://\(host):\(port)\(path)"),
              let found = url.host?.lowercased(),
              found == host.lowercased()
        else { return nil }
        if found.contains("netdata.cloud") || found.contains("my-netdata.io") {
            return nil
        }
        return url
    }

    public static func parsed(_ text: String) -> NetdataEndpoint? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let withScheme = trimmed.contains("://") ? trimmed : "http://\(trimmed)"
        guard let parts = URLComponents(string: withScheme),
              parts.user == nil,
              parts.password == nil,
              let host = parts.host,
              !host.isEmpty
        else { return nil }
        if let scheme = parts.scheme, scheme != "http" {
            return nil
        }
        let port = parts.port ?? 19999
        guard (1...65_535).contains(port) else { return nil }
        let endpoint = NetdataEndpoint(host: host, port: port)
        guard endpoint.isLocalAgent, endpoint.url(for: "/api/v1/info") != nil else { return nil }
        return endpoint
    }
}

extension NetdataAPI {
    /// One latest point from the local agent. `version` is 1 or 2.
    public static func dataPath(chart: String, version: Int = 1) -> String {
        let safeVersion = version == 2 ? 2 : 1
        let encoded = chart.addingPercentEncoding(withAllowedCharacters: querySet) ?? chart
        let query = "chart=\(encoded)&after=-5&points=1&group=average&format=json&options=jsonwrap"
        return "/api/v\(safeVersion)/data?\(query)"
    }

    private static let querySet = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&+=?#"))
}
