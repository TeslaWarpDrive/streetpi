import Foundation

/// Whether an away HTTP response is the key being refused.
/// A 403 on the health check or the login probe is. Any other 403 is the Pi saying no.
public enum AwayKeySignal {
    public static func isRefusedKey(path: String, status: Int) -> Bool {
        guard status == 403 else { return false }
        switch path {
        case "/healthz", "/api/info/login":
            return true
        default:
            return false
        }
    }
}
