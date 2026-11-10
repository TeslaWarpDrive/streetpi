import Foundation

/// Whether the launch film's picture has reached its end.
/// The player stays in the app. This only decides.
/// A pause while the app stays open is not the end, even after the film's length plus three seconds.
/// A stall that runs past that grace is the end.
public enum LaunchFilmPlayback: Sendable {
    public enum Transport: Sendable, Equatable {
        case playing
        case paused
        case waiting
    }

    /// Extra time after the film's length before a stall counts as the end.
    public static let overtime: TimeInterval = 3

    public static func reachedEnd(
        duration: TimeInterval?,
        elapsed: TimeInterval,
        remaining: TimeInterval?,
        sawPlayback: Bool,
        transport: Transport
    ) -> Bool {
        guard let duration, duration.isFinite else { return false }
        if transport != .paused, elapsed > duration + overtime {
            return true
        }
        guard sawPlayback, let remaining, remaining.isFinite else { return false }
        if remaining <= 0.05 { return true }
        return remaining <= 0.2 && transport != .playing
    }
}
