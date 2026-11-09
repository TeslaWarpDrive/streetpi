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

/// The last good reports. A failed latest read keeps them and says so on the badge.
/// A failed history read stays on the chart and does not replace that badge.
public struct AwaySession: Sendable, Equatable {
    public private(set) var latest: AwaySnapshot?
    public private(set) var history: AwaySnapshot?
    public private(set) var problem: MailboxProblem?
    /// Set when the day's chart could not be read and a latest report is still showing.
    public private(set) var historyProblem: MailboxProblem?
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

    /// Only cancellation throws. A latest failure lands in `problem`.
    /// A history failure lands in `historyProblem` once a report is showing, and in `problem` only when it is not.
    public func refreshed<Transport>(using client: MailboxClient<Transport>, now: Date) async throws -> AwaySession {
        var next = self
        do {
            next.latest = try await client.latest() ?? latest
            next.problem = nil
        } catch let failure as MailboxProblem {
            next.problem = failure
            return next
        }
        guard next.wantsHistory(now: now) else { return next }
        next.historyAskedAt = now
        do {
            next.history = try await client.history() ?? history
            next.historyProblem = nil
        } catch let failure as MailboxProblem {
            if next.latest == nil {
                next.problem = failure
            } else {
                next.historyProblem = failure
            }
        }
        return next
    }

    public var board: AwayBoard {
        guard let latest else { return .waiting }
        var board = AwayBoard.make(latest: latest, history: history)
        if let historyProblem {
            board.machine.chartNote = AwayCopy.problem(historyProblem)
        }
        return board
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
