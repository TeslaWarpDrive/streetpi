import Foundation

public enum StatusPageProblem: Error, Equatable {
    case offline
    case notUnderstood
}

/// Where the house status page lives. The slug starts as house and can be edited.
public struct StatusPageEndpoint: Sendable, Equatable, Codable {
    public var host: String
    public var port: Int
    public var slug: String

    public init(host: String, port: Int, slug: String) {
        self.host = host
        self.port = port
        self.slug = slug
    }

    public static let house = StatusPageEndpoint(host: "192.168.1.78", port: 3001, slug: "house")

    public func cleaned() -> StatusPageEndpoint? {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let slug = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...65_535).contains(port), Self.isHost(host), Self.isSlug(slug) else {
            return nil
        }
        return StatusPageEndpoint(host: host, port: port, slug: slug)
    }

    public var pagePath: String? {
        guard let clean = cleaned() else { return nil }
        return "/api/status-page/\(clean.slug)"
    }

    public var heartbeatPath: String? {
        guard let clean = cleaned() else { return nil }
        return "/api/status-page/heartbeat/\(clean.slug)"
    }

    public func url(path: String) -> URL? {
        guard let clean = cleaned(), path.hasPrefix("/") else { return nil }
        var parts = URLComponents()
        parts.scheme = "http"
        parts.host = clean.host
        parts.port = clean.port
        parts.path = path
        return parts.url
    }

    public static func isSlug(_ slug: String) -> Bool {
        guard let first = slug.first, first.isLetter || first.isNumber else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        return slug.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    public static func isHost(_ host: String) -> Bool {
        guard !host.isEmpty else { return false }
        let blocked = ["/", " ", ":", ".."]
        return blocked.allSatisfy { !host.contains($0) }
    }
}

public enum HouseRefreshSource: Sendable, Equatable {
    case fixtures
    case statusPage

    /// Tests and previews stay on fixtures. The installed app reads the status page.
    public static func choose(underTest: Bool) -> HouseRefreshSource {
        underTest ? .fixtures : .statusPage
    }
}

public struct StatusPageHTTPResponse: Sendable, Equatable {
    public var status: Int
    public var body: Data

    public init(status: Int, body: Data) {
        self.status = status
        self.body = body
    }
}

public protocol StatusPageTransport: Sendable {
    func get(path: String) async throws -> StatusPageHTTPResponse
}

public final class ScriptedStatusPageTransport: StatusPageTransport, @unchecked Sendable {
    public struct Step: Sendable {
        public var status: Int
        public var body: Data

        public init(status: Int, body: Data) {
            self.status = status
            self.body = body
        }

        public static func json(_ status: Int, _ text: String) -> Step {
            Step(status: status, body: Data(text.utf8))
        }
    }

    private let lock = NSLock()
    private var steps: [Step]
    private var pathsStorage: [String] = []

    public init(steps: [Step]) {
        self.steps = steps
    }

    public var paths: [String] {
        lock.lock()
        defer { lock.unlock() }
        return pathsStorage
    }

    public func get(path: String) async throws -> StatusPageHTTPResponse {
        guard let step = dequeue(path) else { throw StatusPageProblem.offline }
        return StatusPageHTTPResponse(status: step.status, body: step.body)
    }

    private func dequeue(_ path: String) -> Step? {
        lock.lock()
        defer { lock.unlock() }
        pathsStorage.append(path)
        guard !steps.isEmpty else { return nil }
        return steps.removeFirst()
    }
}

public struct StatusMonitor: Sendable, Equatable, Identifiable {
    public var id: Int
    public var name: String
    public var type: String

    public init(id: Int, name: String, type: String) {
        self.id = id
        self.name = name
        self.type = type
    }
}

public struct StatusSection: Sendable, Equatable, Identifiable {
    public var id: String { name }
    public var name: String
    public var monitors: [StatusMonitor]

