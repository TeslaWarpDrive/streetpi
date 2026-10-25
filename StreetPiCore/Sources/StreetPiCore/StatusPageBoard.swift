import Foundation

public enum StatusPageCopy {
    public static let notSetUp = "Not set up yet."
    public static let notSetUpDetail = "The house status page is not set up yet."
    public static let backupMonitor = "Weekly SD backup"
    public static let backupSection = "Backups"
    public static let addressMonitor = "DuckDNS points home"
    public static let addressSection = "Internet"
    /// A weekly push with no successful check-in for this long is down.
    public static let backupLimit: TimeInterval = 8 * 24 * 60 * 60
}

public struct HouseStatusTile: Sendable, Equatable, Identifiable {
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

    public var brief: GroupBrief {
        GroupBrief(id: id, title: title, summary: summary, tone: tone, rows: rows)
    }
}

public struct HouseStatusBoard: Sendable, Equatable {
    public var tiles: [HouseStatusTile]
    public var services: [ServiceHealth]
    public var isMissing: Bool

    public init(tiles: [HouseStatusTile], services: [ServiceHealth], isMissing: Bool) {
        self.tiles = tiles
        self.services = services
        self.isMissing = isMissing
    }

    public static func notSetUp() -> HouseStatusBoard {
        let pairs: [(HouseGroup, String)] = [
            (.monitors, "Monitors"),
            (.streaming, "Streaming"),
            (.smartHome, "Smart home"),
            (.remoteHelp, "Remote"),
            (.internet, "Internet/DNS"),
            (.address, "Address"),
            (.backups, "Backups"),
        ]
        let tiles = pairs.map { group, title in
            HouseStatusTile(
                id: group,
                title: title,
                summary: StatusPageCopy.notSetUp,
                tone: .attention,
                rows: []
            )
        }
        return HouseStatusBoard(tiles: tiles, services: [], isMissing: true)
    }

    public static func make(
        document: StatusPageDocument,
        history: StatusHistory,
        now: Date
    ) -> HouseStatusBoard {
        let services = StatusServices.list(sections: document.sections, history: history, now: now)
        let tiles = [
            StatusMonitorTile.make(sections: document.sections, history: history, services: services),
            SectionRollup.tile(
                group: .streaming,
                title: "Streaming",
                subject: "Streaming",
                section: "Streaming",
                sections: document.sections,
                history: history,
                services: services
            ),
            SectionRollup.tile(
                group: .smartHome,
                title: "Smart home",
                subject: "Smart home",
                section: "Smart home",
                sections: document.sections,
                history: history,
                services: services
            ),
            SectionRollup.tile(
                group: .remoteHelp,
                title: "Remote",
                subject: "Remote help",
                section: "Remote help",
                sections: document.sections,
                history: history,
                services: services
            ),
            SectionRollup.tile(
                group: .internet,
                title: "Internet/DNS",
                subject: "Internet",
                section: "Internet",
                sections: document.sections,
                history: history,
                services: services
            ),
            AddressTile.make(sections: document.sections, history: history, services: services),
            StatusBackupTile.make(sections: document.sections, history: history, services: services, now: now),
        ]
        return HouseStatusBoard(tiles: tiles, services: services, isMissing: false)
    }

    /// One line for the aura. The tiles carry the section sentences, so a ready page does not use the porch.
    public var briefing: PlainEnglishStatus {
        if isMissing {
            return PlainEnglishStatus(
                headline: StatusPageCopy.notSetUp,
                detail: StatusPageCopy.notSetUpDetail,
                tone: .attention,
                linkLine: "On the home network"
            )
        }
        let sections = tiles.filter { $0.id != .monitors }
        if let problem = sections.first(where: { $0.tone == .problem }) {
            return PlainEnglishStatus(
                headline: problem.summary,
                detail: nil,
                tone: .problem,
                linkLine: "On the home network"
            )
        }
        if let waiting = sections.first(where: { $0.tone == .attention }) {
            return PlainEnglishStatus(
                headline: waiting.summary,
                detail: nil,
                tone: .attention,
                linkLine: "On the home network"
            )
        }
        return PlainEnglishStatus(
            headline: "The house is up.",
            detail: nil,
            tone: .calm,
            linkLine: "On the home network"
        )
    }
}

public struct StatusPageLoad: Sendable, Equatable {
    public var board: HouseStatusBoard
    public var snapshot: HouseholdSnapshot

    public init(board: HouseStatusBoard, snapshot: HouseholdSnapshot) {
        self.board = board
        self.snapshot = snapshot
    }
}

public struct StatusPageReader<Transport: StatusPageTransport>: Sendable {
    public var transport: Transport
    public var endpoint: StatusPageEndpoint
    public var now: @Sendable () -> Date

