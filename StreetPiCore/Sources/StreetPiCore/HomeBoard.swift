import Foundation

/// What Home shows. A later reader can build this and leave the views alone.
public struct HomeBoard: Sendable, Equatable {
    public var title: String
    public var statusTitle: String
    public var statusAccent: String
    public var statusTone: PlainEnglishStatus.Tone
    public var statusDetail: String?
    public var checkedLine: String
    public var adBlocker: HomeAdBlockerReading
    public var pi: HomePiReading
    public var services: [HomeServiceSquare]
    public var monitors: HomeMonitorBoard
    public var backups: HomeBackupReading
    public var uptime: HomeFact
    public var devices: HomeFact
    public var footer: String

    public init(
        title: String,
        statusTitle: String,
        statusAccent: String,
        statusTone: PlainEnglishStatus.Tone,
        statusDetail: String?,
        checkedLine: String,
        adBlocker: HomeAdBlockerReading,
        pi: HomePiReading,
        services: [HomeServiceSquare],
        monitors: HomeMonitorBoard,
        backups: HomeBackupReading,
        uptime: HomeFact,
        devices: HomeFact,
        footer: String
    ) {
        self.title = title
        self.statusTitle = statusTitle
        self.statusAccent = statusAccent
        self.statusTone = statusTone
        self.statusDetail = statusDetail
        self.checkedLine = checkedLine
        self.adBlocker = adBlocker
        self.pi = pi
        self.services = services
        self.monitors = monitors
        self.backups = backups
        self.uptime = uptime
        self.devices = devices
        self.footer = footer
    }
}

public struct HomeAdBlockerReading: Sendable, Equatable {
    public var isOn: Bool
    public var stateWord: String
    public var blockingLine: String
    public var percentText: String
    public var ringFraction: Double
    public var fractionLine: String
    public var blockedText: String
    public var lookupsText: String
    public var lastHourText: String
    public var stoppedLine: String
    public var lookupsLine: String
    public var lastHourLine: String
    public var hourlyStopped: [HomeHourBar]
    public var explainer: String
    public var spoken: String

    public init(
        isOn: Bool,
        stateWord: String,
        blockingLine: String,
        percentText: String,
        ringFraction: Double,
        fractionLine: String,
        blockedText: String,
        lookupsText: String,
        lastHourText: String,
        stoppedLine: String,
        lookupsLine: String,
        lastHourLine: String,
        hourlyStopped: [HomeHourBar],
        explainer: String,
        spoken: String
    ) {
        self.isOn = isOn
        self.stateWord = stateWord
        self.blockingLine = blockingLine
        self.percentText = percentText
        self.ringFraction = ringFraction
        self.fractionLine = fractionLine
        self.blockedText = blockedText
        self.lookupsText = lookupsText
        self.lastHourText = lastHourText
        self.stoppedLine = stoppedLine
        self.lookupsLine = lookupsLine
        self.lastHourLine = lastHourLine
        self.hourlyStopped = hourlyStopped
        self.explainer = explainer
        self.spoken = spoken
    }
}

public struct HomeHourBar: Sendable, Equatable, Identifiable {
    public var hour: Int
    public var stopped: Int

    public var id: Int { hour }

    public init(hour: Int, stopped: Int) {
        self.hour = hour
        self.stopped = stopped
    }
}

public struct HomePiReading: Sendable, Equatable {
    public var temperature: String
    public var warmth: String
    public var warmthTone: PlainEnglishStatus.Tone
    public var line: String
    public var meters: [HomeMeter]
    public var spoken: String

    public init(
        temperature: String,
        warmth: String,
        warmthTone: PlainEnglishStatus.Tone,
        line: String,
        meters: [HomeMeter],
        spoken: String
    ) {
        self.temperature = temperature
        self.warmth = warmth
        self.warmthTone = warmthTone
        self.line = line
        self.meters = meters
        self.spoken = spoken
    }
}

public struct HomeMeter: Sendable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var fraction: Double
    public var value: String

    public init(id: String, title: String, fraction: Double, value: String) {
        self.id = id
        self.title = title
        self.fraction = fraction
        self.value = value
    }
}

public struct HomeServiceSquare: Sendable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var word: String
    public var tone: PlainEnglishStatus.Tone
    public var symbol: String
    public var group: HouseGroup
    public var spoken: String

    public init(
        id: String,
        title: String,
        word: String,
        tone: PlainEnglishStatus.Tone,
        symbol: String,
        group: HouseGroup,
        spoken: String
    ) {
        self.id = id
        self.title = title
        self.word = word
        self.tone = tone
        self.symbol = symbol
        self.group = group
        self.spoken = spoken
    }
}

