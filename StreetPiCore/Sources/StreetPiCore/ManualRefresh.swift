import Foundation

/// What a pull reads when the road on screen stays put.
/// A different road restarts the watch, so it is not decided here.
public enum ManualRefresh {
    public enum Source: Sendable, Equatable, Hashable {
        case adBlocker
        case mailbox
        case temperature
        case charts
        case monitors
    }

    /// The mailbox snapshot already carries the tiles, so that road stays one read.
    /// Signed out still reads nothing.
    public static func reads(mode: ConnectionMode, signedOut: Bool) -> Set<Source> {
        if case .awayMailbox = mode {
            return [.mailbox]
        }
        guard signedOut == false else { return [] }
        return [.adBlocker, .temperature, .charts, .monitors]
    }
}
