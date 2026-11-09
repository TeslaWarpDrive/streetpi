import Foundation

/// Whether an away HTTP response is the key being refused.
/// A 403 on the health check or the login probe is. Any other status is not.
public enum AwayKeySignal {
    /// Today's latch: every HTTP 403 is a refused key, including Pi-hole's own forbidden.
    public static func isRefusedKey(path: String, status: Int) -> Bool {
        guard status == 403 else { return false }
        switch path {
        case "/healthz", "/api/info/login":
            return true
        default:
            return true
        }
    }
}
