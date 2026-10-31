import Foundation

/// A mailbox report in the shapes the House, Ad blocker, and Pi screens already read.
public struct AwayBoard: Sendable, Equatable {
    public var snapshot: HouseholdSnapshot?
    public var desk: DNSDesk
    public var machine: MachineDesk
    public var status: HouseStatusBoard?
    public var piNotice: String?

    /// Before the first report. Empty, so a home reading never passes for an away one.
    public static let waiting = AwayBoard(
        snapshot: nil,
        desk: .quiet,
        machine: awayDesk(series: [], chartNote: AwayCopy.chartWaiting),
        status: nil,
        piNotice: nil
    )

    public static func make(latest: AwaySnapshot, history: AwaySnapshot?) -> AwayBoard {
        let status = AwayStatusBuilder.make(latest)
        return AwayBoard(
            snapshot: HouseholdSnapshot(
                capturedAt: latest.generatedAt,
                link: .away(cachedAt: latest.generatedAt),
                services: status.services,
                machine: latest.machine.map(reading),
                dns: latest.adBlocker.flatMap(summary)
            ),
            desk: desk(latest: latest, history: history),
            machine: awayDesk(series: series(history), chartNote: AwayCopy.chartWaiting),
            status: status,
            piNotice: latest.machine == nil ? AwayCopy.noMeters : nil
        )
    }

    private static func awayDesk(series: [MetricSeries], chartNote: String) -> MachineDesk {
        var desk = MachineDesk.livePlaceholder
        desk.series = series
        desk.chartNote = chartNote
        desk.alertNote = AwayCopy.alertsAtHome
        return desk
    }

    private static func reading(_ machine: AwayMachine) -> MachineReading {
        MachineReading(
            cpuUsedFraction: machine.cpuBusyPercent / 100,
            temperatureCelsius: machine.temperatureC,
            memoryUsedFraction: machine.memoryUsedPercent / 100,
            diskUsedFraction: machine.diskUsedPercent / 100,
            uptimeSeconds: TimeInterval(machine.uptimeSeconds)
        )
    }

    private static func summary(_ part: AwayAdBlocker) -> DNSSummary? {
        guard part.blocking != .unknown else { return nil }
        return DNSSummary(
            blockingEnabled: part.blocking == .enabled,
            queriesToday: part.queriesToday,
            blockedToday: part.blockedToday
        )
    }

    private static func desk(latest: AwaySnapshot, history: AwaySnapshot?) -> DNSDesk {
        var desk = DNSDesk.quiet
        desk.clientsNote = nil
        guard let part = latest.adBlocker else {
            desk.spokenLine = AwayCopy.noChecks
            return desk
        }
        desk.blocking = DNSBlocking(enabled: part.blocking != .disabled)
        desk.spokenLine = part.blocking == .unknown ? AwayCopy.notSure : nil
        desk.knownClients = part.activeDevices
        desk.reportedQueries = part.queriesToday
        desk.reportedBlocked = part.blockedToday
        if let history, let buckets = history.adBlocker?.history {
            desk.day = DayChartBuilder.hours(
                from: buckets.map {
                    HistoryPoint(timestamp: TimeInterval($0.time), total: $0.total, blocked: $0.blocked)
                },
                ending: history.generatedAt
            )
        }
        return desk
    }

    /// Hour averages for the last day, oldest first. The screen's chart reads one point an hour.
    private static func series(_ history: AwaySnapshot?) -> [MetricSeries] {
        guard let history, let points = history.machine?.cpuHistory, !points.isEmpty else { return [] }
        let end = history.generatedAt.timeIntervalSince1970
        let start = end - 24 * 3_600
        let recent = points.filter { TimeInterval($0.time) >= start && TimeInterval($0.time) < end }
        let hours = Dictionary(grouping: recent) { min(23, Int((TimeInterval($0.time) - start) / 3_600)) }
        let averaged = hours.keys.sorted().compactMap { hour -> MetricPoint? in
            guard let members = hours[hour] else { return nil }
            let mean = members.reduce(0) { $0 + $1.busy } / Double(members.count)
            return MetricPoint(hour: hour, value: mean / 100)
        }
        return [
            MetricSeries(id: "cpu", title: "Processor", caption: "Share of the processor.", points: averaged),
        ]
    }
}

extension FixtureBook {
    /// The fixture report and its day of history, as the screens would read them.
    public static func awayBoard() throws -> AwayBoard {
        AwayBoard.make(latest: try away(named: "away-live"), history: try away(named: "away-history"))
    }
}

/// Builds the same status board the home status page gives, from a report's checks.
private enum AwayStatusBuilder {
    private static let backupID = -1
    private static let proxyID = -2
    private static let streamingSection = "Streaming"
    private static let otherSection = "House"

