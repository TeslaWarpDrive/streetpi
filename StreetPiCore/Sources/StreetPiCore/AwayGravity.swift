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
            ActionNotice(title: AwayCopy.gravityUpdatingTitle, detail: AwayCopy.gravityUpdatingDetail, failed: false)
        case .busyRetrying:
            ActionNotice(title: AwayCopy.gravityBusyTitle, detail: AwayCopy.gravityBusyDetail, failed: false)
        }
    }
}

/// Block lists away from home. The edge cuts a long request at about 100 seconds and the Pi keeps
/// working, so a timeout, a 524, or a dropped connection means "check back", not "failed".
public struct AwayGravityFlow: Sendable {
    public static let pollSeconds = 15
    public static let maximumBackoffSeconds = 60
    public static let capSeconds = 600

    private let client: PiholeClient
    private let now: @Sendable () -> Date
    private let sleep: @Sendable (Int) async throws -> Void
    private let onStep: @Sendable (AwayGravityStep) async -> Void

    public init(
        client: PiholeClient,
        now: @escaping @Sendable () -> Date = { Date() },
        sleep: @escaping @Sendable (Int) async throws -> Void,
        onStep: @escaping @Sendable (AwayGravityStep) async -> Void
    ) {
        self.client = client
        self.now = now
        self.sleep = sleep
        self.onStep = onStep
    }

    public static func backoffSeconds(afterFailures failures: Int) -> Int {
        min(pollSeconds << min(max(failures, 0), 3), maximumBackoffSeconds)
    }

    /// Only a problem from before the Pi started, or the Pi's own failure, throws.
    public func run() async throws -> ActionReceipt {
        let started = now()
        let before = try await startingMark(started: started)
        await onStep(.updating)
        if let receipt = try await start(started: started) {
            return receipt
        }
        return try await checkBack(before: before, started: started)
    }

    private func startingMark(started: Date) async throws -> GravityMark {
        var failures = 0
        while true {
            do {
                return try await client.gravityMark()
            } catch PiholeProblem.rateLimited {
                try await backOff(after: &failures, started: started)
            }
        }
    }

    /// A receipt when the Pi finished inside the request. Nil means it is time to check back.
    private func start(started: Date) async throws -> ActionReceipt? {
        var failures = 0
        while true {
            do {
                let report = try await client.updateGravity()
                return ActionReceipt(title: "Block lists updated.", detail: report.detail, listsUpdatedAt: now())
            } catch PiholeProblem.rateLimited {
                try await backOff(after: &failures, started: started)
            } catch PiholeProblem.offline {
                return nil
            }
        }
    }

    private func backOff(after failures: inout Int, started: Date) async throws {
        let wait = Self.backoffSeconds(afterFailures: failures)
        guard canWait(wait, started: started) else { throw PiholeProblem.rateLimited }
        failures += 1
        await onStep(.busyRetrying)
        try await sleep(wait)
    }

    private func checkBack(before: GravityMark, started: Date) async throws -> ActionReceipt {
        var failures = 0
        while true {
            let wait = failures == 0 ? Self.pollSeconds : Self.backoffSeconds(afterFailures: failures)
            guard canWait(wait, started: started) else { return Self.stillUpdating }
            try await sleep(wait)
            do {
                let mark = try await client.gravityMark()
                failures = 0
                if mark.lastUpdate != before.lastUpdate {
                    return finished(mark)
                }
                await onStep(.updating)
            } catch PiholeProblem.rateLimited {
                failures += 1
                await onStep(.busyRetrying)
            } catch {
                // The Pi can drop away while it swaps the lists in. Keep checking.
                try Task.checkCancellation()
            }
        }
    }

    private func canWait(_ seconds: Int, started: Date) -> Bool {
        now().timeIntervalSince(started) + TimeInterval(seconds) <= TimeInterval(Self.capSeconds)
    }

    private func finished(_ mark: GravityMark) -> ActionReceipt {
        let detail = mark.domains.map { "The Pi is now using \($0) domains on the block lists." }
        return ActionReceipt(
            title: "Block lists updated.",
            detail: detail ?? "The Pi finished updating the block lists.",
            listsUpdatedAt: now()
        )
    }

    private static var stillUpdating: ActionReceipt {
        ActionReceipt(title: AwayCopy.gravityStillTitle, detail: AwayCopy.gravityStillDetail)
    }
}
