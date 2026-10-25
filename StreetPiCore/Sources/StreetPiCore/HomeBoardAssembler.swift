import Foundation

extension HomeBoard {
    public static let footerLine = "Tap a tile to open it. Hold the ad blocker to pause it."

    /// Fixture-backed board. Swap the inputs when a live reader arrives.
    public static func make(
        snapshot: HouseholdSnapshot?,
        desk: DNSDesk,
        status: PlainEnglishStatus,
        now: Date
    ) -> HomeBoard {
        let services = snapshot?.services ?? []
        let matched = matchedDay(snapshot: snapshot, desk: desk)
        let blocking = matched ? desk.blocking.enabled : snapshot?.dns?.blockingEnabled
        return HomeBoard(
            title: "Pi Stats",
            statusTitle: pillTitle(status.headline),
            statusAccent: accent(in: status.headline),
            statusTone: status.tone,
            statusDetail: status.detail,
            checkedLine: CheckedPhrase.english(from: snapshot?.referenceDate, now: now),
            adBlocker: adBlocker(snapshot: snapshot, desk: desk, matched: matched),
            pi: pi(snapshot?.machine),
            services: serviceSquares(services, blockingOn: blocking),
            monitors: monitorBoard(services),
            backups: backups(services),
            uptime: uptime(snapshot?.machine),
            devices: devices(count: matched ? desk.knownClients : nil),
            footer: footerLine
        )
    }

    private static func pillTitle(_ headline: String) -> String {
        guard headline.hasSuffix(".") else { return headline }
        return String(headline.dropLast())
    }

    private static func accent(in title: String) -> String {
        let folded = title.lowercased()
        let keys = [
            "good", "look", "down", "hot", "paused", "full", "memory",
            "answering", "trouble", "warmer", "yet",
        ]
        return keys.first { folded.contains($0) } ?? ""
    }

    private static func matchedDay(snapshot: HouseholdSnapshot?, desk: DNSDesk) -> Bool {
        guard let blocked = snapshot?.dns?.blockedToday, let lookups = snapshot?.dns?.queriesToday else {
            return false
        }
        return desk.blockedToday == blocked && desk.queriesToday == lookups
    }
}

extension HomeAdBlockerReading {
    public static func from(desk: DNSDesk) -> HomeAdBlockerReading {
        let hours = desk.day.map { HomeHourBar(hour: $0.hour, stopped: $0.blocked) }
        let hasDay = desk.day.isEmpty == false
        return make(
            blocking: desk.blocking.enabled,
            blocked: hasDay ? desk.blockedToday : nil,
            lookups: hasDay ? desk.queriesToday : nil,
            hours: hours
        )
    }

    fileprivate static func make(
        blocking: Bool?,
        blocked: Int?,
        lookups: Int?,
        hours: [HomeHourBar]
    ) -> HomeAdBlockerReading {
        let share = shareText(blocked: blocked, lookups: lookups)
        let last = hours.last?.stopped
        let state = stateWord(blocking)
        let blockingLine = blockingLine(blocking)
        let blockedText = blocked.map(HomeCountText.grouped) ?? "—"
        let lookupsText = lookups.map(HomeCountText.grouped) ?? "—"
        let lastText = last.map(HomeCountText.grouped) ?? "—"
        return HomeAdBlockerReading(
            isOn: blocking == true,
            stateWord: state,
            blockingLine: blockingLine,
            percentText: share.percent,
            ringFraction: share.fraction,
            fractionLine: share.line,
            blockedText: blockedText,
            lookupsText: lookupsText,
            lastHourText: lastText,
            stoppedLine: blocked == nil ? "No count yet." : "Ads and trackers the house refused.",
            lookupsLine: lookups == nil ? "No count yet." : "Names your devices asked for.",
            lastHourLine: last == nil ? "No hourly reading yet." : "Stopped in the latest hour.",
            hourlyStopped: hours,
            explainer: explainer,
            spoken: spoken(state: state, percent: share.percent, line: share.line)
        )
    }

    private static let explainer = """
    This percent is ads and trackers the house stopped, divided by every lookup in the last 24 hours. \
    The line under it says that same share in plain words.
    """

    private static func spoken(state: String, percent: String, line: String) -> String {
        "Ad blocker, \(state). \(percent). \(line)"
    }

    private static func stateWord(_ blocking: Bool?) -> String {
        switch blocking {
        case true:
            "ON"
        case false:
            "OFF"
        case nil:
            "Quiet"
        }
    }

    private static func blockingLine(_ blocking: Bool?) -> String {
        switch blocking {
        case true:
            "Blocking is on"
        case false:
            "Blocking is paused"
        case nil:
            "No reading yet"
        }
    }

    private static func shareText(blocked: Int?, lookups: Int?) -> ShareReading {
        guard let blocked, let lookups else {
            return ShareReading(percent: "—", fraction: 0, line: "No lookups in the last 24 hours.")
        }
        guard let percent = BlockedShare.percent(blocked: blocked, lookups: lookups) else {
            return ShareReading(percent: "—", fraction: 0, line: BlockedShare.line(blocked: blocked, lookups: lookups))
        }
        let fraction = lookups == 0 ? 0 : Double(blocked) / Double(lookups)
        let line = BlockedShare.line(blocked: blocked, lookups: lookups)
        return ShareReading(percent: "\(percent)%", fraction: fraction, line: line)
    }
}

