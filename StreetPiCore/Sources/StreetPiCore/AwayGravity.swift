import Foundation

/// The block list numbers in `/api/stats/summary`. A new `lastUpdate` means gravity finished.
public struct GravityMark: Sendable, Equatable {
    public var lastUpdate: Double
    public var domains: Int?

    public init(lastUpdate: Double, domains: Int?) {
        self.lastUpdate = lastUpdate
        self.domains = domains
    }

    public static func decode(from data: Data) throws -> GravityMark {
        guard let wire = try? JSONDecoder().decode(SummaryWire.self, from: data),
              let lastUpdate = wire.gravity?.lastUpdate
        else { throw PiholeProblem.notUnderstood }
        return GravityMark(lastUpdate: lastUpdate, domains: wire.gravity?.domains)
    }

    private struct SummaryWire: Decodable {
        struct Gravity: Decodable {
            var lastUpdate: Double?
            var domains: Int?

            enum CodingKeys: String, CodingKey {
                case lastUpdate = "last_update"
                case domains = "domains_being_blocked"
            }
        }

        var gravity: Gravity?
    }
}

public enum AwayGravityStep: Sendable, Equatable {
    case updating
    case busyRetrying

    public var notice: ActionNotice {
        switch self {
        case .updating:
            ActionNotice(
                title: AwayCopy.gravityUpdatingTitle, detail: AwayCopy.gravityUpdatingDetail,
                failed: false, pending: true
            )
        case .busyRetrying:
            ActionNotice(
                title: AwayCopy.gravityBusyTitle, detail: AwayCopy.gravityBusyDetail, failed: false, pending: true
            )
        }
    }
}

/// A cut request does not prove whether gravity finished. Confirm through the summary before
/// reporting success; otherwise leave a check-back notice instead of an edge timeout error.
public struct AwayGravityFlow: Sendable {
    public static let pollSeconds = 15
    public static let maximumBackoffSeconds = 60
    public static let capSeconds = 600
    private static let readSeconds: TimeInterval = 5
    static let couldNotCheckTitle = "Could not check the block lists."
    static let couldNotCheckDetail = "The Pi did not answer, so the update may not have run. Try again later."

    private let client: PiholeClient
    private let now: @Sendable () -> Date
    private let sleep: @Sendable (Int) async throws -> Void
    private let onStep: @Sendable (AwayGravityStep) async -> Void
    private let timeLimit: TimeInterval
    private let timeoutSleep: @Sendable (TimeInterval) async throws -> Void

    public init(
        client: PiholeClient,
        now: @escaping @Sendable () -> Date = { Date() },
        timeLimit: TimeInterval = TimeInterval(Self.capSeconds),
        timeoutSleep: @escaping @Sendable (TimeInterval) async throws -> Void = {
            try await Task.sleep(for: .seconds($0))
        },
        sleep: @escaping @Sendable (Int) async throws -> Void,
        onStep: @escaping @Sendable (AwayGravityStep) async -> Void
    ) {
        self.client = client
        self.now = now
        self.timeLimit = timeLimit
        self.timeoutSleep = timeoutSleep
        self.sleep = sleep
        self.onStep = onStep
    }

    public static func backoffSeconds(afterFailures failures: Int) -> Int {
        min(pollSeconds << min(max(failures, 0), 3), maximumBackoffSeconds)
    }

    /// Only a problem from before the Pi started, or the Pi's own failure, throws.
    public func run() async throws -> ActionReceipt {
        let deadline = now().addingTimeInterval(timeLimit)
        do {
            let before = try await startingMark(deadline: deadline)
            await onStep(.updating)
            try await start(deadline: deadline)
            return try await checkBack(before: before, deadline: deadline)
        } catch GravityDeadline.reached {
            // Only the steps before the first poll get here, so nothing confirmed a run.
            return Self.couldNotCheck
        }
    }

    private func mark(deadline: Date) async throws -> GravityMark {
        try await bounded(deadline: deadline, seconds: Self.readSeconds) {
            try await client.gravityMark()
        }
    }

    private func startingMark(deadline: Date) async throws -> GravityMark {
        var failures = 0
        while true {
            do {
                return try await mark(deadline: deadline)
            } catch PiholeProblem.rateLimited {
                try await backOff(after: &failures, deadline: deadline)
            }
        }
    }

