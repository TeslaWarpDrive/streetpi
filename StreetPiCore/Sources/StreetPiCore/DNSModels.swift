import Foundation

public struct DayChartSample: Sendable, Equatable, Identifiable, Codable {
    public var hour: Int
    public var allowed: Int
    public var blocked: Int

    public var id: Int { hour }

    public init(hour: Int, allowed: Int, blocked: Int) {
        self.hour = hour
        self.allowed = allowed
        self.blocked = blocked
    }
}

public struct DNSBlocking: Sendable, Equatable, Codable {
    public var enabled: Bool
    public var pause: PauseLength?
    public var pauseEndsAt: Date?

    public init(enabled: Bool, pause: PauseLength? = nil, pauseEndsAt: Date? = nil) {
        self.enabled = enabled
        self.pause = pause
        self.pauseEndsAt = enabled ? nil : pauseEndsAt
    }
}

public struct NamedRow: Sendable, Equatable, Identifiable, Codable {
    public var id: String
    public var name: String
    public var detail: String

    public init(id: String, name: String, detail: String) {
        self.id = id
        self.name = name
        self.detail = detail
    }
}

public struct DNSCount: Sendable, Equatable, Identifiable, Codable {
    public var name: String
    public var count: Int

    public var id: String { name }

    public init(name: String, count: Int) {
        self.name = name
        self.count = count
    }
}

public struct DNSQuery: Sendable, Equatable, Identifiable, Codable {
    public enum Outcome: String, Sendable, Equatable, Codable {
        case allowed
        case blocked

        public var word: String {
            switch self {
            case .allowed: "Allowed"
            case .blocked: "Blocked"
            }
        }
    }

    public var id: String
    public var domain: String
    public var client: String
    public var outcome: Outcome
    public var at: Date

    public init(id: String, domain: String, client: String, outcome: Outcome, at: Date) {
        self.id = id
        self.domain = domain
        self.client = client
        self.outcome = outcome
        self.at = at
    }
}

public struct DNSListRow: Sendable, Equatable, Identifiable, Codable {
    public var id: String
    public var name: String
    public var host: String
    public var enabled: Bool

    public init(id: String, name: String, host: String, enabled: Bool) {
        self.id = id
        self.name = name
        self.host = host
        self.enabled = enabled
    }

    public var statusWord: String {
        enabled ? "On" : "Off"
    }
}

public struct DNSServiceChoice: Sendable, Equatable, Identifiable, Codable {
    public var id: String
    public var name: String
    public var detail: String
    public var blocked: Bool

    public init(id: String, name: String, detail: String, blocked: Bool) {
        self.id = id
        self.name = name
        self.detail = detail
        self.blocked = blocked
    }
}

public struct HistoryPoint: Sendable, Equatable {
    public var timestamp: TimeInterval
    public var total: Int
    public var blocked: Int

    public init(timestamp: TimeInterval, total: Int, blocked: Int) {
        self.timestamp = timestamp
        self.total = total
        self.blocked = blocked
    }
}

public enum DayChartBuilder {
    /// Oldest hour is index 0. Empty input is 24 quiet hours, not a sample.
    public static func hours(from points: [HistoryPoint], ending: Date) -> [DayChartSample] {
        let end = ending.timeIntervalSince1970
        let start = end - 24 * 3_600
        var allowed = Array(repeating: 0, count: 24)
        var blocked = Array(repeating: 0, count: 24)
        for point in points {
            guard point.timestamp >= start, point.timestamp < end else { continue }
            let index = min(23, max(0, Int((point.timestamp - start) / 3_600)))
            blocked[index] += max(0, point.blocked)
            allowed[index] += max(0, point.total - point.blocked)
        }
        return (0..<24).map { hour in
            DayChartSample(hour: hour, allowed: allowed[hour], blocked: blocked[hour])
        }
    }
}

public enum DNSCopy {
    public static let emptyQueriesTitle = "No lookups yet."
    public static let emptyQueriesDetail = "When a device looks something up, it will show up here."
    public static let emptyLiveTitle = "Quiet right now."
    public static let emptyLiveDetail = "New lookups will appear here as they happen."
    public static let emptyTopsTitle = "No top lists yet."
    public static let emptyTopsDetail = "Once lookups come in, the busiest names and devices show up here."
    public static let emptyChartTitle = "No lookups in the last day."
    public static let emptyChartDetail = "The last day will show here once a device looks something up."
    public static let localNamesNote = "These names stay on the Pi. This phone can read them."
    public static let upkeepDetail = """
    The text log file is off. Lookups are still kept in memory and in the history, back to July. \
    You can update the block lists from this phone. Other settings stay as they are.
    """
}

public enum QueryOutcomeMap {
    public static func outcome(status: String) -> DNSQuery.Outcome {
        let upper = status.uppercased()
        if upper.contains("GRAVITY") || upper.contains("DENY") {
            return .blocked
        }
        return .allowed
    }
}
