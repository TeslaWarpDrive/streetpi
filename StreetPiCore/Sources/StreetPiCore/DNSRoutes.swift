import Foundation

public struct DNSRoute: Sendable, Equatable {
    public var method: String
    public var path: String
    public var needsConfigAccess: Bool

    public init(method: String, path: String, needsConfigAccess: Bool) {
        self.method = method
        self.path = path
        self.needsConfigAccess = needsConfigAccess
    }
}

/// Pi-hole v6 paths. Reads stay. The only writes are blocking, deny, and allow.
/// No host, and nothing here opens a connection.
public enum DNSAPI {
    public static let routes: [DNSRoute] = [
        DNSRoute(method: "POST", path: "/api/auth", needsConfigAccess: false),
        DNSRoute(method: "DELETE", path: "/api/auth", needsConfigAccess: false),
        DNSRoute(method: "GET", path: "/api/stats/summary", needsConfigAccess: false),
        DNSRoute(method: "GET", path: "/api/history", needsConfigAccess: false),
        DNSRoute(method: "GET", path: "/api/dns/blocking", needsConfigAccess: false),
        DNSRoute(method: "POST", path: "/api/dns/blocking", needsConfigAccess: false),
        DNSRoute(method: "GET", path: "/api/stats/top_domains", needsConfigAccess: false),
        DNSRoute(method: "GET", path: "/api/stats/top_clients", needsConfigAccess: false),
        DNSRoute(method: "GET", path: "/api/queries", needsConfigAccess: false),
        DNSRoute(method: "GET", path: "/api/logs/dnsmasq", needsConfigAccess: false),
        DNSRoute(method: "GET", path: "/api/clients", needsConfigAccess: false),
        DNSRoute(method: "GET", path: "/api/groups", needsConfigAccess: false),
        DNSRoute(method: "GET", path: "/api/domains/deny/exact", needsConfigAccess: false),
        DNSRoute(method: "POST", path: "/api/domains/deny/exact", needsConfigAccess: false),
        DNSRoute(method: "GET", path: "/api/domains/allow/exact", needsConfigAccess: false),
        DNSRoute(method: "POST", path: "/api/domains/allow/exact", needsConfigAccess: false),
        DNSRoute(method: "GET", path: "/api/lists", needsConfigAccess: false),
        DNSRoute(method: "GET", path: "/api/config/dns/hosts", needsConfigAccess: false),
        DNSRoute(method: "GET", path: "/api/config/dns/cnameRecords", needsConfigAccess: false),
    ]

    public static var writePaths: [String] {
        routes.filter { $0.method == "POST" || $0.method == "DELETE" }.map(\.path)
    }
}