private struct ShareReading {
    var percent: String
    var fraction: Double
    var line: String
}

extension HomeBoard {
    fileprivate static func adBlocker(
        snapshot: HouseholdSnapshot?,
        desk: DNSDesk,
        matched: Bool
    ) -> HomeAdBlockerReading {
        if matched {
            return .from(desk: desk)
        }
        let dns = snapshot?.dns
        return HomeAdBlockerReading.make(
            blocking: dns?.blockingEnabled,
            blocked: dns?.blockedToday,
            lookups: dns?.queriesToday,
            hours: []
        )
    }

    fileprivate static func pi(_ machine: MachineReading?) -> HomePiReading {
        guard let machine else {
            return HomePiReading(
                temperature: "—",
                warmth: "Quiet",
                warmthTone: .attention,
                line: "No reading from the Pi.",
                meters: [],
                spoken: "Pi. No reading from the Pi."
            )
        }
        let meters = meters(machine)
        let warmth: String
        let tone: PlainEnglishStatus.Tone
        let temperature: String
        if let degrees = machine.temperatureCelsius {
            warmth = PiWarmthWord.word(celsius: degrees)
            tone = PiWarmthWord.tone(celsius: degrees)
            temperature = ReadingText.celsius(degrees)
        } else {
            warmth = "Quiet"
            tone = .attention
            temperature = "—"
        }
        let line = piLine(warmth: warmth, meters: meters, hasTemperature: machine.temperatureCelsius != nil)
        let spokenMeters = meters.map { "\($0.title) \($0.value)" }.joined(separator: ", ")
        let spoken = spokenMeters.isEmpty
            ? "Pi, \(temperature), \(warmth). \(line)"
            : "Pi, \(temperature), \(warmth). \(spokenMeters). \(line)"
        return HomePiReading(
            temperature: temperature,
            warmth: warmth,
            warmthTone: tone,
            line: line,
            meters: meters,
            spoken: spoken
        )
    }

    private static func piLine(warmth: String, meters: [HomeMeter], hasTemperature: Bool) -> String {
        let lead = hasTemperature ? "The Pi is \(warmth.lowercased())." : "No temperature from the Pi."
        guard meters.isEmpty == false else { return lead }
        let list = meters.map { "\($0.title) \($0.value)" }.joined(separator: ", ")
        return "\(lead) \(list)."
    }

    private static func meters(_ machine: MachineReading) -> [HomeMeter] {
        var rows: [HomeMeter] = []
        if let cpu = machine.cpuUsedFraction {
            rows.append(meter("cpu", "CPU", cpu))
        }
        if let memory = machine.memoryUsedFraction {
            rows.append(meter("ram", "RAM", memory))
        }
        if let disk = machine.diskUsedFraction {
            rows.append(meter("disk", "Disk", disk))
        }
        return rows
    }

    private static func meter(_ id: String, _ title: String, _ fraction: Double) -> HomeMeter {
        HomeMeter(
            id: id,
            title: title,
            fraction: min(max(fraction, 0), 1),
            value: ReadingText.percent(fraction)
        )
    }
}

extension HomeBoard {
    fileprivate static func serviceSquares(
        _ services: [ServiceHealth],
        blockingOn: Bool?
    ) -> [HomeServiceSquare] {
        [
            square(
                id: "streaming",
                title: "Streaming",
                symbol: "play.tv",
                group: .streaming,
                services: services.filter { $0.kind == .media }
            ),
            square(
                id: "remote",
                title: "Remote",
                symbol: "display.and.arrow.down",
                group: .remoteHelp,
                services: services.filter { $0.kind == .remoteHelp }
            ),
            dnsSquare(services, blockingOn: blockingOn),
            square(
                id: "address",
                title: "Address",
                symbol: "globe",
                group: .internet,
                services: services.filter { $0.kind == .internet },
                readyWord: "Current"
            ),
        ]
    }

    private static func dnsSquare(_ services: [ServiceHealth], blockingOn: Bool?) -> HomeServiceSquare {
        let members = services.filter { $0.kind == .dnsFilter || $0.kind == .resolver }
        let word: String
        let tone: PlainEnglishStatus.Tone
        if members.isEmpty {
            word = "Quiet"
            tone = .attention
        } else if members.contains(where: { $0.state == .notResponding }) {
            word = "Down"
            tone = .problem
        } else if blockingOn == false {
            word = "Paused"
            tone = .attention
        } else if members.contains(where: { $0.state != .responding }) {
            word = "Trouble"
            tone = .attention
        } else {
            word = "On"
            tone = .calm
        }
        return HomeServiceSquare(
            id: "dns",
            title: "DNS",
            word: word,
            tone: tone,
            symbol: "shield.lefthalf.filled",
            group: .adBlockerAndDNS,
            spoken: "DNS, \(word)"
        )
    }

