import Foundation

/// The House control center. Screens render this and nothing about where the numbers came from.
public struct ControlBoard: Sendable, Equatable {
    public var headline: String
    public var tone: PlainEnglishStatus.Tone
    public var checkedLine: String
    public var blocker: BlockerTile
    public var pi: PiTile
    public var squares: [ServiceSquare]
    public var monitors: MonitorTile
    public var backups: BackupTile
    public var running: RunningTile
    public var devices: DevicesTile

    public init(
        headline: String,
        checkedLine: String,
        blocker: BlockerTile,
        pi: PiTile,
        squares: [ServiceSquare],
        monitors: MonitorTile,
        backups: BackupTile,
        running: RunningTile,
        devices: DevicesTile,
        tone: PlainEnglishStatus.Tone = .calm
    ) {
        self.headline = headline
        self.tone = tone
        self.checkedLine = checkedLine
        self.blocker = blocker
        self.pi = pi
        self.squares = squares
        self.monitors = monitors
        self.backups = backups
        self.running = running
        self.devices = devices
    }
}

public struct BlockerTile: Sendable, Equatable {
    public var stateWord: String
    public var percentText: String
    public var fraction: Double
    public var fractionLine: String
    public var explainer: String
    public var canPause: Bool

    public init(
        stateWord: String,
        percentText: String,
        fraction: Double,
        fractionLine: String,
        explainer: String,
        canPause: Bool
    ) {
        self.stateWord = stateWord
        self.percentText = percentText
        self.fraction = fraction
        self.fractionLine = fractionLine
        self.explainer = explainer
        self.canPause = canPause
    }
}

public struct PiTile: Sendable, Equatable {
    public var temperature: String
    public var warmth: String
    public var line: String
    public var cpu: Double?
    public var memory: Double?
    public var disk: Double?

    public init(
        temperature: String,
        warmth: String,
        line: String,
        cpu: Double?,
        memory: Double?,
        disk: Double?
    ) {
        self.temperature = temperature
        self.warmth = warmth
        self.line = line
        self.cpu = cpu
        self.memory = memory
        self.disk = disk
    }
}

public struct ServiceSquare: Sendable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var word: String
    public var tone: PlainEnglishStatus.Tone
    public var group: HouseGroup

    public init(
        id: String,
        title: String,
        word: String,
        tone: PlainEnglishStatus.Tone,
        group: HouseGroup
    ) {
        self.id = id
        self.title = title
        self.word = word
        self.tone = tone
        self.group = group
    }
}

public struct MonitorMark: Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var up: Bool
    public var word: String

    public init(id: String, name: String, up: Bool, word: String) {
        self.id = id
        self.name = name
        self.up = up
        self.word = word
    }
}

public struct MonitorTile: Sendable, Equatable {
    public var figure: String
    public var line: String
    public var marks: [MonitorMark]

    public init(figure: String, line: String, marks: [MonitorMark]) {
        self.figure = figure
        self.line = line
        self.marks = marks
    }
}

public struct BackupTile: Sendable, Equatable {
    public var figure: String
    public var line: String
    public var tone: PlainEnglishStatus.Tone

    public init(figure: String, line: String, tone: PlainEnglishStatus.Tone) {
        self.figure = figure
        self.line = line
        self.tone = tone
    }
}

public struct RunningTile: Sendable, Equatable {
    public var figure: String
    public var line: String

    public init(figure: String, line: String) {
        self.figure = figure
        self.line = line
    }
}

public struct DevicesTile: Sendable, Equatable {
    public var figure: String
    public var line: String

    public init(figure: String, line: String) {
        self.figure = figure
        self.line = line
    }
}

/// Cool, Warm, or Hot for the Pi tile. The longer warmth scale stays on `ReadingText`.
public enum PiWarmth {
    public static func word(celsius: Double) -> String {
        if celsius >= MachineLimits.hotCelsius {
            return "Hot"
        }
        if celsius >= MachineLimits.warmCelsius {
            return "Warm"
        }
        return "Cool"
    }

    public static func line(for word: String) -> String {
        switch word {
        case "Cool":
            "The Pi is cool."
        case "Warm":
            "The Pi is warm."
        case "Hot":
            "The Pi is hot."
        default:
            "No temperature from the Pi yet."
        }
    }
}

public enum RuntimePhrase {
    public static func figure(seconds: TimeInterval) -> String {
        if seconds < 3_600 {
            return "Under an hour"
        }
        let hours = Int(seconds / 3_600)
        if hours < 48 {
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }
        let days = max(1, Int(seconds / 86_400))
        return days == 1 ? "1 day" : "\(days) days"
    }

    public static func line(seconds: TimeInterval) -> String {
        "The Pi has been on for \(figure(seconds: seconds))."
    }
}

public enum ControlBoardBuilder {
    public static func make(
        snapshot: HouseholdSnapshot?,
        share: LookupShare?,
        deviceCount: Int?,
        headline: String,
        now: Date,
        tone: PlainEnglishStatus.Tone = .calm
    ) -> ControlBoard {
        let services = snapshot?.services ?? []
        let paused = snapshot?.dns?.blockingEnabled == false
        return ControlBoard(
            headline: headline,
            checkedLine: checkedLine(snapshot: snapshot, now: now),
            blocker: blocker(share: share, enabled: snapshot?.dns?.blockingEnabled),
            pi: pi(snapshot?.machine),
            squares: squares(services: services, paused: paused),
            monitors: monitors(services),
            backups: backups(services),
            running: running(snapshot?.machine),
            devices: devices(deviceCount),
            tone: tone
        )
    }

    private static func checkedLine(snapshot: HouseholdSnapshot?, now: Date) -> String {
        guard let snapshot else { return "Not checked yet" }
        return "Checked \(AgePhrase.english(from: snapshot.referenceDate, to: now))"
    }