    public init(
        transport: Transport,
        endpoint: StatusPageEndpoint,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.transport = transport
        self.endpoint = endpoint
        self.now = now
    }

    /// A missing page is HTTP 404 on the status-page path. Heartbeats are not a setup check.
    public func load() async throws -> StatusPageLoad {
        guard let pagePath = endpoint.pagePath else { throw StatusPageProblem.notUnderstood }
        let page = try await transport.get(path: pagePath)
        let moment = now()
        if page.status == 404 {
            let board = HouseStatusBoard.notSetUp()
            return StatusPageLoad(board: board, snapshot: Self.snapshot(board, at: moment))
        }
        guard page.status == 200 else { throw StatusPageProblem.offline }
        let document = try StatusPageDocument.decode(page.body)
        guard let heartPath = endpoint.heartbeatPath else { throw StatusPageProblem.notUnderstood }
        let hearts = try await transport.get(path: heartPath)
        guard hearts.status == 200 else { throw StatusPageProblem.offline }
        let history = try StatusHistory.decode(hearts.body)
        let board = HouseStatusBoard.make(document: document, history: history, now: moment)
        return StatusPageLoad(board: board, snapshot: Self.snapshot(board, at: moment))
    }

    private static func snapshot(_ board: HouseStatusBoard, at moment: Date) -> HouseholdSnapshot {
        HouseholdSnapshot(
            capturedAt: moment,
            link: .homeNetwork,
            services: board.services,
            machine: nil,
            dns: nil
        )
    }
}

enum StatusNames {
    static func same(_ left: String, _ right: String) -> Bool {
        left.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(right) == .orderedSame
    }

    static func section(_ name: String, in sections: [StatusSection]) -> StatusSection? {
        sections.first { same($0.name, name) }
    }

    static func monitor(_ name: String, in section: StatusSection) -> StatusMonitor? {
        section.monitors.first { same($0.name, name) }
    }
}

enum StatusServices {
    static func list(sections: [StatusSection], history: StatusHistory, now: Date) -> [ServiceHealth] {
        sections.flatMap { section in
            section.monitors.map { monitor in
                ServiceHealth(
                    id: String(monitor.id),
                    name: monitor.name,
                    kind: kind(section.name),
                    state: state(monitor, section: section, history: history, now: now)
                )
            }
        }
    }

    static func rows(monitors: [StatusMonitor], services: [ServiceHealth]) -> [GroupRow] {
        let ids = Set(monitors.map { String($0.id) })
        return services.filter { ids.contains($0.id) }.map { service in
            GroupRow(id: service.id, name: service.name, state: ReadingText.stateWord(for: service))
        }
    }

    private static func kind(_ section: String) -> ServiceKind {
        if StatusNames.same(section, "Streaming") { return .media }
        if StatusNames.same(section, "Smart home") { return .homeAutomation }
        if StatusNames.same(section, "Remote help") { return .remoteHelp }
        if StatusNames.same(section, "Internet") { return .internet }
        if StatusNames.same(section, StatusPageCopy.backupSection) { return .backup }
        return .other
    }

    private static func state(
        _ monitor: StatusMonitor,
        section: StatusSection,
        history: StatusHistory,
        now: Date
    ) -> Reachability {
        if StatusNames.same(section.name, StatusPageCopy.backupSection),
           StatusNames.same(monitor.name, StatusPageCopy.backupMonitor) {
            return StatusBackupTile.reachability(monitorID: monitor.id, history: history, now: now)
        }
        switch history.condition(for: monitor.id) {
        case .up:
            return .responding
        case .down:
            return .notResponding
        case .maintenance:
            return .maintenance
        case .unknown:
            return .unknown
        }
    }
}

enum SectionRollup {
    static func tile(
        group: HouseGroup,
        title: String,
        subject: String,
        section: String,
        sections: [StatusSection],
        history: StatusHistory,
        services: [ServiceHealth]
    ) -> HouseStatusTile {
        guard let found = StatusNames.section(section, in: sections), !found.monitors.isEmpty else {
            return HouseStatusTile(
                id: group,
                title: title,
                summary: StatusPageCopy.notSetUp,
                tone: .attention,
                rows: []
            )
        }
        let states = found.monitors.map { history.condition(for: $0.id) }
        let summary: String
        let tone: PlainEnglishStatus.Tone
        if states.contains(.down) {
            summary = "\(subject) is down."
            tone = .problem
        } else if states.contains(.maintenance) {
            summary = "\(subject) is paused for maintenance."
            tone = .attention
        } else if states.contains(.unknown) {
            summary = "\(subject) is still checking."
            tone = .attention
        } else {
            summary = "\(subject) is up."
            tone = .calm
        }
        return HouseStatusTile(
            id: group,
            title: title,
            summary: summary,
            tone: tone,
            rows: StatusServices.rows(monitors: found.monitors, services: services)
        )
    }
}

