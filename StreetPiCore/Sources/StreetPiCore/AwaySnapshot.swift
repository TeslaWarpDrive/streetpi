import Foundation

/// The numbers the Pi pushes to the mailbox: snapshot contract v1.
/// A key this version does not know fails the decode, so a Pi-side bug cannot slip in an extra field.
/// Descriptions and mirrors never show the contents.
public struct AwaySnapshot: Sendable, Equatable, Codable {
    public static let schemaVersion = 1

    public enum Kind: String, Sendable, Equatable, Codable {
        case live
        case history
    }

    public var kind: Kind
    public var generatedAt: Date
    public var adBlocker: AwayAdBlocker?
    public var machine: AwayMachine?
    public var monitors: AwayMonitors?
    public var streamingProxy: AwayStreamingProxy
    public var backup: AwayBackup?
    public var sources: AwaySources

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schema, kind, generatedAt, adBlocker, machine, monitors, streamingProxy, backup, sources
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        guard try container.decode(Int.self, forKey: .schema) == Self.schemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schema,
                in: container,
                debugDescription: "Unknown schema."
            )
        }
        kind = try container.decode(Kind.self, forKey: .kind)
        generatedAt = try AwayTime.decode(from: container, forKey: .generatedAt)
        adBlocker = try container.decode(AwayAdBlocker?.self, forKey: .adBlocker)
        machine = try container.decode(AwayMachine?.self, forKey: .machine)
        monitors = try container.decode(AwayMonitors?.self, forKey: .monitors)
        streamingProxy = try container.decode(AwayStreamingProxy.self, forKey: .streamingProxy)
        backup = try container.decode(AwayBackup?.self, forKey: .backup)
        sources = try container.decode(AwaySources.self, forKey: .sources)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.schemaVersion, forKey: .schema)
        try container.encode(kind, forKey: .kind)
        try container.encode(AwayTime.text(generatedAt), forKey: .generatedAt)
        try container.encode(adBlocker, forKey: .adBlocker)
        try container.encode(machine, forKey: .machine)
        try container.encode(monitors, forKey: .monitors)
        try container.encode(streamingProxy, forKey: .streamingProxy)
        try container.encode(backup, forKey: .backup)
        try container.encode(sources, forKey: .sources)
    }
}

extension AwaySnapshot: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public var description: String { "AwaySnapshot(redacted)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: []) }
}

public struct AwayAdBlocker: Sendable, Equatable, Codable {
    public enum Blocking: String, Sendable, Equatable, Codable {
        case enabled
        case disabled
        case unknown
    }

    public var blocking: Blocking
    public var queriesToday: Int
    public var blockedToday: Int
    public var percentBlocked: Double
    public var domainsOnLists: Int
    public var activeDevices: Int
    /// Ten-minute buckets for the last day. Only a history push carries these.
    public var history: [AwayLookupBucket]?

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case blocking, queriesToday, blockedToday, percentBlocked, domainsOnLists, activeDevices, history
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        blocking = try container.decode(Blocking.self, forKey: .blocking)
        queriesToday = try container.decode(Int.self, forKey: .queriesToday)
        blockedToday = try container.decode(Int.self, forKey: .blockedToday)
        percentBlocked = try container.decode(Double.self, forKey: .percentBlocked)
        domainsOnLists = try container.decode(Int.self, forKey: .domainsOnLists)
        activeDevices = try container.decode(Int.self, forKey: .activeDevices)
        history = try container.decodeIfPresent([AwayLookupBucket].self, forKey: .history)
    }
}

public struct AwayLookupBucket: Sendable, Equatable, Codable {
    public var time: Int
    public var total: Int
    public var blocked: Int

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case time = "t"
        case total, blocked
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        time = try container.decode(Int.self, forKey: .time)
        total = try container.decode(Int.self, forKey: .total)
        blocked = try container.decode(Int.self, forKey: .blocked)
    }
}

