import Foundation
import StreetPiCore

/// One quick look for the Pi on the home network.
/// The charts agent must answer with its own JSON, so a captive portal does not count.
/// Any reply from the ad blocker counts, because the pinned certificate already proved who it is.
struct PiProbe: Sendable {
    private static let timeout: TimeInterval = 1.5

    private let http: LiveHTTPClient
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
        let endpoints = hosts.load()
        return await withTaskGroup(of: Bool.self) { group in
            group.addTask { await chartsAnswer(base: endpoints.netdata) }
            group.addTask { await blockerAnswers(base: endpoints.pihole) }
            for await answered in group where answered {
                group.cancelAll()
                return true
            }
            return false
        }
    }

    private func chartsAnswer(base: URL) async -> Bool {
        guard let url = LivePaths.url(base: base, path: "/api/v1/info"),
              let reply = try? await http.get(url, headers: ["Accept": "application/json"]),
              reply.status == 200
        else { return false }
        return (try? JSONDecoder().decode(ChartsAgent.self, from: reply.body)) != nil
    }

    private func blockerAnswers(base: URL) async -> Bool {
        guard let url = LivePaths.url(base: base, path: "/info/login") else { return false }
        return (try? await http.get(url, headers: ["Accept": "application/json"])) != nil
    }
}

private struct ChartsAgent: Decodable {
    var version: String
}
