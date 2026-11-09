import Foundation

/// Which road the app takes to the house.
public enum ConnectionMode: Sendable, Equatable {
    /// The Pi answered on the home network. Everything works.
    case home
    /// The Pi is out of reach and the gateway answered. Everything still works.
    case awayLive(AwayGatewaySettings)
    /// Only the mailbox is left. The app can look, not change.
    case awayMailbox(MailboxSetup)
    /// Nothing answered. The app keeps trying.
    case offline

    public static func choose(
        piAnswered: Bool,
        gateway: AwayGatewaySettings?,
        gatewayAnswered: Bool,
        mailbox: MailboxSetup?
    ) -> ConnectionMode {
        if piAnswered { return .home }
        if let gateway, gatewayAnswered { return .awayLive(gateway) }
        if let mailbox { return .awayMailbox(mailbox) }
        return .offline
    }

    /// A good read does not prove the road while the live gateway or the mailbox
    /// is all that answered, nothing answered, or the away key is in doubt.
    /// Those keep looking until a probe says otherwise.
    public func looksAgain(readFailed: Bool, keyRejected: Bool) -> Bool {
        if case .awayLive = self { return true }
        if case .awayMailbox = self { return true }
        return readFailed || keyRejected || self == .offline
    }

    /// Offline keeps the last house on screen. A read that worked stays off it until a probe
    /// leaves that road, so the house cannot look live under "Can't reach the Pi".
    /// A missed read can still land. Every other road shows the read it just got.
    public func paintsHouse(readSucceeded: Bool) -> Bool {
        self != .offline || readSucceeded == false
    }

    /// A failed ad-blocker poll builds an empty desk. Offline does not take it, so pause and the
    /// day's counts stay. A success is already withheld by `paintsHouse`. Every other road takes the poll.
    public func takesAdBlockerDesk(pollFailed: Bool) -> Bool {
        if self == .offline, pollFailed { return false }
        return paintsHouse(readSucceeded: pollFailed == false)
    }

    /// The mailbox is view-only. Offline also holds pause, block, and allow, because those
    /// writes would change the house under "Can't reach the Pi". Face ID is `ActionPolicy`.
    public func allows(_ action: HouseholdAction) -> Bool {
        switch self {
        case .awayMailbox:
            return AwayGate.allows(action)
        case .offline:
            switch action {
            case .pauseAdBlocking, .resumeAdBlocking, .blockDomain, .allowDomain:
                return false
            case .refresh, .updateBlockLists, .signOutOfAdBlocker:
                return true
            }
        case .home, .awayLive:
            return true
        }
    }
}

/// Tries each road in order and stops at the first that answers.
public struct ConnectionProber: Sendable {
    public var piAnswers: @Sendable () async -> Bool
    public var gatewayAnswers: @Sendable (AwayGatewaySettings) async -> Bool

    public init(
        piAnswers: @escaping @Sendable () async -> Bool,
        gatewayAnswers: @escaping @Sendable (AwayGatewaySettings) async -> Bool
    ) {
        self.piAnswers = piAnswers
        self.gatewayAnswers = gatewayAnswers
    }

    public func mode(gateway: AwayGatewaySettings?, mailbox: MailboxSetup?) async -> ConnectionMode {
        if await piAnswers() { return .home }
        var answered = false
        if let gateway {
            answered = await gatewayAnswers(gateway)
        }
        return ConnectionMode.choose(
            piAnswered: false,
            gateway: gateway,
            gatewayAnswered: answered,
            mailbox: mailbox
        )
    }
}

/// Why the app looked for the house again.
public enum ConnectionTrigger: Sendable, Equatable {
    case launch
    case foreground
    case requestFailed
    /// The phone moved to a different network.
    case pathChanged
    /// A pull to refresh.
    case manual
    /// Saved gateway credentials or its switch changed.
    case settingsChanged
}

/// Keeps the app from flapping. A new road waits out the dwell unless the phone
/// moved, saved settings changed, or the person pulled to refresh.
public struct ConnectionDwell: Sendable, Equatable {
    public static let minimumSeconds: TimeInterval = 10

    public private(set) var current: ConnectionMode?
    private var since: Date?
    private var reprobePending = false
    private var lastReprobe: Date?

    public init() {}

    /// The mode to use. A held change returns the current mode.
    public mutating func settle(
        _ probed: ConnectionMode,
        trigger: ConnectionTrigger,
        now: Date
    ) -> ConnectionMode {
        guard let current else {
            adopt(probed, now: now)
            return probed
        }
        guard probed != current else { return current }
        let askedNow = trigger == .pathChanged || trigger == .settingsChanged || trigger == .manual
        guard askedNow || secondsLeft(now: now) == 0 else {
            return current
        }
        adopt(probed, now: now)
        return probed
    }

    public func secondsLeft(now: Date) -> TimeInterval {
        guard let since else { return 0 }
        return max(0, Self.minimumSeconds - now.timeIntervalSince(since))
    }

    /// Failed reads can look again after the cooldown, with only one probe in flight.
    public mutating func wantsReprobe(now: Date) -> Bool {
        guard !reprobePending else { return false }
        if let lastReprobe, now.timeIntervalSince(lastReprobe) < Self.minimumSeconds {
            return false
        }
        reprobePending = true
        return true
    }

    public mutating func reprobeFinished(now: Date) {
        reprobePending = false
        lastReprobe = now
    }

    public mutating func requestSucceeded() {
        lastReprobe = nil
    }

    private mutating func adopt(_ mode: ConnectionMode, now: Date) {
        current = mode
        since = now
        lastReprobe = nil
    }
}
