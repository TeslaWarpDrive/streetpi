import Foundation
import StreetPiCore

/// The road through the gateway, on its own URLSession. It has default system trust and no pin,
/// because the edge certificate rotates. It only talks to the gateway, a redirect is refused, and
/// the Access headers are added here so no other client can ever hold them.
final class AwayHTTPClient: LiveHTTPSending, @unchecked Sendable {
    private let settings: AwayGatewaySettings
    private let session: URLSession
    private let gravitySession: URLSession

    var trustDelegate: (any URLSessionDelegate)? { session.delegate }

    init(
        settings: AwayGatewaySettings,
        configuration: URLSessionConfiguration = LiveHTTPClient.sessionConfiguration()
    ) {
        self.settings = settings
        session = URLSession(configuration: configuration, delegate: RedirectRefusal(), delegateQueue: nil)
        let gravity = Self.gravityConfiguration(configuration)
        gravitySession = URLSession(configuration: gravity, delegate: RedirectRefusal(), delegateQueue: nil)
    }

    deinit {
        session.finishTasksAndInvalidate()
        gravitySession.finishTasksAndInvalidate()
    }

    static func piholeConfiguration() -> URLSessionConfiguration {
        LiveHTTPClient.sessionConfiguration()
    }

    /// Streaming gravity may outlast the edge's idle timeout. Only that POST gets this budget.
    static func gravityConfiguration(_ base: URLSessionConfiguration) -> URLSessionConfiguration {
        let configuration = base.copy() as? URLSessionConfiguration ?? .ephemeral
        configuration.timeoutIntervalForRequest = 310
        configuration.timeoutIntervalForResource = 310
        return configuration
    }

    func get(_ url: URL, headers: [String: String]) async throws -> LiveHTTPResponse {
        try await send(method: "GET", url: url, headers: headers, body: nil)
    }

    func post(_ url: URL, headers: [String: String], body: Data?) async throws -> LiveHTTPResponse {
        try await send(method: "POST", url: url, headers: headers, body: body)
    }

    func delete(_ url: URL, headers: [String: String]) async throws -> LiveHTTPResponse {
        try await send(method: "DELETE", url: url, headers: headers, body: nil)
    }

    private func send(
        method: String,
        url: URL,
        headers: [String: String],
        body: Data?
    ) async throws -> LiveHTTPResponse {
        guard LiveAddress.isSafe(url), settings.isGateway(url) else { throw LiveHTTPProblem.badAddress }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        let access = settings.accessHeaders(for: url)
        for (field, value) in headers.merging(access, uniquingKeysWith: { _, gateway in gateway }) {
            request.setValue(value, forHTTPHeaderField: field)
        }
        let isGravity = method == "POST" && url.path == "/api/action/gravity"
        request.timeoutInterval = isGravity ? 310 : session.configuration.timeoutIntervalForRequest
        let sender = isGravity ? gravitySession : session
        do {
            let (data, response) = try await sender.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw LiveHTTPProblem.unreachable }
            return LiveHTTPResponse(status: http.statusCode, headers: LiveHTTPClient.headerMap(http), body: data)
        } catch let problem as LiveHTTPProblem {
            throw problem
        } catch is CancellationError {
            throw CancellationError()
        } catch let urlError as URLError {
            throw LiveHTTPClient.problem(from: urlError)
        } catch {
            throw LiveHTTPProblem.unreachable
        }
    }
}

extension LiveEndpoints {
    /// Pi-hole, Netdata, and Kuma, all behind the gateway's one https origin.
    static func away(_ gateway: AwayGatewaySettings) -> LiveEndpoints? {
        guard let pihole = gateway.piholeBase,
              let netdata = gateway.netdataBase,
              let kuma = gateway.kumaBase
        else { return nil }
        return LiveEndpoints(pihole: pihole, netdata: netdata, uptimeKuma: kuma)
    }
}

/// One quick look for the gateway. Only a 200 counts, and a redirect is never followed.
struct GatewayProbe: Sendable {
    private static let timeout: TimeInterval = 5

    func answers(_ gateway: AwayGatewaySettings) async -> Bool {
        guard LiveReaderGate.opensSockets, let url = gateway.healthURL else { return false }
        let configuration = LiveHTTPClient.sessionConfiguration()
        configuration.timeoutIntervalForRequest = Self.timeout
        configuration.timeoutIntervalForResource = Self.timeout
        let http = AwayHTTPClient(settings: gateway, configuration: configuration)
        return (try? await http.get(url, headers: [:]))?.status == 200
    }
}

/// Where the reads go right now, and the client that takes them there.
struct LiveRoad {
    var endpoints: LiveEndpoints
    var sender: any LiveHTTPSending
    var isAway: Bool
}

/// The open away clients. A new gateway gets new sessions.
final class AwayRoadHold {
    private var gateway: AwayGatewaySettings?
    private var reads: AwayHTTPClient?

    func reader(for settings: AwayGatewaySettings) -> AwayHTTPClient {
        if let reads, gateway == settings {
            return reads
        }
        let fresh = AwayHTTPClient(settings: settings)
        reads = fresh
        gateway = settings
        return fresh
    }
}