public struct AwayMachine: Sendable, Equatable, Codable {
    public var cpuBusyPercent: Double
    public var memoryUsedPercent: Double
    public var memoryUsedMB: Int
    public var memoryTotalMB: Int
    public var temperatureC: Double
    public var diskUsedPercent: Double
    public var uptimeSeconds: Int
    /// Five-minute points for the last day. Only a history push carries these.
    public var cpuHistory: [AwayCPUPoint]?

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case cpuBusyPercent, memoryUsedPercent, memoryUsedMB, memoryTotalMB
        case temperatureC, diskUsedPercent, uptimeSeconds, cpuHistory
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        cpuBusyPercent = try container.decode(Double.self, forKey: .cpuBusyPercent)
        memoryUsedPercent = try container.decode(Double.self, forKey: .memoryUsedPercent)
        memoryUsedMB = try container.decode(Int.self, forKey: .memoryUsedMB)
        memoryTotalMB = try container.decode(Int.self, forKey: .memoryTotalMB)
        temperatureC = try container.decode(Double.self, forKey: .temperatureC)
        diskUsedPercent = try container.decode(Double.self, forKey: .diskUsedPercent)
        uptimeSeconds = try container.decode(Int.self, forKey: .uptimeSeconds)
        cpuHistory = try container.decodeIfPresent([AwayCPUPoint].self, forKey: .cpuHistory)
    }
}

public struct AwayCPUPoint: Sendable, Equatable, Codable {
    public var time: Int
    public var busy: Double

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case time = "t"
        case busy
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        time = try container.decode(Int.self, forKey: .time)
        busy = try container.decode(Double.self, forKey: .busy)
    }
}

public struct AwayMonitors: Sendable, Equatable, Codable {
    public var up: Int
    public var down: Int
    public var total: Int
    public var items: [AwayMonitor]

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case up, down, total, items
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        up = try container.decode(Int.self, forKey: .up)
        down = try container.decode(Int.self, forKey: .down)
        total = try container.decode(Int.self, forKey: .total)
        items = try container.decode([AwayMonitor].self, forKey: .items)
    }
}

public struct AwayMonitor: Sendable, Equatable, Codable {
    public enum Status: String, Sendable, Equatable, Codable {
        case up
        case down
        case pending
        case maintenance
    }

    public var name: String
    public var status: Status

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case name, status
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        status = try container.decode(Status.self, forKey: .status)
    }
}

public struct AwayStreamingProxy: Sendable, Equatable, Codable {
    public var healthy: Bool

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case healthy
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        healthy = try container.decode(Bool.self, forKey: .healthy)
    }
}

public struct AwayBackup: Sendable, Equatable, Codable {
    public var lastRunAt: Date
    public var ok: Bool

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case lastRunAt, ok
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        lastRunAt = try AwayTime.decode(from: container, forKey: .lastRunAt)
        ok = try container.decode(Bool.self, forKey: .ok)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(AwayTime.text(lastRunAt), forKey: .lastRunAt)
        try container.encode(ok, forKey: .ok)
    }
}

public struct AwaySources: Sendable, Equatable, Codable {
    public enum Health: String, Sendable, Equatable, Codable {
        case ok
        case stale
        case error
    }

    public var adBlocker: Health
    public var machine: Health
    public var monitors: Health

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case adBlocker, machine, monitors
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        adBlocker = try container.decode(Health.self, forKey: .adBlocker)
        machine = try container.decode(Health.self, forKey: .machine)
        monitors = try container.decode(Health.self, forKey: .monitors)
    }
}

/// One newest history row. `GET /v1/history?limit=1` already holds a full day.
struct AwayHistoryPage: Decodable {
    var snapshots: [AwaySnapshot]

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case snapshots
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        snapshots = try container.decode([AwaySnapshot].self, forKey: .snapshots)
    }
}

private struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        nil
    }
}

private extension Decoder {
    /// Same as `container(keyedBy:)`, and refuses a key the type does not list.
    func strictContainer<Key: CodingKey & CaseIterable>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        let known = Set(Key.allCases.map(\.stringValue))
        let present = try container(keyedBy: AnyCodingKey.self).allKeys
        guard present.allSatisfy({ known.contains($0.stringValue) }) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: codingPath, debugDescription: "Unknown key.")
            )
        }
        return try container(keyedBy: type)
    }
}

/// The mailbox sends UTC timestamps with or without fractions of a second.
private enum AwayTime {
    static func decode<Key: CodingKey>(from container: KeyedDecodingContainer<Key>, forKey key: Key) throws -> Date {
        let text = try container.decode(String.self, forKey: key)
        guard let date = KumaClock.parse(text) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "Unreadable time.")
        }
        return date
    }

    static func text(_ date: Date) -> String {
        date.ISO8601Format()
    }
}
