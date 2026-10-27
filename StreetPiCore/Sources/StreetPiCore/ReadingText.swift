import Foundation

public enum AgePhrase {
    public static func english(from past: Date, to now: Date) -> String {
        let seconds = max(0, now.timeIntervalSince(past))
        if seconds < 60 {
            return "just now"
        }
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        }
        let hours = Int(seconds / 3_600)
        if hours < 24 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        }
        let days = Int(seconds / 86_400)
        if days == 1 {
            return "yesterday"
        }
        return "\(days) days ago"
    }
}

public enum ReadingText {
    public static func percent(_ fraction: Double) -> String {
        let value = Int((fraction * 100).rounded())
        return "\(value)%"
    }

    public static func celsius(_ degrees: Double) -> String {
        "\(Int(degrees.rounded()))°"
    }

    public static func warmth(_ degrees: Double) -> String {
        if degrees >= MachineLimits.hotCelsius {
            return "Too hot"
        }
        if degrees >= MachineLimits.warmCelsius {
            return "Hot"
        }
        if degrees >= 60 {
            return "Warm"
        }
        if degrees >= 50 {
            return "Comfortable"
        }
        return "Cool"
    }

    public static func uptime(_ seconds: TimeInterval) -> String {
        if seconds < 3_600 {
            return "Up less than an hour"
        }
        let hours = Int(seconds / 3_600)
        if hours < 48 {
            return hours == 1 ? "Up 1 hour" : "Up \(hours) hours"
        }
        let days = max(1, Int(seconds / 86_400))
        return days == 1 ? "Up 1 day" : "Up \(days) days"
    }

    /// "Pi 5 · up 12 days". The uptime half drops out when there is no reading.
    public static func machineLine(model: String, uptimeSeconds: TimeInterval?) -> String {
        let name = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let uptimeSeconds else { return name }
        let phrase = uptime(uptimeSeconds)
        if name.isEmpty { return phrase }
        return "\(name) · \(phrase.prefix(1).lowercased())\(phrase.dropFirst())"
    }

    /// The plain word under the Processor ring.
    public static func processorWord(_ fraction: Double) -> String {
        if fraction >= MachineLimits.processorBusy {
            return "Busy"
        }
        if fraction >= 0.5 {
            return "Steady"
        }
        return "Light"
    }

    /// The plain word under the Memory and Disk rings.
    public static func roomWord(_ fraction: Double, limit: Double) -> String {
        fraction >= limit ? "Almost full" : "Room to spare"
    }

    public static func stateWord(for service: ServiceHealth) -> String {
        switch service.state {
        case .responding:
            switch service.kind {
            case .dnsFilter:
                return "Blocking"
            case .resolver:
                return "Answering"
            case .backup:
                return "Copied"
            case .internet:
                return "Up to date"
            case .remoteHelp:
                return "Ready"
            default:
                return "Up"
            }
        case .notResponding:
            return "Not responding"
        case .degraded:
            return "Having trouble"
        case .maintenance:
            return "Paused"
        case .unknown:
            return "No recent news"
        }
    }
}
