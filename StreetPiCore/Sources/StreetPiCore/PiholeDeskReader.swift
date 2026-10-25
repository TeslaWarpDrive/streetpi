import Foundation

public enum PiholeLoginState: Sendable, Equatable {
    case answering
    case dnsOff
}

public enum PiholeLoginProbe: Sendable, Equatable {
    case answering
    case dnsOff
    case notThisService
}

public struct PiholeSummaryFacts: Sendable, Equatable {
    public var total: Int
    public var blocked: Int
    public var activeClients: Int
    public var listsUpdatedAt: Date?

    public init(total: Int, blocked: Int, activeClients: Int, listsUpdatedAt: Date?) {
        self.total = total
        self.blocked = blocked
        self.activeClients = activeClients
        self.listsUpdatedAt = listsUpdatedAt
    }
}

public struct PiholeDeskLoad: Sendable, Equatable {
    public var desk: DNSDesk
    public var total: Int
    public var blocked: Int
    public var blockingEnabled: Bool

    public init(desk: DNSDesk, total: Int, blocked: Int, blockingEnabled: Bool) {
        self.desk = desk
        self.total = total
        self.blocked = blocked
        self.blockingEnabled = blockingEnabled
    }
}

extension PiholeClient {
    /// Reads the ad blocker. Does not pause, allow, block, or update lists.
    public func loadDesk(now: Date) async throws -> PiholeDeskLoad {
        let facts = try await summaryFacts()
        let blocking = try await blocking()
        let day = try await history(ending: now)
        let busiestDomains = try await topDomains()
        let blockedNames = try await topDomains(blocked: true)
        let clientsTop = try await topClients()
        let recent = try await queries()
        let known = try await clients()
        let groupRows = try await groups()
        let domainRows = try await domains()
        let listRows = try await lists()
        let hostRows = try await hosts()
        let aliasRows = try await cnames()
        let textLog = try await textLogEnabled()
        let line = AdBlockerVoice.line(
            blocked: facts.blocked,
            total: facts.total,
            blockingEnabled: blocking.enabled
        )
        let updated = facts.listsUpdatedAt ?? now
        let desk = DNSDesk(
            textLogFileEnabled: textLog,
            blocking: blocking,
            day: day,
            knownClients: facts.activeClients > 0 ? facts.activeClients : known.count,
            listCount: listRows.count,
            listsUpdatedAt: updated,
            clients: known,
            groups: groupRows,
            domains: domainRows,
            lists: listRows,
            hosts: hostRows,
            cnames: aliasRows,
            services: [],
            queries: recent,
            topDomains: busiestDomains,
            topClients: clientsTop,
            blockedDomains: blockedNames,
            spokenLine: line,
            listsUpdateKnown: facts.listsUpdatedAt != nil,
            upkeepNote: AdBlockerVoice.upkeep(textLogOn: textLog, listsKnown: facts.listsUpdatedAt != nil)
        )
        return PiholeDeskLoad(
            desk: desk,
            total: facts.total,
            blocked: facts.blocked,
            blockingEnabled: blocking.enabled
        )
    }

    private func textLogEnabled() async throws -> Bool {
        do {
            return try await queryLogging()
        } catch PiholeProblem.notUnderstood {
            return false
        }
    }
}
