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

    public func pause(seconds: Int) async throws -> DNSBlocking {
        guard let request = PiholeWrites.pause(seconds: seconds) else {
            throw PiholeProblem.invalidPause
        }
        let response = try await perform(request)
        return try PiholeDecode.blocking(from: response.body)
    }

    public func resume() async throws -> DNSBlocking {
        let response = try await perform(PiholeWrites.resume())
        return try PiholeDecode.blocking(from: response.body)
    }

    public func block(domain: String) async throws -> String {
        guard let request = PiholeWrites.block(domain: domain) else {
            throw PiholeProblem.invalidDomain
        }
        let response = try await perform(request, badRequest: .invalidDomain)
        let sent = DomainName.normalized(domain) ?? domain
        return try PiholeDecode.acceptedDomain(from: response.body, sent: sent)
    }

    public func allow(domain: String) async throws -> String {
        guard let request = PiholeWrites.allow(domain: domain) else {
            throw PiholeProblem.invalidDomain
        }
        let response = try await perform(request, badRequest: .invalidDomain)
        let sent = DomainName.normalized(domain) ?? domain
        return try PiholeDecode.acceptedDomain(from: response.body, sent: sent)
    }

    public func updateGravity() async throws -> GravityReport {
        let response = try await perform(PiholeWrites.gravity())
        return try PiholeDecode.gravity(from: response.body)
    }

    public func blocking() async throws -> DNSBlocking {
        try PiholeDecode.blocking(from: try await get("/api/dns/blocking"))
    }

    /// No password and no session id. A 200 with `dns: true` means the ad blocker is there.
    public func reachability() async throws -> PiholeLoginState {
        let response = try await sendPlain(
            PiholeRequest(method: "GET", path: "/api/info/login", headers: [:], body: nil)
        )
        guard (200...299).contains(response.status) else { throw PiholeProblem.notSetUp }
        switch PiholeDecode.loginProbe(from: response.body) {
        case .answering:
            return .answering
        case .dnsOff:
            return .dnsOff
        case .notThisService:
            throw PiholeProblem.notSetUp
        }
    }

    public func summary() async throws -> DNSSummary {
        try PiholeDecode.summary(from: try await get("/api/stats/summary"))
    }

    public func summaryFacts() async throws -> PiholeSummaryFacts {
        try PiholeDecode.summaryFacts(from: try await get("/api/stats/summary"))
    }

    public func history(ending: Date) async throws -> [DayChartSample] {
        let until = Int(ending.timeIntervalSince1970)
        let from = until - 86_400
        let path = "/api/history?from=\(from)&until=\(until)"
        return try PiholeDecode.history(from: try await get(path), ending: ending)
    }

    public func topDomains() async throws -> [DNSCount] {
        try await topDomains(blocked: false)
    }

    public func topDomains(blocked: Bool) async throws -> [DNSCount] {
        let path = blocked
            ? "/api/stats/top_domains?blocked=true&count=10"
            : "/api/stats/top_domains?count=10"
        return try PiholeDecode.namedCounts(
            from: try await get(path),
            listKey: "domains",
            nameKey: "domain"
        )
    }

    public func topClients() async throws -> [DNSCount] {
        try PiholeDecode.namedCounts(
            from: try await get("/api/stats/top_clients?count=10"),
            listKey: "clients",
            nameKey: "name",
            fallbackNameKey: "ip"
        )
    }

    public func queries() async throws -> [DNSQuery] {
        try PiholeDecode.queries(from: try await get("/api/queries?length=50"))
    }

    public func domains() async throws -> [NamedRow] {
        let denied = try PiholeDecode.domainRows(from: try await get("/api/domains/deny"), detail: "Blocked")
        let allowed = try PiholeDecode.domainRows(from: try await get("/api/domains/allow"), detail: "Allowed")
        return denied + allowed
    }

    public func queryLogging() async throws -> Bool {
        try PiholeDecode.queryLogging(from: try await get("/api/config/dns/queryLogging"))
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

    /// Reuse a session id this phone already holds. A 401 still signs in again.
    public func restoreSession(id: String, expiresAt: Date) {
        guard session == nil else { return }
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        session = SID(value: trimmed, expiresAt: expiresAt)
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

    private func sendPlain(_ request: PiholeRequest) async throws -> PiholeResponse {
        do {
            let response = try await transport.send(request)
            guard response.status != 401 else { throw PiholeProblem.notSetUp }
            return response
        } catch let problem as PiholeProblem {
            throw problem
        } catch {
            throw PiholeProblem.offline
        }
    }

    private func perform(
        _ request: PiholeRequest,
        badRequest: PiholeProblem = .notUnderstood
    ) async throws -> PiholeResponse {
        var response = try await sendOnce(request)
        if response.status == 401 {
            session = nil
            response = try await sendOnce(request)
        }
        try accept(response, badRequest: badRequest)
        return response
    }

    private func sendOnce(_ request: PiholeRequest) async throws -> PiholeResponse {
        let sid = try await validSID()
        var headers = request.headers
        headers[FTLSessionPolicy.sidHeader] = sid
        let authed = PiholeRequest(
            method: request.method,
            path: request.path,
            headers: headers,
            body: request.body,
            timeout: request.timeout
        )
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

    private func accept(_ response: PiholeResponse, badRequest: PiholeProblem) throws {
        switch response.status {
        case 200...299:
            return
        case 400:
            throw badRequest
        case 401:
            throw PiholeProblem.needsSignIn
        case 403:
            throw PiholeProblem.refused
        case 409:
            throw PiholeProblem.busy
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
