import Foundation

/// Whether an away HTTP response is the key being refused.
/// A 403 on the health check, the login probe, Netdata, or Kuma is.
/// A 403 on Pi-hole's own calls is the Pi saying no.
public enum AwayKeySignal {
    public static func isRefusedKey(path: String, status: Int) -> Bool {
        guard status == 403 else { return false }
        switch path {
        case "/healthz", "/api/info/login":
            return true
        default:
            return isService(path, prefix: "/netdata") || isService(path, prefix: "/kuma")
        }
    }

    private static func isService(_ path: String, prefix: String) -> Bool {
        path == prefix || path.hasPrefix(prefix + "/")
    }
}

/// The health check and a later Pi-hole call have to agree before the live road is up.
/// The Pi-hole call is the later word. A 200 means the road is up, whatever health said.
/// Any other Pi-hole result means the road is down, even when health returned 200.
public enum LiveRoadAgreement {
    public static func isUp(healthStatus: Int?, piholeStatus: Int?) -> Bool {
        switch (healthStatus, piholeStatus) {
        case (_, 200):
            return true
        default:
            return false
        }
    }

    /// A 403 is a refused key unless that later Pi-hole call returned 200.
    public static func refusedKey(healthStatus: Int?, piholeStatus: Int?) -> Bool {
        if piholeStatus == 200 { return false }
        return piholeStatus == 403 || healthStatus == 403
    }
}

/// Holds a refused-key 403 until a refresh reads it.
/// Pi-hole, Netdata, and Kuma share one, so a 403 on any of them can raise the notice.
public final class AwayKeyLatch: @unchecked Sendable {
    private let lock = NSLock()
    private var rejected = false

    public init() {}

    public func note(path: String, status: Int) {
        guard AwayKeySignal.isRefusedKey(path: path, status: status) else { return }
        lock.lock()
        rejected = true
        lock.unlock()
    }

    /// Returns whether a refused key is waiting, and clears it.
    public func take() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let result = rejected
        rejected = false
        return result
    }
}
