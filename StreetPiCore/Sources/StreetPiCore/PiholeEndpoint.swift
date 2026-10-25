import Foundation

/// The house Pi-hole. HTTPS on port 443 only. This value is not a connection.
public struct PiholeEndpoint: Sendable, Equatable {
    public var host: String
    public var port: Int

    public init(host: String, port: Int) {
        self.host = host
        self.port = port
    }

    public static let house = PiholeEndpoint(host: "192.168.1.78", port: 443)

    public func url(pathAndQuery: String) -> URL? {
        guard port == 443, pathAndQuery.hasPrefix("/") else { return nil }
        return URL(string: "https://\(host):\(port)\(pathAndQuery)")
    }

    public static func accepts(_ url: URL) -> Bool {
        guard url.scheme == "https" else { return false }
        if let port = url.port, port != 443 {
            return false
        }
        return true
    }
}

/// StreetPiCore never opens a socket. Tests keep this false. The app dials on its own, and only outside tests.
public enum PiholeLiveLink {
    public static let socketsEnabled = false
}
