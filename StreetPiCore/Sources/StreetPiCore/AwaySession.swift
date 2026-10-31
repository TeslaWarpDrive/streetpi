import Foundation

/// How often the app reads the mailbox while it is open and in front.
public enum AwayPace {
    public static let pollSeconds = 15
    /// Charts read `/v1/history` at most this often.
    public static let historySeconds: TimeInterval = 60

    public static func waitSeconds(afterFailures failures: Int) -> Int {
        failures == 0 ? pollSeconds : RefreshPace.waitSeconds(afterFailures: failures)
    }
}

/// The last good reports. A failed read keeps them on screen and says what went wrong.
public struct AwaySession: Sendable, Equatable {
    public private(set) var latest: AwaySnapshot?
    public private(set) var history: AwaySnapshot?
    public private(set) var problem: MailboxProblem?
    private var historyAskedAt: Date?

    public init() {}

    init(latest: AwaySnapshot?, history: AwaySnapshot?) {
        self.latest = latest
        self.history = history
    }

    func wantsHistory(now: Date) -> Bool {
        guard let historyAskedAt else { return true }
        return now.timeIntervalSince(historyAskedAt) >= AwayPace.historySeconds
    }

    /// Only cancellation throws. Every other failure lands in `problem`.
    public func refreshed<Transport>(using client: MailboxClient<Transport>, now: Date) async throws -> AwaySession {
        var next = self
        do {
            next.latest = try await client.latest() ?? latest
            next.problem = nil
            if next.wantsHistory(now: now) {
                next.historyAskedAt = now
                next.history = try await client.history() ?? history
            }
        } catch let failure as MailboxProblem {
            next.problem = failure
        }
        return next
    }

    public var board: AwayBoard {
        guard let latest else { return .waiting }
        return AwayBoard.make(latest: latest, history: history)
    }

    public var status: AwayStatus {
        .reading(generatedAt: latest?.generatedAt, problem: problem, note: latest.flatMap(Self.note))
    }

    private static func note(_ snapshot: AwaySnapshot) -> String? {
        let health = [snapshot.sources.adBlocker, snapshot.sources.machine, snapshot.sources.monitors]
        if health.contains(.error) { return AwayCopy.someMissing }
        if health.contains(.stale) { return AwayCopy.someEarlier }
        return nil
    }
}