enum StatusMonitorTile {
    static func make(
        sections: [StatusSection],
        history: StatusHistory,
        services: [ServiceHealth]
    ) -> HouseStatusTile {
        let monitors = sections.flatMap(\.monitors)
        guard !monitors.isEmpty else {
            return HouseStatusTile(
                id: .monitors,
                title: "Monitors",
                summary: StatusPageCopy.notSetUp,
                tone: .attention,
                rows: []
            )
        }
        let up = monitors.filter { history.condition(for: $0.id) == .up }.count
        let tone: PlainEnglishStatus.Tone
        if monitors.contains(where: { history.condition(for: $0.id) == .down }) {
            tone = .problem
        } else if up == monitors.count {
            tone = .calm
        } else {
            tone = .attention
        }
        return HouseStatusTile(
            id: .monitors,
            title: "Monitors",
            summary: "\(up) of \(monitors.count) up",
            tone: tone,
            rows: StatusServices.rows(monitors: monitors, services: services)
        )
    }
}

enum AddressTile {
    static func make(
        sections: [StatusSection],
        history: StatusHistory,
        services: [ServiceHealth]
    ) -> HouseStatusTile {
        guard let section = StatusNames.section(StatusPageCopy.addressSection, in: sections),
              let monitor = StatusNames.monitor(StatusPageCopy.addressMonitor, in: section)
        else {
            return HouseStatusTile(
                id: .address,
                title: "Address",
                summary: StatusPageCopy.notSetUp,
                tone: .attention,
                rows: []
            )
        }
        let summary: String
        let tone: PlainEnglishStatus.Tone
        switch history.condition(for: monitor.id) {
        case .up:
            summary = "The home's address on the internet is up to date."
            tone = .calm
        case .down:
            summary = "The home's address on the internet is out of date."
            tone = .problem
        case .maintenance:
            summary = "The home address is paused for maintenance."
            tone = .attention
        case .unknown:
            summary = "No recent news about the home address."
            tone = .attention
        }
        return HouseStatusTile(
            id: .address,
            title: "Address",
            summary: summary,
            tone: tone,
            rows: StatusServices.rows(monitors: [monitor], services: services)
        )
    }
}

enum StatusBackupTile {
    static func make(
        sections: [StatusSection],
        history: StatusHistory,
        services: [ServiceHealth],
        now: Date
    ) -> HouseStatusTile {
        guard let section = StatusNames.section(StatusPageCopy.backupSection, in: sections),
              let monitor = StatusNames.monitor(StatusPageCopy.backupMonitor, in: section)
        else {
            return HouseStatusTile(
                id: .backups,
                title: "Backups",
                summary: StatusPageCopy.notSetUp,
                tone: .attention,
                rows: []
            )
        }
        let summary: String
        let tone: PlainEnglishStatus.Tone
        if let success = history.successes[monitor.id] {
            let when = BackupClock.phrase(success.time)
            if now.timeIntervalSince(success.time) >= StatusPageCopy.backupLimit {
                summary = "No backup in the last 8 days. Last backup: \(when)."
                tone = .problem
            } else {
                summary = "Last backup: \(when)"
                tone = .calm
            }
        } else {
            summary = "No backup check-in yet."
            tone = .attention
        }
        return HouseStatusTile(
            id: .backups,
            title: "Backups",
            summary: summary,
            tone: tone,
            rows: StatusServices.rows(monitors: [monitor], services: services)
        )
    }

    static func reachability(monitorID: Int, history: StatusHistory, now: Date) -> Reachability {
        guard let success = history.successes[monitorID] else { return .unknown }
        if now.timeIntervalSince(success.time) >= StatusPageCopy.backupLimit {
            return .notResponding
        }
        return .responding
    }
}

enum BackupClock {
    static func phrase(_ date: Date) -> String {
        guard let zone = TimeZone(identifier: "America/Chicago") else {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        calendar.locale = Locale(identifier: "en_US")
        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        let index = (parts.weekday ?? 1) - 1
        let symbols = calendar.shortWeekdaySymbols
        let weekday = symbols.indices.contains(index) ? symbols[index] : "Day"
        let hour24 = parts.hour ?? 0
        let minute = parts.minute ?? 0
        let period = hour24 >= 12 ? "PM" : "AM"
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        let minutes = minute < 10 ? "0\(minute)" : "\(minute)"
        return "\(weekday) \(hour12):\(minutes) \(period)"
    }
}
