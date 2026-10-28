import Foundation

/// A reading of the house at one moment. Built from fixtures in Phase 1.
public struct HouseholdSnapshot: Sendable, Equatable, Codable {
    public var capturedAt: Date
    public var link: LinkState
    public var services: [ServiceHealth]
    public var machine: MachineReading?
    public var dns: DNSSummary?

    public init(
        capturedAt: Date,
        link: LinkState,
        services: [ServiceHealth],
        machine: MachineReading?,
        dns: DNSSummary?
    ) {
        self.capturedAt = capturedAt
        self.link = link
        self.services = services
        self.machine = machine
        self.dns = dns
    }
}

public enum LinkState: Sendable, Equatable, Codable {
    case homeNetwork
    case away(cachedAt: Date)

    private enum CodingKeys: String, CodingKey {
        case kind
        case cachedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "homeNetwork":
            self = .homeNetwork
        case "away":
            let cachedAt = try container.decode(Date.self, forKey: .cachedAt)
            self = .away(cachedAt: cachedAt)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "Unknown link kind."
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .homeNetwork:
            try container.encode("homeNetwork", forKey: .kind)
        case .away(let cachedAt):
            try container.encode("away", forKey: .kind)
            try container.encode(cachedAt, forKey: .cachedAt)
        }
    }
}

public struct ServiceHealth: Sendable, Equatable, Identifiable, Codable {
    public var id: String
    public var name: String
    public var kind: ServiceKind
    public var state: Reachability

    public init(id: String, name: String, kind: ServiceKind, state: Reachability) {
        self.id = id
        self.name = name
        self.kind = kind
        self.state = state
    }
}

public enum ServiceKind: String, Sendable, Equatable, Codable, CaseIterable {
    case dnsFilter
    case resolver
    case homeAutomation
    case media
    case remoteHelp
    case internet
    case backup
    case statusPage
    case telemetry
    case other
}

public enum Reachability: String, Sendable, Equatable, Codable {
    case responding
    case notResponding
    case degraded
    case maintenance
    case unknown
}

public struct MachineReading: Sendable, Equatable, Codable {
    public var cpuUsedFraction: Double?
    public var temperatureCelsius: Double?
    public var memoryUsedFraction: Double?
    public var diskUsedFraction: Double?
    public var uptimeSeconds: TimeInterval?

    public init(
        cpuUsedFraction: Double? = nil,
        temperatureCelsius: Double? = nil,
        memoryUsedFraction: Double? = nil,
        diskUsedFraction: Double? = nil,
        uptimeSeconds: TimeInterval? = nil
    ) {
        self.cpuUsedFraction = cpuUsedFraction
        self.temperatureCelsius = temperatureCelsius
        self.memoryUsedFraction = memoryUsedFraction
        self.diskUsedFraction = diskUsedFraction
        self.uptimeSeconds = uptimeSeconds
    }
}

public struct DNSSummary: Sendable, Equatable, Codable {
    public var blockingEnabled: Bool
    /// Nil only when this phone has not loaded a count. FTL still records lookups when the text log is off.
    public var queriesToday: Int?
    public var blockedToday: Int?

    public init(blockingEnabled: Bool, queriesToday: Int? = nil, blockedToday: Int? = nil) {
        self.blockingEnabled = blockingEnabled
        self.queriesToday = queriesToday
        self.blockedToday = blockedToday
    }
}

public enum MachineLimits {
    public static let warmCelsius = 70.0
    public static let hotCelsius = 80.0
    public static let diskAttention = 0.90
    public static let memoryAttention = 0.92
    public static let processorBusy = 0.85
}

extension Date {
    /// Fixed clock for fixtures, previews, and visual snapshots.
    public static let streetFixtureNow = Date(timeIntervalSince1970: 1_792_422_000)
}
