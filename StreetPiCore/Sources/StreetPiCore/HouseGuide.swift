import Foundation

public enum HouseGroup: String, Sendable, Equatable, Codable, CaseIterable, Identifiable {
    case adBlockerAndDNS
    case streaming
    case smartHome
    case remoteHelp
    case internet
    case piHealth
    case backups
    case monitors
    case address

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .adBlockerAndDNS: "Ad blocker & DNS"
        case .streaming: "Streaming"
        case .smartHome: "Smart home"
        case .remoteHelp: "Remote help"
        case .internet: "Internet"
        case .piHealth: "Pi health"
        case .backups: "Backups"
        case .monitors: "Monitors"
        case .address: "Address"
        }
    }
}

public struct GroupRow: Sendable, Equatable, Identifiable, Codable {
    public var id: String
    public var name: String
    public var state: String

    public init(id: String, name: String, state: String) {
        self.id = id
        self.name = name
        self.state = state
    }
}

public struct GroupBrief: Sendable, Equatable, Identifiable {
    public var id: HouseGroup
    public var title: String
    public var summary: String
    public var tone: PlainEnglishStatus.Tone
    public var rows: [GroupRow]

    public init(
        id: HouseGroup,
        title: String,
        summary: String,
        tone: PlainEnglishStatus.Tone,
        rows: [GroupRow]
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.tone = tone
        self.rows = rows
    }
}

public enum CacheFreshness {
    public static let staleAfter: TimeInterval = 6 * 60 * 60

    public static func isStale(_ snapshot: HouseholdSnapshot, now: Date) -> Bool {
        now.timeIntervalSince(snapshot.referenceDate) >= staleAfter
    }
}

extension HouseholdSnapshot {
    public var referenceDate: Date {
        switch link {
        case .homeNetwork:
            capturedAt
        case .away(let cachedAt):
            cachedAt
        }
    }

    public var isEmptyHouse: Bool {
        services.isEmpty && machine == nil
    }
}

public enum HouseGuide {
    public static func groups(in snapshot: HouseholdSnapshot) -> [GroupBrief] {
        HouseGroup.allCases.compactMap { brief($0, in: snapshot) }
    }

    public static func brief(_ group: HouseGroup, in snapshot: HouseholdSnapshot) -> GroupBrief? {
        switch group {
        case .monitors, .address:
            return nil
        case .piHealth:
            guard snapshot.machine != nil else { return nil }
            return GroupBrief(
                id: group,
                title: group.title,
                summary: piSummary(snapshot),
                tone: piTone(snapshot),
                rows: []
            )
        default:
            let rows = snapshot.services
                .filter { $0.kind.houseGroup == group }
                .map { GroupRow(id: $0.id, name: $0.name, state: ReadingText.stateWord(for: $0)) }
            guard !rows.isEmpty else { return nil }
            let members = snapshot.services.filter { $0.kind.houseGroup == group }
            return GroupBrief(
                id: group,
                title: group.title,
                summary: summary(for: group, members: members, snapshot: snapshot),
                tone: tone(for: members),
                rows: rows
            )
        }
    }

    private static func tone(for members: [ServiceHealth]) -> PlainEnglishStatus.Tone {
        if members.contains(where: { $0.state == .notResponding }) {
            return .problem
        }
        if members.contains(where: { $0.state == .degraded || $0.state == .unknown }) {
            return .attention
        }
        return .calm
    }

    private static func summary(
        for group: HouseGroup,
        members: [ServiceHealth],
        snapshot: HouseholdSnapshot
    ) -> String {
        if group == .internet {
            return internetSummary(members)
        }
        if members.allSatisfy({ $0.state == .notResponding }), let only = members.first, members.count == 1 {
            return downLine(only)
        }
        if let down = members.first(where: { $0.state == .notResponding }) {
            return downLine(down)
        }
        if members.contains(where: { $0.state == .degraded }) {
            return "Something here is having trouble."
        }
        switch group {
        case .adBlockerAndDNS:
            if snapshot.dns?.blockingEnabled == false {
                return "Ad blocking is paused."
            }
            return "Ads are being blocked."
        case .streaming:
            return "Streaming is up."
        case .smartHome:
            return "The house controls are up."
        case .remoteHelp:
            return "Remote help is ready."
        case .internet:
            return internetSummary(members)
        case .backups:
            return "The weekly copy succeeded."
        case .piHealth:
            return piSummary(snapshot)
        case .monitors:
            return "No monitors yet."
        case .address:
            return "No recent news about the home address."
        }
    }

    private static func internetSummary(_ members: [ServiceHealth]) -> String {
        if members.allSatisfy({ $0.state == .responding }) {
            return "The home's address on the internet is up to date."
        }
        return "The home's address on the internet is out of date."
    }

    private static func downLine(_ service: ServiceHealth) -> String {
        if service.kind == .dnsFilter {
            return "The ad blocker is down."
        }
        return "\(service.name) is down."
    }

    private static func piSummary(_ snapshot: HouseholdSnapshot) -> String {
        guard let temperature = snapshot.machine?.temperatureCelsius else {
            return "No recent reading from the Pi."
        }
        if temperature >= MachineLimits.hotCelsius {
            return "The Pi is too hot."
        }
        if temperature >= MachineLimits.warmCelsius {
            return "The Pi is warmer than usual."
        }
        return "The Pi is cool and quiet."
    }

    private static func piTone(_ snapshot: HouseholdSnapshot) -> PlainEnglishStatus.Tone {
        guard let temperature = snapshot.machine?.temperatureCelsius else {
            return .attention
        }
        if temperature >= MachineLimits.hotCelsius {
            return .problem
        }
        if temperature >= MachineLimits.warmCelsius {
            return .attention
        }
        if let disk = snapshot.machine?.diskUsedFraction, disk >= MachineLimits.diskAttention {
            return .attention
        }
        if let memory = snapshot.machine?.memoryUsedFraction, memory >= MachineLimits.memoryAttention {
            return .attention
        }
        return .calm
    }
}

extension ServiceKind {
    public var houseGroup: HouseGroup? {
        switch self {
        case .dnsFilter, .resolver:
            .adBlockerAndDNS
        case .media:
            .streaming
        case .homeAutomation:
            .smartHome
        case .remoteHelp:
            .remoteHelp
        case .internet:
            .internet
        case .backup:
            .backups
        case .statusPage, .telemetry, .other:
            nil
        }
    }
}
