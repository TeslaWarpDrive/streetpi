import Foundation

public struct AdBlockerTile: Sendable, Equatable {
    public var percentText: String?
    public var window: String?
    public var line: String
    public var tone: PlainEnglishStatus.Tone

    public init(
        percentText: String?,
        window: String?,
        line: String,
        tone: PlainEnglishStatus.Tone
    ) {
        self.percentText = percentText
        self.window = window
        self.line = line
        self.tone = tone
    }
}

public enum AdBlockerVoice {
    public static let window = "Last 24 hours"
    public static let unreachableTitle = "The ad blocker is not answering."
    public static let unreachableDetail = """
    This phone can't see the ad blocker right now. Nothing was changed. \
    Raspberry Pi Stats will try again on its own.
    """
    public static let notSetUpTitle = "The ad blocker is not set up."
    public static let dnsOffTitle = "The ad blocker is not running."

    public static func line(blocked: Int, total: Int, blockingEnabled: Bool) -> String {
        let blockedCount = max(0, blocked)
        let totalCount = max(0, total)
        let percent = percentText(blocked: blockedCount, total: totalCount)
        if !blockingEnabled {
            if let percent {
                return "Ad blocking is paused. Blocked \(percent) of lookups in the last 24 hours."
            }
            return "Ad blocking is paused."
        }
        guard let percent else {
            return "No lookups in the last 24 hours."
        }
        if blockedCount == 0 {
            return "Nothing was blocked in the last 24 hours."
        }
        return "Blocked \(percent) of lookups in the last 24 hours."
    }

    public static func percentText(blocked: Int, total: Int) -> String? {
        guard total > 0 else { return nil }
        let fraction = Double(max(0, blocked)) / Double(total)
        return ReadingText.percent(fraction)
    }

    public static func upkeep(textLogOn: Bool, listsKnown: Bool) -> String {
        let log = textLogOn ? "The text log file is on." : "The text log file is off."
        let lists = listsKnown
            ? "The block lists have an update time."
            : "The block lists have not reported an update."
        return "\(lists) \(log) Lookups are still kept. This phone does not change settings on the Pi."
    }
}

public struct AdBlockerBoard: Sendable, Equatable {
    public var desk: DNSDesk
    public var tile: AdBlockerTile
    public var status: PlainEnglishStatus
    public var snapshot: HouseholdSnapshot
    public var problem: PiholeProblem?

    public init(
        desk: DNSDesk,
        tile: AdBlockerTile,
        status: PlainEnglishStatus,
        snapshot: HouseholdSnapshot,
        problem: PiholeProblem?
    ) {
        self.desk = desk
        self.tile = tile
        self.status = status
        self.snapshot = snapshot
        self.problem = problem
    }
}

public enum AdBlockerHome {
    public static func ready(_ load: PiholeDeskLoad, now: Date) -> AdBlockerBoard {
        let state: Reachability = load.blockingEnabled ? .responding : .maintenance
        let tone: PlainEnglishStatus.Tone = load.blockingEnabled ? .calm : .attention
        let tile = AdBlockerTile(
            percentText: AdBlockerVoice.percentText(blocked: load.blocked, total: load.total),
            window: AdBlockerVoice.window,
            line: load.desk.blockingLine,
            tone: tone
        )
        return make(
            Parts(
                desk: load.desk,
                tile: tile,
                title: load.desk.blockingLine,
                detail: nil,
                tone: tone,
                link: "On the home network",
                state: state,
                summary: DNSSummary(
                    blockingEnabled: load.blockingEnabled,
                    queriesToday: load.total,
                    blockedToday: load.blocked
                ),
                problem: nil
            ),
            now: now
        )
    }

    public static func offline(now: Date) -> AdBlockerBoard {
        quiet(
            Quiet(
                problem: .offline,
                title: AdBlockerVoice.unreachableTitle,
                detail: AdBlockerVoice.unreachableDetail,
                state: .notResponding,
                tone: .problem,
                link: "Not connected"
            ),
            now: now
        )
    }

    public static func notSetUp(now: Date) -> AdBlockerBoard {
        quiet(
            Quiet(
                problem: .notSetUp,
                title: AdBlockerVoice.notSetUpTitle,
                detail: PiholeProblem.notSetUp.detail,
                state: .unknown,
                tone: .attention,
                link: "On this phone"
            ),
            now: now
        )
    }

    public static func dnsOff(now: Date) -> AdBlockerBoard {
        quiet(
            Quiet(
                problem: .dnsOff,
                title: AdBlockerVoice.dnsOffTitle,
                detail: PiholeProblem.dnsOff.detail,
                state: .notResponding,
                tone: .problem,
                link: "On the home network"
            ),
            now: now
        )
    }

    public static func failed(_ problem: PiholeProblem, now: Date) -> AdBlockerBoard {
        quiet(
            Quiet(
                problem: problem,
                title: problem.title,
                detail: problem.detail,
                state: .notResponding,
                tone: .problem,
                link: "Not connected"
            ),
            now: now
        )
    }

    private struct Quiet {
        var problem: PiholeProblem
        var title: String
        var detail: String
        var state: Reachability
        var tone: PlainEnglishStatus.Tone
        var link: String
    }

    private struct Parts {
        var desk: DNSDesk
        var tile: AdBlockerTile
        var title: String
        var detail: String?
        var tone: PlainEnglishStatus.Tone
        var link: String
        var state: Reachability
        var summary: DNSSummary?
        var problem: PiholeProblem?
    }

    private static func quiet(_ item: Quiet, now: Date) -> AdBlockerBoard {
        let tile = AdBlockerTile(percentText: nil, window: nil, line: item.title, tone: item.tone)
        var desk = DNSDesk.emptyLookups
        desk.spokenLine = item.title
        desk.listsUpdateKnown = false
        desk.upkeepNote = item.detail
        desk.textLogKnown = false
        desk.services = []
        return make(
            Parts(
                desk: desk,
                tile: tile,
                title: item.title,
                detail: item.detail,
                tone: item.tone,
                link: item.link,
                state: item.state,
                summary: nil,
                problem: item.problem
            ),
            now: now
        )
    }

    private static func make(_ parts: Parts, now: Date) -> AdBlockerBoard {
        let snapshot = HouseholdSnapshot(
            capturedAt: now,
            link: .homeNetwork,
            services: [
                ServiceHealth(id: "ad-blocker", name: "Ad blocker", kind: .dnsFilter, state: parts.state),
            ],
            machine: nil,
            dns: parts.summary
        )
        let status = PlainEnglishStatus(
            headline: parts.title,
            detail: parts.detail,
            tone: parts.tone,
            linkLine: parts.link
        )
        return AdBlockerBoard(
            desk: parts.desk,
            tile: parts.tile,
            status: status,
            snapshot: snapshot,
            problem: parts.problem
        )
    }
}