    private func start(deadline: Date) async throws {
        var failures = 0
        while true {
            do {
                _ = try await bounded(deadline: deadline, seconds: 310) {
                    try await client.updateGravity()
                }
                return
            } catch PiholeProblem.rateLimited {
                try await backOff(after: &failures, deadline: deadline)
            } catch PiholeProblem.offline, PiholeProblem.untrusted, PiholeProblem.busy {
                // The Pi may be running, or already was. Only the summary can say.
                return
            }
        }
    }

    private func backOff(after failures: inout Int, deadline: Date) async throws {
        let wait = Self.backoffSeconds(afterFailures: failures)
        guard deadline.timeIntervalSince(now()) > TimeInterval(wait) else { throw GravityDeadline.reached }
        failures += 1
        await onStep(.busyRetrying)
        try await sleep(wait)
    }

    private func checkBack(before: GravityMark, deadline: Date) async throws -> ActionReceipt {
        var failures = 0
        var answered = false
        var sawFinish = false
        func outOfTime() -> ActionReceipt {
            if sawFinish { return finished(domains: nil) }
            return answered ? Self.stillUpdating : Self.couldNotCheck
        }
        while true {
            try Task.checkCancellation()
            let wait = failures == 0 ? Self.pollSeconds : Self.backoffSeconds(afterFailures: failures)
            // Reserve a final short look when another full wait would exhaust the budget.
            let finalLook = deadline.timeIntervalSince(now()) <= TimeInterval(wait) + Self.readSeconds
            if !finalLook { try await sleep(wait) }
            do {
                let current = try await mark(deadline: deadline)
                failures = 0
                answered = true
                if current.lastUpdate != before.lastUpdate {
                    // The stamp moves just before the Pi reloads, so the old count can still show.
                    if let domains = current.domains, domains >= 0, domains != before.domains || sawFinish {
                        return finished(domains: domains)
                    }
                    sawFinish = true
                } else {
                    await onStep(.updating)
                }
            } catch GravityDeadline.reached {
                return outOfTime()
            } catch PiholeProblem.rateLimited {
                failures += 1
                await onStep(.busyRetrying)
            } catch {
                try Task.checkCancellation()
            }
            if finalLook { return outOfTime() }
        }
    }

    /// Cancellation reaches URLSession through the client. A late reply cannot become success.
    /// The call runs in its own task, because waiting on a sign-in other readers share does not
    /// end on cancellation. That sign-in is left to finish for them.
    private func bounded<Value: Sendable>(
        deadline: Date,
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        let remaining = deadline.timeIntervalSince(now())
        guard remaining > 0 else { throw GravityDeadline.reached }
        let (outcome, finish) = AsyncThrowingStream<Value, any Error>.makeStream()
        let work = Task {
            do {
                finish.yield(try await operation())
                finish.finish()
            } catch {
                finish.finish(throwing: error)
            }
        }
        let timer = Task {
            try await timeoutSleep(min(seconds, remaining))
            finish.finish(throwing: remaining <= seconds ? GravityDeadline.reached : PiholeProblem.offline)
        }
        defer {
            work.cancel()
            timer.cancel()
        }
        do {
            var reply = outcome.makeAsyncIterator()
            guard let value = try await reply.next(), now() < deadline else { throw GravityDeadline.reached }
            try Task.checkCancellation()
            return value
        } catch {
            try Task.checkCancellation()
            if now() >= deadline { throw GravityDeadline.reached }
            throw error
        }
    }

    private func finished(domains: Int?) -> ActionReceipt {
        let detail = domains.map { "The Pi is now using \($0) domains on the block lists." }
        return ActionReceipt(
            title: "Block lists updated.",
            detail: detail ?? "The Pi finished updating the block lists.",
            listsUpdatedAt: now()
        )
    }

    private static var stillUpdating: ActionReceipt {
        ActionReceipt(title: AwayCopy.gravityStillTitle, detail: AwayCopy.gravityStillDetail, pending: true)
    }

    private static var couldNotCheck: ActionReceipt {
        ActionReceipt(title: couldNotCheckTitle, detail: couldNotCheckDetail, pending: true)
    }
}

private enum GravityDeadline: Error { case reached }
