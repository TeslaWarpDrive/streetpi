import Foundation
import StreetPiCore

struct PiMeterRefresh: Sendable {
    var client: LiveHTTPClient
    var base: URL

    func load() async -> Result<NetdataMeters, NetdataProblem>? {
        let reader = NetdataReader(transport: NetdataLiveTransport(client: client, base: base))
        do {
            return .success(try await reader.load())
        } catch is CancellationError {
            return nil
        } catch let problem as NetdataProblem {
            return .failure(problem)
        } catch {
            return .failure(.offline)
        }
    }
}

struct NetdataLiveTransport: NetdataTransport {
    var client: LiveHTTPClient
    var base: URL

    func get(_ path: String) async throws -> NetdataReply {
        guard let url = LivePaths.url(base: base, path: path), Self.isHouseAgent(url) else {
            throw NetdataProblem.notUnderstood
        }
        if Self.isCloud(url) {
            throw NetdataProblem.redirected
        }
        let response = try await reply(for: url)
        if (300..<400).contains(response.status) {
            throw NetdataProblem.redirected
        }
        return NetdataReply(status: response.status, body: response.body)
    }

    private func reply(for url: URL) async throws -> LiveHTTPResponse {
        do {
            return try await client.get(url, headers: ["Accept": "application/json"])
        } catch let problem as LiveHTTPProblem {
            switch problem {
            case .badAddress:
                throw NetdataProblem.notUnderstood
            case .untrusted, .unreachable:
                throw NetdataProblem.offline
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw NetdataProblem.offline
        }
    }

    private static func isHouseAgent(_ url: URL) -> Bool {
        guard url.user == nil, url.password == nil, let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    private static func isCloud(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return host.contains("netdata.cloud") || host.contains("my-netdata.io")
    }
}