    private static func blocker(share: LookupShare?, enabled: Bool?) -> BlockerTile {
        let on = enabled == true
        let percent = share?.percent ?? 0
        return BlockerTile(
            stateWord: stateWord(enabled: enabled),
            percentText: share?.percentText ?? "—",
            fraction: Double(percent) / 100,
            fractionLine: share?.fractionLine ?? LookupFraction.line(stopped: 0, lookups: 0),
            explainer: share?.explainer ?? LookupFraction.explainer(stopped: 0, lookups: 0),
            canPause: on
        )
    }

    private static func stateWord(enabled: Bool?) -> String {
        switch enabled {
        case true:
            "ON"
        case false:
            "Paused"
        case nil:
            "—"
        }
    }

    private static func pi(_ machine: MachineReading?) -> PiTile {
        guard let machine else {
            return PiTile(
                temperature: "—",
                warmth: "—",
                line: "No reading from the Pi yet.",
                cpu: nil,
                memory: nil,
                disk: nil
            )
        }
        guard let degrees = machine.temperatureCelsius else {
            return PiTile(
                temperature: "—",
                warmth: "—",
                line: "No temperature from the Pi yet.",
                cpu: machine.cpuUsedFraction,
                memory: machine.memoryUsedFraction,
                disk: machine.diskUsedFraction
            )
        }
        let warmth = PiWarmth.word(celsius: degrees)
        return PiTile(
            temperature: ReadingText.celsius(degrees),
            warmth: warmth,
            line: PiWarmth.line(for: warmth),
            cpu: machine.cpuUsedFraction,
            memory: machine.memoryUsedFraction,
            disk: machine.diskUsedFraction
        )
    }

    private static func squares(services: [ServiceHealth], paused: Bool) -> [ServiceSquare] {
        SquarePlan.all.map { plan in
            let members = services.filter { $0.kind.houseGroup == plan.group }
            let state = squareState(group: plan.group, members: members, paused: paused)
            return ServiceSquare(
                id: plan.id,
                title: plan.title,
                word: state.word,
                tone: state.tone,
                group: plan.group
            )
        }
    }

    private static func monitors(_ services: [ServiceHealth]) -> MonitorTile {
        let marks = services.map { service in
            MonitorMark(
                id: service.id,
                name: service.name,
                up: service.state == .responding,
                word: ReadingText.stateWord(for: service)
            )
        }
        let up = marks.filter(\.up).count
        let total = marks.count
        if total == 0 {
            return MonitorTile(figure: "None", line: "No monitors yet.", marks: [])
        }
        let line = up == total ? "All \(total) are answering." : "\(up) of \(total) are answering."
        return MonitorTile(figure: "\(up) of \(total)", line: line, marks: marks)
    }

    private static func backups(_ services: [ServiceHealth]) -> BackupTile {
        let copies = services.filter { $0.kind == .backup }
        if copies.isEmpty {
            return BackupTile(figure: "None", line: "No backup has been recorded.", tone: .attention)
        }
        if copies.contains(where: { $0.state == .notResponding }) {
            return BackupTile(figure: "Down", line: "The weekly copy did not finish.", tone: .problem)
        }
        if copies.allSatisfy({ $0.state == .responding }) {
            return BackupTile(figure: "Copied", line: "The weekly copy succeeded.", tone: .calm)
        }
        return BackupTile(figure: "Trouble", line: "The weekly copy needs a look.", tone: .attention)
    }

    private static func running(_ machine: MachineReading?) -> RunningTile {
        guard let seconds = machine?.uptimeSeconds else {
            return RunningTile(figure: "—", line: "No reading for how long the Pi has been on.")
        }
        return RunningTile(figure: RuntimePhrase.figure(seconds: seconds), line: RuntimePhrase.line(seconds: seconds))
    }

    private static func devices(_ count: Int?) -> DevicesTile {
        guard let count else {
            return DevicesTile(figure: "—", line: "No devices have been counted yet.")
        }
        if count == 1 {
            return DevicesTile(figure: "1", line: "1 device has asked for a name.")
        }
        return DevicesTile(figure: "\(count)", line: "\(count) devices have asked for a name.")
    }

    private static func squareState(
        group: HouseGroup,
        members: [ServiceHealth],
        paused: Bool
    ) -> (word: String, tone: PlainEnglishStatus.Tone) {
        if members.isEmpty {
            return ("Quiet", .attention)
        }
        if members.contains(where: { $0.state == .notResponding }) {
            return ("Down", .problem)
        }
        if members.contains(where: { $0.state == .degraded || $0.state == .unknown }) {
            return ("Trouble", .attention)
        }
        if members.contains(where: { $0.state == .maintenance }) {
            return ("Paused", .attention)
        }
        if group == .adBlockerAndDNS, paused {
            return ("Paused", .attention)
        }
        return calmSquare(group)
    }

    private static func calmSquare(_ group: HouseGroup) -> (word: String, tone: PlainEnglishStatus.Tone) {
        switch group {
        case .remoteHelp:
            ("Ready", .calm)
        case .internet:
            ("Current", .calm)
        case .adBlockerAndDNS:
            ("On", .calm)
        default:
            ("Up", .calm)
        }
    }

    private struct SquarePlan {
        var id: String
        var title: String
        var group: HouseGroup

        static let all: [SquarePlan] = [
            SquarePlan(id: "streaming", title: "Streaming", group: .streaming),
            SquarePlan(id: "remote", title: "Remote", group: .remoteHelp),
            SquarePlan(id: "dns", title: "DNS", group: .adBlockerAndDNS),
            SquarePlan(id: "address", title: "Address", group: .internet),
        ]
    }
}