    public init(name: String, monitors: [StatusMonitor]) {
        self.name = name
        self.monitors = monitors
    }
}

public struct StatusPageDocument: Sendable, Equatable {
    public var title: String
    public var published: Bool
    public var sections: [StatusSection]

    public init(title: String, published: Bool, sections: [StatusSection]) {
        self.title = title
        self.published = published
        self.sections = sections
    }

    public static func decode(_ data: Data) throws -> StatusPageDocument {
        do {
            return try JSONDecoder().decode(RawPage.self, from: data).document
        } catch {
            throw StatusPageProblem.notUnderstood
        }
    }
}

public struct StatusBeat: Sendable, Equatable {
    public var status: Int
    public var time: Date

    public init(status: Int, time: Date) {
        self.status = status
        self.time = time
    }
}

public enum StatusCondition: Sendable, Equatable {
    case up
    case down
    case maintenance
    case unknown
}

public struct StatusHistory: Sendable, Equatable {
    public var latest: [Int: StatusBeat]
    public var successes: [Int: StatusBeat]

    public init(latest: [Int: StatusBeat], successes: [Int: StatusBeat]) {
        self.latest = latest
        self.successes = successes
    }

    public func condition(for monitorID: Int) -> StatusCondition {
        guard let beat = latest[monitorID] else { return .unknown }
        switch beat.status {
        case 1:
            return .up
        case 0:
            return .down
        case 3:
            return .maintenance
        default:
            return .unknown
        }
    }

    public static func decode(_ data: Data) throws -> StatusHistory {
        do {
            let raw = try JSONDecoder().decode(RawHeartbeats.self, from: data)
            return raw.history
        } catch {
            throw StatusPageProblem.notUnderstood
        }
    }
}

private struct RawPage: Decodable {
    var config: RawConfig
    var publicGroupList: [RawGroup]

    var document: StatusPageDocument {
        StatusPageDocument(
            title: config.title,
            published: config.published ?? false,
            sections: publicGroupList.map { group in
                StatusSection(
                    name: group.name,
                    monitors: group.monitorList.map { monitor in
                        StatusMonitor(id: monitor.id, name: monitor.name, type: monitor.type)
                    }
                )
            }
        )
    }
}

private struct RawConfig: Decodable {
    var title: String
    var published: Bool?
}

private struct RawGroup: Decodable {
    var name: String
    var monitorList: [RawMonitor]
}

/// Public monitors expose id, name, and type. Extra keys are ignored.
private struct RawMonitor: Decodable {
    var id: Int
    var name: String
    var type: String
}

private struct RawHeartbeats: Decodable {
    var heartbeatList: [String: [RawBeat]]

    var history: StatusHistory {
        var latest: [Int: StatusBeat] = [:]
        var successes: [Int: StatusBeat] = [:]
        for (key, beats) in heartbeatList {
            guard let monitorID = Int(key) else { continue }
            for beat in beats {
                guard let status = beat.status, let time = beat.parsedTime else { continue }
                let sample = StatusBeat(status: status, time: time)
                if latest[monitorID].map({ $0.time > sample.time }) != true {
                    latest[monitorID] = sample
                }
                guard status == 1 else { continue }
                if successes[monitorID].map({ $0.time > sample.time }) != true {
                    successes[monitorID] = sample
                }
            }
        }
        return StatusHistory(latest: latest, successes: successes)
    }
}

private struct RawBeat: Decodable {
    var status: Int?
    var time: String?

    var parsedTime: Date? {
        guard let time else { return nil }
        return KumaClock.parse(time)
    }
}

enum KumaClock {
    static func parse(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: trimmed) {
            return date
        }
        let internet = ISO8601DateFormatter()
        internet.formatOptions = [.withInternetDateTime]
        if let date = internet.date(from: trimmed) {
            return date
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for format in ["yyyy-MM-dd HH:mm:ss.SSS", "yyyy-MM-dd HH:mm:ss"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        return nil
    }
}
