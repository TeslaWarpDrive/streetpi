import Foundation
import StreetPiCore

/// Pi-hole calls through the shared live client. A mock sender lets tests stay off the network.
struct LivePiholeTransport: PiholeTransport {
    var http: any LiveHTTPSending
    var base: URL

    init(http: any LiveHTTPSending, base: URL) {
        self.http = http
        self.base = base
    }

    init(client: LiveHTTPClient, base: URL) {
        self.init(http: client, base: base)
    }

    func send(_ request: PiholeRequest) async throws -> PiholeResponse {
        guard let url = Self.endpoint(base: base, pathAndQuery: request.path) else {
            throw PiholeProblem.notUnderstood
        }
        var headers = request.headers
        headers["Accept"] = "application/json"
        if request.body != nil {
            headers["Content-Type"] = "application/json"
        }
        do {
            let response = try await dispatch(request.method, url: url, headers: headers, body: request.body)
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

    private func dispatch(
        _ method: String,
        url: URL,
        headers: [String: String],
        body: Data?
    ) async throws -> LiveHTTPResponse {
        switch method {
        case "GET":
            try await http.get(url, headers: headers)
        case "POST":
            try await http.post(url, headers: headers, body: body)
        case "DELETE":
            try await http.delete(url, headers: headers)
        default:
            throw PiholeProblem.notUnderstood
        }
    }

    private static func mapped(_ problem: LiveHTTPProblem) -> PiholeProblem {
        switch problem {
        case .unreachable:
            .offline
        case .untrusted:
            .untrusted
        case .badAddress:
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

struct KeychainFTLSession: FTLSessionStoring {
    var keychain: KeychainSession

    func loadSID() -> String? {
        try? keychain.loadSessionID()
    }

    func saveSID(_ sid: String) {
        try? keychain.saveSessionID(sid)
    }

    func clearSID() {
        try? keychain.deleteSessionID()
    }
}