    private static func square(
        id: String,
        title: String,
        symbol: String,
        group: HouseGroup,
        services: [ServiceHealth],
        readyWord: String = "Up"
    ) -> HomeServiceSquare {
        let word: String
        let tone: PlainEnglishStatus.Tone
        if services.isEmpty {
            word = "Quiet"
            tone = .attention
        } else if services.contains(where: { $0.state == .notResponding }) {
            word = "Down"
            tone = .problem
        } else if services.contains(where: { $0.state != .responding }) {
            word = "Trouble"
            tone = .attention
        } else if group == .remoteHelp {
            word = "Ready"
            tone = .calm
        } else {
            word = readyWord
            tone = .calm
        }
        return HomeServiceSquare(
            id: id,
            title: title,
            word: word,
            tone: tone,
            symbol: symbol,
            group: group,
            spoken: "\(title), \(word)"
        )
    }

    fileprivate static func monitorBoard(_ services: [ServiceHealth]) -> HomeMonitorBoard {
        let rows = services.compactMap(monitor)
        let up = rows.filter { $0.word == "Up" }.count
        let summary = rows.isEmpty ? "None yet" : "\(up) of \(rows.count) up"
        let line: String
        if rows.isEmpty {
            line = "No monitors yet."
        } else if up == rows.count {
            line = "Every monitor is answering."
        } else {
            let down = rows.count - up
            line = down == 1 ? "1 monitor needs a look." : "\(down) monitors need a look."
        }
        return HomeMonitorBoard(title: "Monitors", summary: summary, line: line, monitors: rows)
    }

    private static func monitor(_ service: ServiceHealth) -> HomeMonitor? {
        guard let group = service.kind.houseGroup, group != .backups else { return nil }
        let word = monitorWord(service.state)
        return HomeMonitor(
            id: service.id,
            name: service.name,
            word: word,
            tone: monitorTone(service.state),
            group: group,
            spoken: "\(service.name), \(word)"
        )
    }

    private static func monitorWord(_ state: Reachability) -> String {
        switch state {
        case .responding:
            "Up"
        case .notResponding:
            "Down"
        case .degraded:
            "Trouble"
        case .maintenance:
            "Paused"
        case .unknown:
            "Quiet"
        }
    }

    private static func monitorTone(_ state: Reachability) -> PlainEnglishStatus.Tone {
        switch state {
        case .responding:
            .calm
        case .notResponding:
            .problem
        case .degraded, .maintenance, .unknown:
            .attention
        }
    }

    fileprivate static func backups(_ services: [ServiceHealth]) -> HomeBackupReading {
        guard let backup = services.first(where: { $0.kind == .backup }) else {
            return HomeBackupReading(
                title: "Backups",
                value: "Quiet",
                line: "No backup reading yet.",
                tone: .attention,
                group: .backups,
                spoken: "Backups. No backup reading yet."
            )
        }
        let value = backupValue(backup.state)
        let line = backupLine(backup.state)
        return HomeBackupReading(
            title: "Backups",
            value: value,
            line: line,
            tone: monitorTone(backup.state),
            group: .backups,
            spoken: "Backups, \(value). \(line)"
        )
    }

    private static func backupValue(_ state: Reachability) -> String {
        switch state {
        case .responding:
            "Copied"
        case .notResponding:
            "Down"
        case .degraded:
            "Trouble"
        case .maintenance:
            "Paused"
        case .unknown:
            "Quiet"
        }
    }

    private static func backupLine(_ state: Reachability) -> String {
        switch state {
        case .responding:
            "The weekly copy succeeded."
        case .notResponding:
            "The weekly copy did not finish."
        case .degraded, .maintenance, .unknown:
            "The weekly copy needs a look."
        }
    }

    fileprivate static func uptime(_ machine: MachineReading?) -> HomeFact {
        guard let seconds = machine?.uptimeSeconds else {
            return HomeFact(
                id: "uptime",
                title: "Running for",
                value: "—",
                line: "No reading from the Pi.",
                spoken: "Running for. No reading from the Pi."
            )
        }
        let value = RunningForCopy.value(seconds: seconds)
        let line = RunningForCopy.line(seconds: seconds)
        return HomeFact(
            id: "uptime",
            title: "Running for",
            value: value,
            line: line,
            spoken: "Running for \(value). \(line)"
        )
    }

    fileprivate static func devices(count: Int?) -> HomeFact {
        guard let count else {
            return HomeFact(
                id: "devices",
                title: "Devices",
                value: "—",
                line: "No devices yet.",
                spoken: "Devices. No devices yet."
            )
        }
        let value = HomeCountText.grouped(count)
        let line = deviceLine(count: count, value: value)
        return HomeFact(
            id: "devices",
            title: "Devices",
            value: value,
            line: line,
            spoken: "Devices, \(value). \(line)"
        )
    }

    private static func deviceLine(count: Int, value: String) -> String {
        if count == 0 {
            return "No devices asked for a name."
        }
        if count == 1 {
            return "1 device asked for a name."
        }
        return "\(value) devices asked for a name."
    }
}
