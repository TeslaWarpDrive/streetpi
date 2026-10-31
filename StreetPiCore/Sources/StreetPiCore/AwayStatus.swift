import Foundation

/// Which road the app takes to the house.
public enum HouseMode: Sendable, Equatable {
    /// The Pi answered. Everything works.
    case home
    /// The Pi did not answer, so the app reads the mailbox.
    case away(MailboxSetup)
    /// The Pi did not answer and no mailbox is saved. The app keeps trying the Pi.
    case homeOnly

    public static func choose(piAnswered: Bool, setup: MailboxSetup?) -> HouseMode {
        if piAnswered { return .home }
        if let setup { return .away(setup) }
        return .homeOnly
    }
}

/// How old a report is, in the words the badge uses.
public struct AwayFreshness: Sendable, Equatable {
    public static let staleAfter: TimeInterval = 60
    public static let silentAfter: TimeInterval = 180

    public enum Level: Sendable, Equatable {
        case fresh
        case stale
        case silent
    }

    public var level: Level
    public var line: String
    public var spoken: String

    public static func make(generatedAt: Date, now: Date) -> AwayFreshness {
        let age = max(0, now.timeIntervalSince(generatedAt))
        let seconds = Int(age)
        let minutes = seconds / 60
        if age >= silentAfter {
            let span = span(minutes: minutes)
            return AwayFreshness(
                level: .silent,
                line: "Pi hasn't reported in \(span.short)",
                spoken: "The Pi hasn't reported in \(span.spoken)."
            )
        }
        if age >= staleAfter {
            return AwayFreshness(
                level: .stale,
                line: "Away · updated \(minutes) min ago",
                spoken: "Away from home. Updated \(span(minutes: minutes).spoken) ago."
            )
        }
        return AwayFreshness(
            level: .fresh,
            line: "Away · updated \(seconds)s ago",
            spoken: "Away from home. Updated \(seconds == 1 ? "1 second" : "\(seconds) seconds") ago."
        )
    }

    private static func span(minutes: Int) -> (short: String, spoken: String) {
        if minutes < 120 {
            return ("\(minutes) min", minutes == 1 ? "1 minute" : "\(minutes) minutes")
        }
        let hours = minutes / 60
        return ("\(hours) hr", "\(hours) hours")
    }
}

/// What the app knows about its connection to the house while the Pi is out of reach.
public enum AwayStatus: Sendable, Equatable {
    /// No mailbox is saved. Controls stay open because the app is still trying the Pi.
    case notSetUp
    case reading(generatedAt: Date?, problem: MailboxProblem?, note: String?)

    /// Private pages and every write are held back.
    public var isAway: Bool {
        if case .reading = self { return true }
        return false
    }

    public func badge(now: Date) -> AwayBadge {
        switch self {
        case .notSetUp:
            return AwayBadge(
                line: AwayCopy.notSetUp,
                detail: AwayCopy.notSetUpDetail,
                tone: .attention,
                symbol: "wifi.slash",
                spoken: "\(AwayCopy.notSetUp). \(AwayCopy.notSetUpDetail)",
                offersSetup: true
            )
        case .reading(nil, nil, _):
            return AwayBadge(
                line: AwayCopy.waitingFirstReport,
                detail: nil,
                tone: .attention,
                symbol: "hourglass",
                spoken: AwayCopy.waitingFirstReport,
                offersSetup: false
            )
        case .reading(nil, let problem?, _):
            let line = AwayCopy.problem(problem)
            return AwayBadge(
                line: line,
                detail: nil,
                tone: .problem,
                symbol: "exclamationmark.triangle",
                spoken: line,
                offersSetup: problem == .refused || problem == .wrongAddress
            )
        case .reading(let generatedAt?, let problem, let note):
            return badge(
                freshness: AwayFreshness.make(generatedAt: generatedAt, now: now),
                problem: problem,
                note: note
            )
        }
    }

    private func badge(freshness: AwayFreshness, problem: MailboxProblem?, note: String?) -> AwayBadge {
        let detail = problem.map(AwayCopy.problem) ?? note
        let spoken = [freshness.spoken, detail].compactMap { $0 }.joined(separator: " ")
        switch freshness.level {
        case .fresh:
            return AwayBadge(
                line: freshness.line, detail: detail, tone: .calm,
                symbol: "antenna.radiowaves.left.and.right", spoken: spoken, offersSetup: false
            )
        case .stale:
            return AwayBadge(
                line: freshness.line, detail: detail, tone: .attention,
                symbol: "clock.badge.exclamationmark", spoken: spoken, offersSetup: false
            )
        case .silent:
            return AwayBadge(
                line: freshness.line, detail: detail, tone: .problem,
                symbol: "exclamationmark.triangle", spoken: spoken, offersSetup: false
            )
        }
    }
}

/// One small status line. The symbol changes with the tone, so status is never color alone.
public struct AwayBadge: Sendable, Equatable {
    public var line: String
    public var detail: String?
    public var tone: PlainEnglishStatus.Tone
    public var symbol: String
    public var spoken: String
    public var offersSetup: Bool

    public init(
        line: String,
        detail: String?,
        tone: PlainEnglishStatus.Tone,
        symbol: String,
        spoken: String,
        offersSetup: Bool
    ) {
        self.line = line
        self.detail = detail
        self.tone = tone
        self.symbol = symbol
        self.spoken = spoken
        self.offersSetup = offersSetup
    }
}

/// What stays behind the home network. Away is view-only, and private lists never leave the house.
public enum AwayGate {
    public static func allows(_ page: DNSPage) -> Bool {
        page == .today
    }

    public static func allows(_ page: MachinePage) -> Bool {
        page != .containers
    }

    public static func allows(_ action: HouseholdAction) -> Bool {
        action == .refresh
    }
}
