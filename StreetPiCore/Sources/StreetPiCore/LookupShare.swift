import Foundation

/// Blocked lookups against every lookup in one window, usually the last 24 hours.
/// Later phases can fill this from a live counter. The screens only read it.
public struct LookupShare: Sendable, Equatable {
    public var stopped: Int
    public var lookups: Int
    /// Stopped lookups for each hour, oldest first. Empty when the source has no hours.
    public var hourlyStopped: [Int]

    public init(stopped: Int, lookups: Int, hourlyStopped: [Int] = []) {
        self.stopped = max(0, stopped)
        self.lookups = max(lookups, 0)
        self.hourlyStopped = hourlyStopped.map { max(0, $0) }
    }

    public static func from(desk: DNSDesk) -> LookupShare {
        LookupShare(
            stopped: desk.blockedToday,
            lookups: desk.queriesToday,
            hourlyStopped: desk.day.map(\.blocked)
        )
    }

    /// Uses the desk's hours when the totals are the same reading. Otherwise the summary stands alone.
    public static func matching(summary: DNSSummary?, desk: DNSDesk) -> LookupShare? {
        guard let summary, let stopped = summary.blockedToday, let lookups = summary.queriesToday else {
            return nil
        }
        if desk.blockedToday == stopped, desk.queriesToday == lookups {
            return from(desk: desk)
        }
        return LookupShare(stopped: stopped, lookups: lookups)
    }

    public var percent: Int {
        LookupFraction.percent(stopped: stopped, lookups: lookups)
    }

    public var percentText: String {
        "\(percent)%"
    }

    public var fractionLine: String {
        LookupFraction.line(stopped: stopped, lookups: lookups)
    }

    public var explainer: String {
        LookupFraction.explainer(stopped: stopped, lookups: lookups)
    }

    public var lastHourStopped: Int? {
        hourlyStopped.last
    }
}

/// The plain-English fraction for a lookup window. Generated from the counts, never stored as a fixed sentence.
public enum LookupFraction {
    public static func percent(stopped: Int, lookups: Int) -> Int {
        let stopped = max(0, stopped)
        let lookups = max(0, lookups)
        guard lookups > 0 else { return 0 }
        let raw = (Double(stopped) / Double(lookups) * 100).rounded()
        return min(100, max(0, Int(raw)))
    }

    /// Whole number N in "1 in N". Nil when there is nothing to compare.
    public static func denominator(stopped: Int, lookups: Int) -> Int? {
        let stopped = max(0, stopped)
        let lookups = max(0, lookups)
        guard lookups > 0, stopped > 0 else { return nil }
        let ratio = (Double(lookups) / Double(stopped)).rounded()
        return max(1, Int(ratio))
    }

    public static func line(stopped: Int, lookups: Int) -> String {
        let stopped = max(0, stopped)
        let lookups = max(0, lookups)
        if lookups == 0 {
            return "No lookups in the last 24 hours."
        }
        if stopped == 0 {
            return "Nothing your devices tried to load was an ad or tracker."
        }
        guard let denominator = denominator(stopped: stopped, lookups: lookups) else {
            return "No lookups in the last 24 hours."
        }
        if denominator == 1 {
            return "About everything your devices tried to load was an ad or tracker."
        }
        return "About 1 in \(denominator) things your devices tried to load was an ad or tracker."
    }

    public static func explainer(stopped: Int, lookups: Int) -> String {
        let stopped = max(0, stopped)
        let lookups = max(0, lookups)
        let lead = "This percent is how many lookups were stopped, divided by every lookup in the last 24 hours."
        if lookups == 0 {
            return "\(lead) There are no lookups yet."
        }
        return "\(lead) \(line(stopped: stopped, lookups: lookups))"
    }
}
