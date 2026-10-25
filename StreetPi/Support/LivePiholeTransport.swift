import Foundation
import StreetPiCore

/// Pi-hole calls through the shared live client. Tests never open a socket.
struct LivePiholeTransport: PiholeTransport {
    var client: LiveHTTPClient
    var base: URL

    func send(_ request: PiholeRequest) async throws -> PiholeResponse {
        guard !LiveGate.usesFixtures else { throw PiholeProblem.offline }
        guard let url = Self.endpoint(base: base, pathAndQuery: request.path) else {
            throw PiholeProblem.notUnderstood
        }
        do {
            let response = try await perform(request, url: url)
            if (300...399).contains(response.status) {
                throw PiholeProblem.notUnderstood
            }
            return PiholeResponse(status: response.status, body: response.body)
        } catch let problem as PiholeProblem {
            throw problem
        } catch let problem as LiveHTTPProblem {
            throw Self.mapped(problem)
        } catch {
            throw PiholeProblem.offline
        }
    }

    private func perform(_ request: PiholeRequest, url: URL) async throws -> LiveHTTPResponse {
        switch request.method {
        case "GET":
            return try await client.get(url, headers: request.headers)
        case "POST":
            return try await client.post(url, headers: request.headers, body: request.body)
        case "DELETE":
            return try await client.delete(url, headers: request.headers)
        default:
            throw PiholeProblem.notUnderstood
        }
    }

    private static func mapped(_ problem: LiveHTTPProblem) -> PiholeProblem {
        switch problem {
        case .unreachable:
            .offline
        case .badAddress, .untrusted:
            .notUnderstood
        }
    }

    /// The stored Pi-hole address already ends in `/api`. Client paths start with `/api` too.
    static func endpoint(base: URL, pathAndQuery: String) -> URL? {
        guard let host = base.host?.lowercased(), !host.contains("netdata.cloud") else { return nil }
        guard var parts = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return nil }
        parts.path = ""
        parts.query = nil
        parts.fragment = nil
        parts.user = nil
        parts.password = nil
        guard let origin = parts.url else { return nil }
        return LivePaths.url(base: origin, path: pathAndQuery)
    }
}
