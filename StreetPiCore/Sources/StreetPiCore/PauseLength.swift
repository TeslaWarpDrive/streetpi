import Foundation

/// How long ad blocking stays off before it turns itself back on.
/// There is no indefinite pause.
public struct PauseLength: Sendable, Equatable, Identifiable, Codable {
    public let seconds: Int

    public var id: Int { seconds }

    private init(validSeconds: Int) {
        self.seconds = validSeconds
    }

    public init?(seconds: Int) {
        guard Self.allowed(seconds) else { return nil }
        self.init(validSeconds: seconds)
    }

    public static let thirtySeconds = PauseLength(validSeconds: 30)
    public static let fiveMinutes = PauseLength(validSeconds: 300)
    public static let thirtyMinutes = PauseLength(validSeconds: 1_800)
    public static let presets: [PauseLength] = [.thirtySeconds, .fiveMinutes, .thirtyMinutes]

    /// Short label for a pause control. Confirmation still uses `title`.
    public var shortTitle: String {
        if seconds == 30 {
            return "30 sec"
        }
        if seconds == 300 {
            return "5 min"
        }
        if seconds == 1_800 {
            return "30 min"
        }
        return title
    }

    public var title: String {
        if seconds == 30 {
            return "30 seconds"
        }
        if seconds == 300 {
            return "5 minutes"
        }
        if seconds == 1_800 {
            return "30 minutes"
        }
        return Self.english(seconds: seconds)
    }

    public static func english(seconds: Int) -> String {
        if seconds % 3_600 == 0 {
            let hours = seconds / 3_600
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }
        if seconds % 60 == 0 {
            let minutes = seconds / 60
            return minutes == 1 ? "1 minute" : "\(minutes) minutes"
        }
        return seconds == 1 ? "1 second" : "\(seconds) seconds"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let seconds = try container.decode(Int.self)
        guard Self.allowed(seconds) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Pause length is out of range."
            )
        }
        self.init(validSeconds: seconds)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(seconds)
    }

    private static func allowed(_ seconds: Int) -> Bool {
        (1...86_400).contains(seconds)
    }
}