public struct HomeMonitorBoard: Sendable, Equatable {
    public var title: String
    public var summary: String
    public var line: String
    public var monitors: [HomeMonitor]

    public init(title: String, summary: String, line: String, monitors: [HomeMonitor]) {
        self.title = title
        self.summary = summary
        self.line = line
        self.monitors = monitors
    }
}

public struct HomeMonitor: Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var word: String
    public var tone: PlainEnglishStatus.Tone
    public var group: HouseGroup
    public var spoken: String

    public init(
        id: String,
        name: String,
        word: String,
        tone: PlainEnglishStatus.Tone,
        group: HouseGroup,
        spoken: String
    ) {
        self.id = id
        self.name = name
        self.word = word
        self.tone = tone
        self.group = group
        self.spoken = spoken
    }
}

public struct HomeBackupReading: Sendable, Equatable {
    public var title: String
    public var value: String
    public var line: String
    public var tone: PlainEnglishStatus.Tone
    public var group: HouseGroup
    public var spoken: String

    public init(
        title: String,
        value: String,
        line: String,
        tone: PlainEnglishStatus.Tone,
        group: HouseGroup,
        spoken: String
    ) {
        self.title = title
        self.value = value
        self.line = line
        self.tone = tone
        self.group = group
        self.spoken = spoken
    }
}

public struct HomeFact: Sendable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var value: String
    public var line: String
    public var spoken: String

    public init(id: String, title: String, value: String, line: String, spoken: String) {
        self.id = id
        self.title = title
        self.value = value
        self.line = line
        self.spoken = spoken
    }
}

public enum BlockedShare {
    public static func percent(blocked: Int, lookups: Int) -> Int? {
        guard lookups > 0 else { return nil }
        return Int((Double(blocked) / Double(lookups) * 100).rounded())
    }

    /// Plain sentence for blocked ÷ lookups. One share, no extra claim.
    public static func line(blocked: Int, lookups: Int) -> String {
        guard lookups > 0 else {
            return "No lookups in the last 24 hours."
        }
        guard blocked > 0 else {
            return "Nothing your devices tried to load was an ad or tracker."
        }
        let nearest = Int((Double(lookups) / Double(blocked)).rounded())
        if nearest <= 1 {
            return "Almost everything your devices tried to load was an ad or tracker."
        }
        return "About 1 in \(nearest) things your devices tried to load was an ad or tracker."
    }
}

enum HomeCountText {
    static func grouped(_ value: Int) -> String {
        let digits = String(abs(value))
        var groups: [String] = []
        var index = digits.endIndex
        while index != digits.startIndex {
            let start = digits.index(index, offsetBy: -3, limitedBy: digits.startIndex) ?? digits.startIndex
            groups.append(String(digits[start..<index]))
            index = start
        }
        let body = groups.reversed().joined(separator: ",")
        return value < 0 ? "-\(body)" : body
    }
}

enum CheckedPhrase {
    static func english(from past: Date?, now: Date) -> String {
        guard let past else { return "Not checked yet" }
        let seconds = max(0, now.timeIntervalSince(past))
        if seconds < 60 {
            return "Checked just now"
        }
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return minutes == 1 ? "Checked 1 min ago" : "Checked \(minutes) min ago"
        }
        let hours = Int(seconds / 3_600)
        if hours < 24 {
            return hours == 1 ? "Checked 1 hour ago" : "Checked \(hours) hours ago"
        }
        let days = max(1, Int(seconds / 86_400))
        return days == 1 ? "Checked 1 day ago" : "Checked \(days) days ago"
    }
}

enum PiWarmthWord {
    static func word(celsius: Double) -> String {
        if celsius >= MachineLimits.hotCelsius {
            return "Hot"
        }
        if celsius >= MachineLimits.warmCelsius {
            return "Warm"
        }
        return "Cool"
    }

    static func tone(celsius: Double) -> PlainEnglishStatus.Tone {
        if celsius >= MachineLimits.hotCelsius {
            return .problem
        }
        if celsius >= MachineLimits.warmCelsius {
            return .attention
        }
        return .calm
    }
}

enum RunningForCopy {
    static func value(seconds: TimeInterval) -> String {
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

    static func line(seconds: TimeInterval) -> String {
        if seconds < 3_600 {
            return "The Pi has been on for less than an hour."
        }
        return "The Pi has been on for \(value(seconds: seconds))."
    }
}
