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

    /// Whether a finished read should send the app looking for the house again.
    public func looksAgain(readFailed: Bool, keyRejected: Bool) -> Bool {
        readFailed
    }

    /// Only the mailbox holds actions back. Face ID is decided by `ActionPolicy` in every mode.
    public func allows(_ action: HouseholdAction) -> Bool {
        if case .awayMailbox = self { return AwayGate.allows(action) }
        return true
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

/// Keeps the app from flapping. A new road waits out the dwell unless the phone really moved.
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
        guard trigger == .pathChanged || trigger == .settingsChanged || secondsLeft(now: now) == 0 else {
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
