import Foundation

public enum LiveReadCopy {
    public static let charts = "The charts could not be read."
    public static let containers = "The containers could not be read."
    public static let alarms = "The alarms could not be read."
    public static let liveLog = "The live log could not be read."
    public static let textLog = "The text log could not be read."
    public static let offline = "The Pi is not answering."
    public static let tryAgain = "This phone will try again on its own."

    public static func pihole(_ problem: PiholeProblem, fallback: String) -> String {
        switch problem {
        case .offline:
            offline
        case .needsPassword, .needsSignIn, .refused:
            problem.title
        case .notUnderstood, .invalidDomain, .invalidPause:
            fallback
        }
    }
}

public struct TextLogPage: Sendable, Equatable {
    public var lines: [String]
    public var nextID: Int
    public var pid: Int?
    public var fileEnabled: Bool

    public init(lines: [String], nextID: Int, pid: Int?, fileEnabled: Bool) {
        self.lines = lines
        self.nextID = nextID
        self.pid = pid
        self.fileEnabled = fileEnabled
    }
}

/// Newest lookups first. A later poll adds rows and keeps the ones already seen.
public struct LiveLogFeed: Sendable, Equatable {
    public var queries: [DNSQuery]

    public init(queries: [DNSQuery] = []) {
        self.queries = queries
    }

    public func applying(_ incoming: [DNSQuery], limit: Int = 40) -> LiveLogFeed {
        var byID: [String: DNSQuery] = [:]
        for query in queries {
            byID[query.id] = query
        }
        for query in incoming {
            byID[query.id] = query
        }
        let merged = byID.values.sorted { lhs, rhs in
            if lhs.at != rhs.at { return lhs.at > rhs.at }
            return lhs.id > rhs.id
        }
        let cap = max(0, limit)
        return LiveLogFeed(queries: Array(merged.prefix(cap)))
    }
}

/// The dnsmasq text log. `nextID` asks the Pi only for lines that arrived after the last read.
public struct TextLogFeed: Sendable, Equatable {
    public var lines: [String]
    public var nextID: Int?
    public var pid: Int?
    public var fileEnabled: Bool

    public init(lines: [String] = [], nextID: Int? = nil, pid: Int? = nil, fileEnabled: Bool = false) {
        self.lines = lines
        self.nextID = nextID
        self.pid = pid
        self.fileEnabled = fileEnabled
    }

    public func applying(_ page: TextLogPage, limit: Int = 80) -> TextLogFeed {
        let restarted = pid != nil && page.pid != nil && pid != page.pid
        let combined = (nextID == nil || restarted) ? page.lines : lines + page.lines
        let cap = max(0, limit)
        return TextLogFeed(
            lines: Array(combined.suffix(cap)),
            nextID: page.nextID,
            pid: page.pid ?? pid,
            fileEnabled: page.fileEnabled
        )
    }
}
