import Foundation

/// A reason the launch film might leave. The film itself stays in the app.
public enum LaunchFilmCue: Sendable, Equatable {
    public enum Scene: Sendable, Equatable {
        case active
        case inactive
        case background
    }

    case tap
    case playbackEnded
    case missingFilm
    case stillHeld
    case scene(Scene)
    case sleepCancelled
}

/// Whether that cue ends the launch film.
public enum LaunchFilmHandoff: Sendable, Equatable {
    case stay
    case finish

    /// Skip, the end, a missing file, and the still hold finish.
    /// Backgrounding finishes too. A paused film never starts again.
    /// A cancelled wait finishes while the film is still up, and a second cue does nothing.
    public static func step(_ cue: LaunchFilmCue, alreadyFinished: Bool) -> LaunchFilmHandoff {
        guard !alreadyFinished else { return .stay }
        switch cue {
        case .tap, .playbackEnded, .missingFilm, .stillHeld, .scene(.background), .sleepCancelled:
            return .finish
        case .scene(.active), .scene(.inactive):
            return .stay
        }
    }
}
