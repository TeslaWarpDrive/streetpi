import Foundation
import StreetPiCore

/// One quick look for the Pi on the home network.
/// Any reply from the ad blocker counts, because the pinned certificate already proved who it is.
struct PiProbe: Sendable {
    private static let timeout: TimeInterval = 1.5

    private let http: any LiveHTTPSending
    private let hosts: LiveHostStore

    init(hosts: LiveHostStore = LiveHostStore()) {
        self.hosts = hosts
        let configuration = LiveHTTPClient.sessionConfiguration()
        configuration.timeoutIntervalForRequest = Self.timeout
        configuration.timeoutIntervalForResource = Self.timeout
        http = LiveHTTPClient(store: hosts, configuration: configuration)
    }

    func piAnswers() async -> Bool {
        guard LiveReaderGate.opensSockets else { return false }
        return await Self.pinnedPiAnswers(http: http, base: hosts.load().pihole)
    }

    /// Only contact through the pinned Pi-hole client proves home. Plaintext charts cannot.
    static func pinnedPiAnswers(http: any LiveHTTPSending, base: URL) async -> Bool {
        guard let url = LivePaths.url(base: base, path: "/info/login") else { return false }
        return (try? await http.get(url, headers: ["Accept": "application/json"])) != nil
    }
}