    /// A report has names only, so a check joins its status-page section by what it is called.
    private static let sectionWords: [(word: String, section: String)] = [
        ("streaming", streamingSection), ("mediaflow", streamingSection), ("aiostreams", streamingSection),
        ("aiometadata", streamingSection),
        ("home assistant", "Smart home"), ("homekit", "Smart home"), ("matter", "Smart home"),
        ("rustdesk", "Remote help"), ("remote", "Remote help"),
        ("internet", StatusPageCopy.addressSection), ("duckdns", StatusPageCopy.addressSection),
        ("pi-hole", StatusPageCopy.addressSection), ("unbound", StatusPageCopy.addressSection),
        ("dns", StatusPageCopy.addressSection),
    ]

    static func make(_ report: AwaySnapshot) -> HouseStatusBoard {
        let board = HouseStatusBoard.make(
            document: StatusPageDocument(title: "Away", published: true, sections: sections(report)),
            history: history(report),
            now: report.generatedAt
        )
        var tiles = board.tiles
        for index in tiles.indices {
            tiles[index] = adjusted(tiles[index], report: report)
        }
        return HouseStatusBoard(tiles: tiles, services: board.services, isMissing: false)
    }

    private static func section(for name: String) -> String {
        let folded = name.lowercased()
        return sectionWords.first { folded.contains($0.word) }?.section ?? otherSection
    }

    private static func isBackup(_ item: AwayMonitor) -> Bool {
        item.name.lowercased().contains("backup")
    }

    private static func items(_ report: AwaySnapshot) -> [AwayMonitor] {
        (report.monitors?.items ?? []).filter { !isBackup($0) }
    }

    private static func sections(_ report: AwaySnapshot) -> [StatusSection] {
        var grouped: [String: [StatusMonitor]] = [:]
        for (index, item) in items(report).enumerated() {
            grouped[section(for: item.name), default: []]
                .append(StatusMonitor(id: index, name: item.name, type: "report"))
        }
        grouped[streamingSection, default: []]
            .append(StatusMonitor(id: proxyID, name: "Streaming proxy", type: "report"))
        grouped[StatusPageCopy.backupSection] = [
            StatusMonitor(id: backupID, name: StatusPageCopy.backupMonitor, type: "report"),
        ]
        return grouped.keys.sorted().compactMap { name in
            grouped[name].map { StatusSection(name: name, monitors: $0) }
        }
    }

    private static func history(_ report: AwaySnapshot) -> StatusHistory {
        let time = report.generatedAt
        var latest: [Int: StatusBeat] = [:]
        var successes: [Int: StatusBeat] = [:]
        for (index, item) in items(report).enumerated() {
            latest[index] = StatusBeat(status: beat(item.status), time: time)
        }
        latest[proxyID] = StatusBeat(status: report.streamingProxy.healthy ? 1 : 0, time: time)
        if let backup = report.backup {
            latest[backupID] = StatusBeat(status: backup.ok ? 1 : 0, time: backup.lastRunAt)
            if backup.ok {
                successes[backupID] = StatusBeat(status: 1, time: backup.lastRunAt)
            }
        }
        return StatusHistory(latest: latest, successes: successes)
    }

    /// The Uptime Kuma numbers `StatusHistory` reads.
    private static func beat(_ status: AwayMonitor.Status) -> Int {
        switch status {
        case .up:
            1
        case .down:
            0
        case .pending:
            2
        case .maintenance:
            3
        }
    }

    private static func adjusted(_ tile: HouseStatusTile, report: AwaySnapshot) -> HouseStatusTile {
        var next = tile
        if tile.id == .backups {
            applyBackup(report.backup, to: &next)
        } else if tile.id == .monitors {
            applyMonitors(report.monitors, to: &next)
        } else if tile.rows.isEmpty {
            next.summary = report.monitors == nil ? AwayCopy.noChecks : AwayCopy.notInReport
            next.tone = report.monitors == nil ? .attention : .calm
        }
        return next
    }

    private static func applyBackup(_ backup: AwayBackup?, to tile: inout HouseStatusTile) {
        guard let backup else {
            tile.summary = AwayCopy.noBackupWord
            tile.tone = .calm
            return
        }
        if !backup.ok {
            tile.summary = AwayCopy.backupFailed
            tile.tone = .problem
        }
    }

    /// The count covers every check on the Pi. A report names only the service checks.
    private static func applyMonitors(_ monitors: AwayMonitors?, to tile: inout HouseStatusTile) {
        guard let monitors else {
            tile.summary = AwayCopy.noChecks
            tile.tone = .attention
            return
        }
        tile.summary = "\(monitors.up) of \(monitors.total) up"
        if monitors.down > 0 {
            tile.tone = .problem
        } else {
            tile.tone = monitors.up == monitors.total ? .calm : .attention
        }
    }
}
