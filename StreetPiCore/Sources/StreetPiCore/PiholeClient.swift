import Foundation

public actor PiholeClient {
    private let transport: any PiholeTransport
    private let password: @Sendable () -> String
    private let now: @Sendable () -> Date
    private var session: SID?

    public init(
        transport: any PiholeTransport,
        password: @escaping @Sendable () -> String,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.transport = transport
        self.password = password
        self.now = now
    }

    public func pause(seconds: Int) async throws {
        guard let request = PiholeWrites.pause(seconds: seconds) else {
            throw PiholeProblem.invalidPause
        }
        _ = try await perform(request)
    }

    public func resume() async throws {
        _ = try await perform(PiholeWrites.resume())
    }

    public func block(domain: String) async throws {
        guard let request = PiholeWrites.block(domain: domain) else {
            throw PiholeProblem.invalidDomain
        }
        _ = try await perform(request)
    }

    public func allow(domain: String) async throws {
        guard let request = PiholeWrites.allow(domain: domain) else {
            throw PiholeProblem.invalidDomain
        }
        _ = try await perform(request)
    }

    public func blocking() async throws -> DNSBlocking {
        try PiholeDecode.blocking(from: try await get("/api/dns/blocking"))
    }

    public func summary() async throws -> DNSSummary {
        try PiholeDecode.summary(from: try await get("/api/stats/summary"))
    }

    public func history(ending: Date) async throws -> [DayChartSample] {
        try PiholeDecode.history(from: try await get("/api/history"), ending: ending)
    }

    public func topDomains() async throws -> [DNSCount] {
        try PiholeDecode.namedCounts(
            from: try await get("/api/stats/top_domains"),
            listKey: "domains",
            nameKey: "domain"
        )
    }

    public func topClients() async throws -> [DNSCount] {
        try PiholeDecode.namedCounts(
            from: try await get("/api/stats/top_clients"),
            listKey: "clients",
            nameKey: "name"
        )
    }

    public func queries() async throws -> [DNSQuery] {
        try PiholeDecode.queries(from: try await get("/api/queries"))
    }

    /// Newest lookups. The caller polls this and folds the rows into `LiveLogFeed`.
    public func liveQueries() async throws -> [DNSQuery] {
        let rows = try PiholeDecode.queries(from: try await get("/api/queries?length=40"))
        return rows.sorted { $0.at > $1.at }
    }

    /// Dnsmasq text log. Pass the previous `nextID` to read only the new lines.
    public func textLog(after nextID: Int?) async throws -> TextLogPage {
        let path = nextID.map { "/api/logs/dnsmasq?nextID=\($0)" } ?? "/api/logs/dnsmasq"
        return try PiholeDecode.textLog(from: try await get(path))
    }

    public func clients() async throws -> [NamedRow] {
        try PiholeDecode.clients(from: try await get("/api/clients"))
    }

    public func groups() async throws -> [NamedRow] {
        try PiholeDecode.groups(from: try await get("/api/groups"))
    }

    public func lists() async throws -> [DNSListRow] {
        try PiholeDecode.lists(from: try await get("/api/lists"))
    }

    public func hosts() async throws -> [NamedRow] {
        try PiholeDecode.hosts(from: try await get("/api/config/dns/hosts"))
    }

    public func cnames() async throws -> [NamedRow] {
        try PiholeDecode.cnames(from: try await get("/api/config/dns/cnameRecords"))
    }

    public func signOut() async {
        guard let current = session else { return }
        session = nil
        let request = PiholeRequest(
            method: "DELETE",
            path: "/api/auth",
            headers: [FTLSessionPolicy.sidHeader: current.value],
            body: nil
        )
        _ = try? await transport.send(request)
    }

    public func appDidEnterBackground() async {
        await signOut()
    }

    private func get(_ path: String) async throws -> Data {
        let response = try await perform(PiholeRequest(method: "GET", path: path, headers: [:], body: nil))
        return response.body
    }

    private func perform(_ request: PiholeRequest) async throws -> PiholeResponse {
        var response = try await sendOnce(request)
        if response.status == 401 {
            session = nil
            response = try await sendOnce(request)
        }
        try accept(response)
        return response
    }

    private func sendOnce(_ request: PiholeRequest) async throws -> PiholeResponse {
        let sid = try await validSID()
        var headers = request.headers
        headers[FTLSessionPolicy.sidHeader] = sid
        let authed = PiholeRequest(method: request.method, path: request.path, headers: headers, body: request.body)
        do {
            return try await transport.send(authed)
        } catch let problem as PiholeProblem {
            throw problem
        } catch {
            throw PiholeProblem.offline
        }
    }

    private func validSID() async throws -> String {
        if let session, session.expiresAt > now() {
            return session.value
        }
        try await authenticate()
        guard let session else { throw PiholeProblem.needsSignIn }
        return session.value
    }

    private func authenticate() async throws {
        let secret = password()
        guard !secret.isEmpty else { throw PiholeProblem.needsPassword }
        let body = try JSONEncoder().encode(AuthRequest(password: secret))
        let request = PiholeRequest(method: "POST", path: "/api/auth", headers: [:], body: body)
        let response: PiholeResponse
        do {
            response = try await transport.send(request)
        } catch let problem as PiholeProblem {
            throw problem
        } catch {
            throw PiholeProblem.offline
        }
        if response.status == 401 { throw PiholeProblem.needsSignIn }
        if response.status == 403 { throw PiholeProblem.refused }
        guard (200...299).contains(response.status) else { throw PiholeProblem.notUnderstood }
        let wire = try JSONDecoder().decode(AuthWire.self, from: response.body)
        let validity = wire.session.validity ?? FTLSessionPolicy.validitySeconds
        session = SID(value: wire.session.sid, expiresAt: now().addingTimeInterval(TimeInterval(validity)))
    }

    private func accept(_ response: PiholeResponse) throws {
        switch response.status {
        case 200...299:
            return
        case 401:
            throw PiholeProblem.needsSignIn
        case 403:
            throw PiholeProblem.refused
        default:
            throw PiholeProblem.notUnderstood
        }
    }
}

private struct SID: Sendable {
    var value: String
    var expiresAt: Date
}

private struct AuthWire: Decodable {
    struct Session: Decodable {
        var sid: String
        var validity: Int?
    }

    var session: Session
}
